# Portfolio 5: Distributed and Cloud Database Exercise

**Course:** MIT 8103 – Advanced Database Systems  
**Academic Session:** 2026/2027  
**Case Study:** EkoStay Hospitality Limited  
**Deliverable:** Horizontal Partitioning & Sharding, Replication & Read-Write Splitting, CAP/PACELC Consistency Verification, and Cloud High-Availability Architecture  
**Component Score Weight:** 7 Marks  
**Author:** Rabiu Sekinah (`301870666`)  

---

## 1. Overview & Distributed Hospitality Context

As EkoStay Hospitality Limited expands across Lagos (Victoria Island and Ikeja), Abuja (Maitama), and Port Harcourt (GRA), a single monolithic database node introduces three fundamental limitations:
1. **Single Point of Failure (SPOF):** Hardware or Availability Zone failure during peak check-in or holiday booking windows halts all reservations and digital keycard activations.
2. **Table Bloat on Historical Reservations:** Storing years of historical bookings inside a single heap degrades index maintenance, `VACUUM` freeze times, and monthly revenue reporting.
3. **Read-Write Contention:** Heavy analytical workloads (Night Audit reconciliation, RevPAR dashboards, and high-ratio room availability browsing) compete for CPU and buffer cache with latency-sensitive room reservations (`SELECT ... FOR UPDATE`).

In this fifth portfolio milestone, I designed and empirically verified EkoStay's distributed database architecture in PostgreSQL 16:
- **Declarative Range Partitioning (`bookings_partitioned`):** Partitioned 15,015 reservations into monthly check-in ranges (`2026-05` through `2026-12`) and verified **Partition Pruning** via `EXPLAIN (ANALYZE, BUFFERS)`.
- **4-Way Hash Sharding (`rooms_sharded`):** Sharded 218 hotel rooms across 4 logical property shards using `PARTITION BY HASH (room_number)` and verified single-shard routing.
- **Replication & Read-Write Query Splitting (`02-replication-read-write-split.sql`):** Configured logical replication publications (`ekostay_crs_pub`), inspected live WAL LSN state, and built a latency-aware query router (`fn_route_ekostay_query`).
- **CAP / PACELC Tunable Consistency & Failover (`03-distributed-cap-pacelc-verification.sql`):** Demonstrated per-transaction `synchronous_commit` tuning, idempotent Paystack/OTA webhook deduplication, and automated primary-to-standby failover ($\text{RTO} = 16.80\text{s}, \text{RPO} = 0\text{ms}$).

---

## 2. Horizontal Partitioning & Hash Sharding (`01-table-partitioning-sharding.sql`)

### 2.1 Monthly Range Partitioning on `bookings_partitioned`
PostgreSQL requires that any `PRIMARY KEY` or `UNIQUE` constraint on a partitioned table include the partitioning column. I engineered `bookings_partitioned` with composite keys `PRIMARY KEY (booking_id, check_in_date)` and `UNIQUE (booking_reference, check_in_date)` partitioned by `RANGE (check_in_date)`.

#### Empirical Tuple Distribution Across Monthly Partitions (`evidence/01-partition-pruning-output.log`):

| Partition Table | Partition Range Bound (`check_in_date`) | Tuple Count | Storage Footprint |
| :--- | :--- | :---: | :---: |
| `bookings_p2026_05` | `['2026-05-01', '2026-06-01')` | 2,625 | 1,352 kB |
| `bookings_p2026_06` | `['2026-06-01', '2026-07-01')` | 2,434 | 1,288 kB |
| `bookings_p2026_07` | `['2026-07-01', '2026-08-01')` | 2,573 | 1,376 kB |
| `bookings_p2026_08` | `['2026-08-01', '2026-09-01')` | 2,639 | 1,416 kB |
| `bookings_p2026_09` | `['2026-09-01', '2026-10-01')` | 2,498 | 1,328 kB |
| `bookings_p2026_10` | `['2026-10-01', '2026-11-01')` | 2,237 | 1,192 kB |
| `bookings_p2026_11` | `['2026-11-01', '2026-12-01')` | 2 | 72 kB |
| `bookings_p2026_12` | `['2026-12-01', '2027-01-01')` | 7 | 72 kB |
| `bookings_p_default` | `DEFAULT` | 0 | 32 kB |

#### Empirical Proof of Partition Pruning:
When executing an October 2026 channel revenue audit (`WHERE check_in_date >= '2026-10-01' AND check_in_date < '2026-11-01'`), PostgreSQL pruned 8 of the 9 partitions at planning time and scanned **only** `bookings_p2026_10`:
```text
Seq Scan on bookings_p2026_10 bookings_partitioned  (cost=0.00..105.94 rows=2162 width=30) (actual time=0.099..11.674 rows=2162 loops=1)
  Filter: ((check_in_date >= '2026-10-01'::date) AND (check_in_date < '2026-11-01'::date) AND ((booking_status)::text = ANY ('{CHECKED_OUT,CHECKED_IN,CONFIRMED}'::text[])))
  Rows Removed by Filter: 75
  Buffers: shared hit=64
```
Instead of reading 427 buffer pages across the full 15,015-row table, the engine read only **64 buffer pages** (**an 85.0% I/O reduction**).

### 2.2 4-Way Hash Sharding on `rooms_sharded`
Using `PARTITION BY HASH (room_number)` with `MODULUS 4`, the 218 hotel rooms were distributed across 4 logical property shards:

| Logical Shard Partition | Hosted Rooms | Distribution % | Daily Tariff Capacity (NGN) |
| :--- | :---: | :---: | :---: |
| `rooms_shard_00` | 63 | 28.90% | ₦15,810,000.00 |
| `rooms_shard_01` | 47 | 21.56% | ₦10,925,000.00 |
| `rooms_shard_02` | 49 | 22.48% | ₦15,405,000.00 |
| `rooms_shard_03` | 59 | 27.06% | ₦14,855,000.00 |

When querying `WHERE room_number = 'A101'`, PostgreSQL hashed `'A101'` and routed the lookup directly to `rooms_shard_01` (`Buffers: shared hit=1`), completely ignoring the other three shards.

---

## 3. Replication & Read-Write Query Routing (`02-replication-read-write-split.sql`)

I modeled EkoStay's 4-node multi-region topology (`distributed_cluster_nodes`), created a logical replication publication (`CREATE PUBLICATION ekostay_crs_pub FOR TABLE rooms, bookings, payments, checkin_checkout_records`), and implemented the routing function `fn_route_ekostay_query`:

| Workload Category | SQL Operation | Selected Node | Selected Role | Routing Decision |
| :--- | :--- | :--- | :--- | :--- |
| `ROOM_RESERVATION_WRITE` | `SELECT * FROM sp_create_room_reservation(...)` | `ekostay-pg-primary-01` | `PRIMARY_WRITER` | Mutation / `FOR UPDATE` lock routed strictly to Primary Writer. |
| `POST_BOOKING_FOLIO_VIEW` | `SELECT ... FROM bookings WHERE guest_id = ...` (`require_read_your_writes = TRUE`) | `ekostay-pg-standby-02` | `SYNC_STANDBY` | Session consistency required immediately after reservation; routed to Sync Standby (`1.35 ms` lag). |
| `NIGHT_AUDIT_REVPAR_ANALYTICS` | `SELECT wing, count(*), sum(total_amount) ...` (`require_read_your_writes = FALSE`) | `ekostay-pg-replica-03` | `ASYNC_READ_REPLICA` | Heavy analytical aggregation offloaded to lowest-lag Async Read Replica (`13.60 ms` lag). |

---

## 4. CAP / PACELC Consistency & Failover Verification (`03-distributed-cap-pacelc-verification.sql`)

1. **PACELC Per-Transaction Tunable Consistency:**
   - **CP / PC+EC Mode (`SET LOCAL synchronous_commit = 'on'`):** Used for room reservations, front-desk check-ins, and Paystack/NIP settlements.
   - **Local Durable Mode (`SET LOCAL synchronous_commit = 'local'`):** Used for guest profile updates and special request notes.
   - **AP / PA+EL Mode (`SET LOCAL synchronous_commit = 'off'`):** Used for non-monetary room search telemetry.
2. **Idempotent Webhook Deduplication (`distributed_idempotency_registry`):**
   - Verified that duplicate Paystack/OTA webhook retries (`IDEMP-PSK-20261030-004419`) during network partitions are absorbed via `ON CONFLICT (idempotency_key) DO UPDATE SET retry_attempts = retry_attempts + 1`, guaranteeing zero duplicate bookings or double-charges.
3. **Automated Primary Failover Simulation:**
   - Simulated `ekostay-pg-primary-01` going `OFFLINE`, promoted `ekostay-pg-standby-02` to `PRIMARY_WRITER` ($\text{RTO} = 16.80\text{s}, \text{RPO} = 0.00\text{ms}$), and verified that `fn_route_ekostay_query` automatically redirected subsequent reservation writes to `ekostay-pg-standby-02`.

---

## 5. Cloud HA & Disaster Recovery Blueprint

A comprehensive cloud architecture diagram and disaster recovery specification is documented in [`04-cloud-ha-disaster-recovery.md`](04-cloud-ha-disaster-recovery.md).

---

## 6. How to Execute the Portfolio 5 Test Suite

```bash
# 1. Execute Monthly Range Partitioning & 4-Way Hash Sharding
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-5/01-table-partitioning-sharding.sql

# 2. Execute Replication Publication & Read-Write Query Routing
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-5/02-replication-read-write-split.sql

# 3. Execute CAP/PACELC Consistency, Idempotency & Failover Verification
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-5/03-distributed-cap-pacelc-verification.sql
```

---

## 7. Technical Reflection & Practical Debugging Log

### 7.1 Practical Bugs Encountered & Resolved
1. **Ambiguous `tableoid` System Column in Joined Sharding Query:**  
   When verifying shard distribution in `01-table-partitioning-sharding.sql` by joining `rooms_sharded rs` with `room_categories rc`, referencing an unqualified `tableoid::regclass` raised:
   ```text
   ERROR: column "tableoid" does not exist
   DETAIL: There are columns named "tableoid", but they are in tables that cannot be referenced from this part of the query.
   HINT: Try using a table-qualified name.
   ```
   Because every PostgreSQL table exposes the hidden system column `tableoid`, joining two tables requires qualifying the alias (`rs.tableoid::regclass`). Updating the query to `rs.tableoid::regclass` resolved the error and produced the 4-shard distribution table.
2. **Composite Primary Keys on Partitioned Tables:**  
   PostgreSQL enforces that every `PRIMARY KEY` or `UNIQUE` constraint on a declaratively partitioned table must include all partition key columns. For `bookings_partitioned`, I updated the constraints to `PRIMARY KEY (booking_id, check_in_date)` and `UNIQUE (booking_reference, check_in_date)`.

---

## 8. Academic Integrity and AI Use Declaration

*(In accordance with Section 11 of the Continuous Assessment Syllabus)*

1. **AI Tools Used:** Claude / AI Programming Assistant
2. **Specific Tasks Where AI Was Used:**
   - Reviewing PostgreSQL system catalog queries (`pg_inherits`, `pg_class`, `rs.tableoid::regclass`) for inspecting child partition bounds and tuple counts.
   - Formatting the Mermaid multi-region cloud topology diagram.
3. **Student Verification & Ownership:**
   - I designed the monthly `check_in_date` range partitioning scheme, the 4-way `room_number` hash sharding scheme, the read-write query router, and the idempotency registry.
   - I executed all three SQL scripts inside the live PostgreSQL 16 Docker container and verified the captured logs in `evidence/`.
