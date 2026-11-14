# MIT 8103 – Advanced Database Systems: Continuous Assessment Synthesis & Technical Reflection

**Programme:** Master of Information Technology (SPGS), MIVA Open University  
**Course Code & Title:** MIT 8103 – Advanced Database Systems  
**Academic Session:** 2026/2027 – First Semester  
**Student Name:** Rabiu Sekinah  
**Student ID:** 301870666  
**Student Email:** s.rabiu0666@miva.edu.ng  
**GitHub Repository:** https://github.com/srabiu0666-ops/mit8103  
**Case Study Domain:** EkoStay Hospitality Limited (Hotel Reservation, Property Management & Smart Room Telemetry System)  

---

## 1. Executive Summary & Case Study Selection

This document presents the architectural synthesis, empirical verification results, and technical reflection for the **EkoStay Hospitality Limited** database portfolio.

EkoStay Hospitality Limited is modeled on multi-property luxury and business hotel chains in Nigeria (such as Eko Hotels & Suites, Transcorp Hilton, and Marriott Lagos), operating across Victoria Island and Ikeja (Lagos), Maitama (Abuja), and GRA (Port Harcourt). Per **Section 2 of the Continuous Assessment Guidelines**, the EkoStay case study was maintained consistently across all five portfolio milestones:

1. **Nature of the Business:** Central Reservation System (CRS), Property Management System (PMS), multi-channel payment settlement ledger, front-desk check-in/out operations, and smart-room IoT telemetry platform.
2. **Database Users & Actors:** Individual and corporate hotel guests, front-desk receptionists and duty managers, housekeeping and facility engineering staff, finance and Night Audit reconciliation officers, and automated backend services.
3. **Major Data Stored:** Loyalty tier definitions (`loyalty_tiers`), verified guest profiles with SHA-256 hashed NIN/Passport numbers (`guests`), standardized room categories (`room_categories`), physical room inventory (`rooms`), reservation folios (`bookings`), gateway payments (`payments`), front-desk stay records (`checkin_checkout_records`), immutable JSONB audit trails (`audit_logs`), and MongoDB smart-room IoT telemetry (`room_iot_telemetry`) and polymorphic concierge tickets (`guest_concierge_requests`).
4. **Key Operations Supported:** Real-time room availability validation, loyalty discount and 12.5% statutory tax calculation (7.5% VAT + 5% State Consumption Tax), atomic reservation and payment settlement, pessimistic double-booking prevention, smart-lock security surveillance, and multi-region partitioned query routing.

---

## 2. Synthesis of Portfolio Milestones & Empirical Results

### 2.1 Portfolio 1: Database Design and Relational Modelling (7 Marks)
- **Architectural Design:** Engineered an 8-table relational schema normalized from Unnormalised Form (UNF) through 1NF, 2NF, 3NF, to **Boyce-Codd Normal Form (BCNF)**.
- **Key Normalisation Decisions:**
  - Separated `room_categories` (`base_nightly_rate`, `caution_deposit_amount`, `max_occupancy`, `bed_configuration`) from `rooms` (`room_number`, `wing`, `floor_number`, `room_status`) to eliminate transitive dependencies ($\text{room\_id} \to \text{category\_id} \to \text{base\_nightly\_rate}$).
  - Separated `loyalty_tiers` (`discount_percentage`, `late_checkout_hours`, `max_active_bookings`) from `guests`.
  - Separated `checkin_checkout_records` (`actual_check_in_at`, `keycard_code`, `deposit_held`, `room_inspection_status`) from `bookings` to avoid sparse NULL columns on future or cancelled reservations.
- **Integrity & Trigger Enforcement:** Verified via `04-verification-tests.sql` that invalid check-out dates (`chk_booking_dates`), malformed room numbers (`chk_room_number_format`), duplicate phone numbers, and bookings on `OUT_OF_ORDER` rooms (`trg_validate_booking_rules`) are strictly rejected.

### 2.2 Portfolio 2: Query Processing and Optimisation (7 Marks)
- **Volumetric Scaling:** Expanded the database via `01-data-generator.sql` to **122 guests, 218 physical hotel rooms, 15,008 bookings, 15,008 payments, and 5,005 check-in/out stay logs**.
- **Index Engineering & Empirical Speedups:** Analyzed five hospitality analytical queries with `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)` before and after deploying partial, composite, and covering (`INCLUDE`) indexes:
  - **Query 1 (Corporate & OTA Booking Surveillance):** Shifted from `Seq Scan` (`54.231 ms`, `435 buffers`) to `Index Only Scan` on `idx_bookings_checkin_channel_covering` (`22.440 ms`, `66 buffers` — **2.4x speedup, 84.8% I/O reduction**).
  - **Query 2 (Night Audit Gateway Exceptions):** Shifted from `Seq Scan` on 15,008 payment rows (`56.246 ms`, `442 payment buffers`) to a Partial `Index Only Scan` on `idx_payments_exceptions_partial` (`12.080 ms`, `9 payment buffers` — **4.7x speedup, 98.0% I/O reduction**).
  - **Query 3 (Room Running Revenue Window Function):** Eliminated 100% of heap page fetches (`Heap Fetches: 0`) and reduced total plan cost by **89.7%** (`199.70` to `20.53`).
  - **Query 4 (Loyalty Tier Booking Cap Audit):** Shifted from `Seq Scan` (`38.215 ms`, `431 buffers`) to Partial `Index Only Scan` (`1.898 ms`, `11 buffers` — **20.1x speedup, 97.4% I/O reduction**).
  - **Query 5 (Executive Tower Suite Tax Yield):** Shifted from `Seq Scan` (`29.887 ms`, `437 buffers`) to Covering `Index Only Scan` (`2.166 ms`, `8 buffers` — **13.8x speedup, 98.2% I/O reduction**).

### 2.3 Portfolio 3: Transactions and Concurrency Control (7 Marks)
- **Atomic Stored Procedures:** Implemented `sp_create_room_reservation` and `sp_book_room_pair` in PL/pgSQL (`01-room-reservation-procedure.sql`).
- **Concurrency & Double-Booking Prevention:** Demonstrated how locking the parent physical room row (`SELECT ... FROM rooms WHERE room_number = p_room_number FOR UPDATE OF r`) serializes concurrent mobile app and OTA reservation attempts for Presidential Penthouse `E502`, preventing the empty-range phantom double-booking bug.
- **Deadlock Elimination:** Enforced deterministic ascending lexicographical lock acquisition (`D402 -> D403`) in `sp_book_room_pair`, mathematically breaking Coffman's *Circular Wait* condition during multi-room corporate block bookings.

### 2.4 Portfolio 4: NoSQL and Advanced Data Models (7 Marks)
- **Polyglot Persistence in MongoDB 7.0:** Designed two collections (`room_iot_telemetry` and `guest_concierge_requests`) enforced by `$jsonSchema` validators, a `2dsphere` GeoJSON spatial index, and a 90-day TTL index (`expireAfterSeconds: 7776000`) for NDPR compliance.
- **Aggregation Pipelines:** Executed four multi-stage pipelines (`03-mongo-queries.js`) that detected a blacklisted guest (`a0000000-...-0011`) attempting a cloned RFID tap on Room `C303` in Lagos followed 12 minutes later by remote API unlock replay attacks on Suites `D402` and `E501` from a Frankfurt Tor VPN exit node (`185.220.101.5`).

### 2.5 Portfolio 5: Distributed and Cloud Database Exercise (6 Marks)
- **Declarative Range Partitioning & Hash Sharding:**
  - Partitioned `bookings_partitioned` into monthly ranges by `check_in_date` (`bookings_p2026_05` to `bookings_p2026_12`), achieving **85.0% buffer I/O pruning** (`64 buffers` vs `427 buffers`) on October 2026 revenue audits.
  - Sharded `rooms_sharded` across 4 hash partitions (`MODULUS 4`) by `room_number`, achieving single-shard routing (`Buffers: shared hit=1`).
- **Replication, Read-Write Routing & Failover:** Configured logical replication (`ekostay_crs_pub`), verified workload routing across Primary (`0.00ms`), Sync Standby (`1.35ms`), and Async Replica (`13.60ms`), verified idempotent Paystack/OTA webhook deduplication, and simulated automated Patroni failover ($\text{RTO} = 16.80\text{s}, \text{RPO} = 0.00\text{ms}$).

---

## 3. Critical Technical Reflection & Debugging Log

During the implementation and container testing of the five portfolios, I diagnosed and resolved several concrete database engineering challenges:

1. **PostgreSQL Serial Sequence Desynchronization (Portfolio 1):**  
   Seeding explicit `category_id` values (`1..5`) in `room_categories` left the underlying sequence counter at `1`. I resolved this by adding `SELECT setval('room_categories_category_id_seq', 5, true);` in `03-seed-data.sql`.
2. **Visibility Map & `VACUUM ANALYZE` for Index-Only Scans (Portfolio 2):**  
   Immediately after inserting 15,000 synthetic rows, PostgreSQL still performed heap fetches even when a covering index with `INCLUDE` existed because the Visibility Map bits were not yet marked all-visible. Running `VACUUM ANALYZE` updated the Visibility Map and enabled true `Index Only Scan` execution with `Heap Fetches: 0`.
3. **Scoped Row Locking (`FOR UPDATE OF r`) on Joined Queries (Portfolio 3):**  
   Locking a joined query across `rooms r` and `room_categories rc` with an unqualified `FOR UPDATE` would lock the shared category row and block bookings on unrelated rooms in the same category. Qualifying `FOR UPDATE OF r` restricted the exclusive lock strictly to the target room row.
4. **BSON Numeric Type Coercion in `mongosh` (Portfolio 4):**  
   Whole-number floats in JavaScript (`48.0`, `21.0`) are serialized by `mongosh` as BSON `int` rather than `double`, triggering `MongoBulkWriteError: Document failed validation` under strict `bsonType: 'double'`. Updating the `$jsonSchema` numeric properties to `bsonType: ['double', 'int', 'decimal']` resolved the validation error cleanly.
5. **Qualified System Column `rs.tableoid` in Joined Sharding Queries (Portfolio 5):**  
   Joining `rooms_sharded rs` and `room_categories rc` caused an ambiguous column error on `tableoid::regclass` because every PostgreSQL table has a hidden `tableoid` attribute. Qualifying `rs.tableoid::regclass` resolved the ambiguity.

---

## 4. Academic Integrity, References & AI Use Declaration

### 4.1 AI Use Declaration
1. **AI Tools Used:** Claude / AI Programming Assistant
2. **What the AI Tool Was Used For:**
   - Reviewing PostgreSQL 16 PL/pgSQL syntax (`FOR UPDATE OF r`, partitioned composite primary keys, and `pg_inherits` catalog queries).
   - Diagnosing `mongosh` BSON numeric type serialization in `$jsonSchema` validators and formatting `EXPLAIN (ANALYZE, BUFFERS)` tables.
3. **How Output Was Reviewed, Corrected, Tested, and Verified:**
   - All domain modelling, Nigerian hospitality business rules (12.5% combined VAT and Consumption Tax, loyalty tier discounts and booking caps, front-desk keycard and caution deposit workflows), and normalization proofs were designed by me.
   - Every SQL and JavaScript script was executed and verified inside live PostgreSQL 16 and MongoDB 7.0 Docker containers, with raw outputs captured in each portfolio's `evidence/` directory.

### 4.2 References
1. Silberschatz, A., Korth, H. F., & Sudarshan, S. (2019). *Database System Concepts* (7th ed.). McGraw-Hill Education.
2. Kleppmann, M. (2017). *Designing Data-Intensive Applications: The Big Ideas Behind Reliable, Scalable, and Maintainable Systems*. O'Reilly Media.
3. PostgreSQL Global Development Group. (2026). *PostgreSQL 16 Documentation: Concurrency Control, Query Planning, and Declarative Partitioning*. https://www.postgresql.org/docs/16/
4. MongoDB, Inc. (2026). *MongoDB 7.0 Manual: Schema Validation, 2dsphere Indexes, and Aggregation Pipeline*. https://www.mongodb.com/docs/v7.0/
5. Abadi, D. J. (2012). Consistency Tradeoffs in Modern Distributed Database System Design: CAP is Only Part of the Story. *IEEE Computer*, 45(2), 37–42.
