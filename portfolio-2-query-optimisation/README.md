# Portfolio 2: Query Processing and Optimisation

**Course:** MIT 8103 – Advanced Database Systems  
**Academic Session:** 2026/2027  
**Case Study:** EkoStay Hospitality Limited  
**Deliverable:** Synthetic Data Scaling, Analytical Hospitality Queries, EXPLAIN (ANALYZE, BUFFERS) Plans, Index Engineering & Performance Analysis  
**Component Score Weight:** 7 Marks  
**Author:** Rabiu Sekinah (`301870666`)  

---

## 1. Overview & Practical Objectives

In this second portfolio milestone, I focused on database query engine internals, cost-based query optimization, and storage access paths in PostgreSQL 16.

A common pitfall in database coursework is evaluating query optimization on tiny datasets (e.g., 10–20 rows). On small tables that fit inside one or two 8KB heap pages, PostgreSQL's cost-based query planner will consistently prefer a **Sequential Scan (`Seq Scan`)** because reading a single page sequentially (`seq_page_cost = 1.0`) is cheaper than traversing B-Tree index pages (`random_page_cost = 4.0`).

To conduct a scientifically valid benchmark, I developed a procedural volumetric data generator (`01-data-generator.sql`) that expanded my initial EkoStay database to **122 guests, 218 physical hotel rooms, 15,008 reservations (`bookings`), 15,008 payment settlements (`payments`), and 5,005 front-desk stay logs (`checkin_checkout_records`)** spanning six months of hospitality activity.

Using this realistic production-scale dataset, I engineered five real-world hospitality analytical queries, analyzed their baseline execution plans using `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)`, diagnosed the I/O and CPU bottlenecks, designed targeted indexes (composite, partial, and covering indexes with `INCLUDE`), and measured the before-and-after execution improvements.

---

## 2. Dataset Volumetric Scaling

I executed `01-data-generator.sql` using a set-based PL/pgSQL procedural block. By combining `generate_series()` with deterministic date-window allocation and realistic Nigerian hospitality tariffs, I scaled the schema as follows:

| Table Name | Initial Rows (Portfolio 1) | Scaled Rows (Portfolio 2) | Growth Factor |
| :--- | :---: | :---: | :---: |
| `loyalty_tiers` | 4 | 4 | Baseline Reference |
| `room_categories` | 5 | 5 | Baseline Catalog |
| `guests` | 12 | 122 | 10.2x |
| `rooms` | 14 | 218 | 15.6x |
| `bookings` | 8 | 15,008 | **1,876x** |
| `payments` | 8 | 15,008 | **1,876x** |
| `checkin_checkout_records` | 5 | 5,005 | **1,001x** |
| `audit_logs` | 2 | 2 | Baseline Snapshot |

After loading the dataset, I executed `ANALYZE` across all tables to refresh the `pg_statistic` catalog (tuple counts, histogram bounds, and most common values) for the cost-based optimizer.

---

## 3. Real-World Hospitality Analytical Queries

I developed five SQL queries representing critical hotel management, revenue audit, and guest loyalty workflows:

1. **Query 1: High-Frequency Corporate & OTA Booking Surveillance (August 2026 Audit Window)**  
   *Business Purpose:* Identifies guests who placed 3 or more reservations totaling over ₦500,000 through `CORPORATE_DESK` or `OTA_BOOKING_COM` during August 2026.
2. **Query 2: Night Audit Payment Gateway Settlement Exceptions (`FAILED` & `REFUNDED`)**  
   *Business Purpose:* Aggregates failed and refunded payment transactions grouped by gateway provider (`PAYSTACK`, `FLUTTERWAVE`, `INTERSWITCH_POS`, `MONIEPOINT_POS`, `NIBSS_NIP_DIRECT`) and payment method to resolve settlement disputes.
3. **Query 3: Room Folio Statement with Chronological Running Revenue (Window Function)**  
   *Business Purpose:* Generates a chronological occupancy ledger and cumulative running revenue statement for Room `A101` using SQL Window functions (`SUM(total_amount) OVER (PARTITION BY room_id ORDER BY check_in_date)`).
4. **Query 4: Loyalty Tier Active Booking Ceiling & Revenue Compliance Audit**  
   *Business Purpose:* Audits active (`CONFIRMED` and `CHECKED_IN`) Q4 reservations per guest against their assigned `loyalty_tiers.max_active_bookings` cap.
5. **Query 5: Executive Tower Luxury Suite Turnover & Tax Yield Ranking**  
   *Business Purpose:* Ranks luxury suites in the `EXECUTIVE_TOWER` wing by gross folio revenue, net room revenue, and 12.5% statutory tax yield (VAT + Consumption Tax) during the October 2026 audit window.

---

## 4. Strategic Indexing Implementation

After inspecting the baseline execution plans (`evidence/01-baseline-explain-plans.log`), I identified three major execution bottlenecks:
1. **Full Table Scans on Low-Selectivity Exception Predicates:** Query 2 sequentially scanned all 442 heap pages of `payments` (15,008 rows), discarding 14,608 `COMPLETED` rows just to aggregate the 400 `FAILED` and `REFUNDED` exception rows.
2. **Repeated Sequential Scans on the 427-Page `bookings` Heap:** Queries 1, 4, and 5 performed full sequential scans over all 15,008 booking rows (427 shared buffer pages) to filter specific check-in date windows or active booking statuses.
3. **Heap Page Lookups During Room Statement Window Aggregation:** Query 3 used a `Bitmap Heap Scan` on `bookings` and a `Seq Scan` on `rooms` to resolve Room `A101`.

To eliminate these bottlenecks, I engineered six targeted indexes in `03-optimization-indexes.sql`:

```sql
-- 1. Partial Covering Index for payment gateway exceptions (targets Query 2)
CREATE INDEX idx_payments_exceptions_partial
ON payments(paid_at, gateway_provider, payment_method, payment_status)
INCLUDE (payment_id, booking_id, amount_paid)
WHERE payment_status IN ('FAILED', 'REFUNDED');

-- 2. Composite Covering Index with INCLUDE for date-window & channel audits (targets Query 1 & 5)
CREATE INDEX idx_bookings_checkin_channel_covering
ON bookings(check_in_date, booking_status, booking_channel)
INCLUDE (booking_id, guest_id, room_id, subtotal_amount, tax_amount, total_amount, check_out_date);

-- 3. Composite Pre-Sorted Covering Index for room running revenue (targets Query 3)
CREATE INDEX idx_bookings_room_checkin_composite
ON bookings(room_id, check_in_date)
INCLUDE (check_out_date, booking_reference, booking_channel, booking_status, subtotal_amount, tax_amount, total_amount);

-- 4. Partial Covering Index for active guest booking ceiling checks (targets Query 4)
CREATE INDEX idx_bookings_status_guest_covering
ON bookings(check_in_date, guest_id)
INCLUDE (total_amount, booking_id)
WHERE booking_status IN ('CONFIRMED', 'CHECKED_IN');

-- 5. Partial Covering Index for Executive Tower suite reporting (targets Query 5)
CREATE INDEX idx_rooms_executive_tower_covering
ON rooms(room_id)
INCLUDE (room_number, category_id)
WHERE wing = 'EXECUTIVE_TOWER';

-- 6. Covering Index for instant room number resolution (targets Query 3)
CREATE INDEX idx_rooms_number_covering
ON rooms(room_number)
INCLUDE (room_id, category_id, wing, room_status);
```

Following index creation, I executed `VACUUM ANALYZE` so PostgreSQL updated the visibility map (`Heap Fetches: 0`), enabling true **Index-Only Scans**.

---

## 5. Comparative Performance Benchmarks & Results

Below are the empirical execution metrics captured directly from PostgreSQL 16 using `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)` before (`evidence/01-baseline-explain-plans.log`) and after (`evidence/02-optimized-explain-plans.log`) applying the optimization indexes:

| Query | Metric | Baseline (Unoptimized) | Optimized | Improvement | Primary Execution Node Shift |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Q1: Corporate/OTA Audit** | Execution Time | 54.231 ms | 22.440 ms | **58.6% Faster (2.4x)** | `Seq Scan` $\to$ `Index Only Scan` |
| | Estimated Cost | 772.79 | 340.17 | **56.0% Reduction** | Cost dropped from 772 to 340 |
| | Buffer Hits | 435 pages | 66 pages | **84.8% I/O Reduction** | `Heap Fetches: 0` (58 index pages) |
| **Q2: Gateway Exceptions** | Execution Time | **56.246 ms** | **12.080 ms** | **78.5% Faster (4.7x)** | **`Seq Scan` $\to$ Partial `Index Only Scan`** |
| | Payments Scan Cost | 667.12 | 39.24 | **94.1% Reduction** | Cost dropped from 667 to 39 |
| | Payments Buffers | 442 pages | 9 pages | **98.0% I/O Reduction** | Bypassed 433 heap pages (`Heap Fetches: 0`) |
| **Q3: Room Running Rev** | Execution Time | 5.231 ms | 5.037 ms | **3.7% Faster** | `Bitmap Heap Scan` $\to$ `Index Only Scan` |
| | Total Plan Cost | 199.70 | 20.53 | **89.7% Cost Drop** | Cost dropped from 199.70 to 20.53 |
| | Heap Fetches | 70 rows | 0 rows | **100% Elimination** | Both `rooms` and `bookings` served from index |
| **Q4: Loyalty Cap Breach** | Execution Time | **38.215 ms** | **1.898 ms** | **95.0% Faster (20.1x)** | **`Seq Scan` $\to$ Partial `Index Only Scan`** |
| | Estimated Cost | 661.03 | 11.04 | **98.3% Reduction** | Cost dropped from 661 to 11 |
| | Buffer Hits | 431 pages | 11 pages | **97.4% I/O Reduction** | `bookings` buffers cut from 427 to 2 pages |
| **Q5: Executive Tower** | Execution Time | **29.887 ms** | **2.166 ms** | **92.8% Faster (13.8x)** | **`Seq Scan` $\to$ Covering `Index Only Scan`** |
| | Estimated Cost | 706.41 | 27.49 | **96.1% Reduction** | Cost dropped from 706 to 27 |
| | Buffer Hits | 437 pages | 8 pages | **98.2% I/O Reduction** | `bookings` buffers cut from 427 to 4 pages |

---

## 6. Deep Dive: Architectural Insights & Database Internals

### 6.1 Partial Index-Only Scan on Payment Exceptions (Query 2 Analysis)
During Night Audit reconciliation (Query 2), finance officers audit `FAILED` and `REFUNDED` gateway transactions. In the unoptimized state, PostgreSQL executed:
```text
Seq Scan on public.payments p  (cost=0.00..667.12 rows=398 width=74) (actual time=0.083..41.408 rows=400 loops=1)
  Filter: (((p.payment_status)::text = ANY ('{FAILED,REFUNDED}'::text[])) AND (p.paid_at >= '2026-05-31 23:00:00+00'::timestamptz))
  Rows Removed by Filter: 14608
  Buffers: shared hit=442
```
PostgreSQL scanned all 442 pages of `payments`, evaluating 15,008 rows and discarding 14,608 rows.

By deploying the partial covering index `idx_payments_exceptions_partial` with `WHERE payment_status IN ('FAILED', 'REFUNDED')`, the B-Tree stores only the 400 exception rows. The planner shifted to:
```text
Index Only Scan using idx_payments_exceptions_partial on public.payments p  (cost=0.28..39.24 rows=398 width=74) (actual time=0.120..1.279 rows=400 loops=1)
  Index Cond: (p.paid_at >= '2026-05-31 23:00:00+00'::timestamptz)
  Heap Fetches: 0
  Buffers: shared hit=9
```
This cut `payments` buffer reads from **442 pages down to 9 pages (a 98.0% I/O reduction)** and reduced total query latency from **56.246 ms to 12.080 ms (a 4.7x speedup)**.

### 6.2 Partial Covering Index for Active Reservations (Query 4 Analysis)
In a mature hotel database, historical `CHECKED_OUT` reservations account for >95% of rows in `bookings`, while currently active reservations (`CONFIRMED` and `CHECKED_IN`) represent a small operational working set. By indexing `(check_in_date, guest_id) INCLUDE (total_amount, booking_id) WHERE booking_status IN ('CONFIRMED', 'CHECKED_IN')`, Query 4 bypassed 425 heap pages, reducing buffer hits from **431 pages to 11 pages** and cutting execution time from **38.215 ms to 1.898 ms (20.1x speedup)**.

### 6.3 Trade-Offs of Indexing in High-Throughput Hospitality Systems
While covering and partial indexes dramatically accelerate analytical and reporting queries, they require careful engineering balance:
- **Write Amplification:** Every new booking or status transition (`CONFIRMED` $\to$ `CHECKED_IN` $\to$ `CHECKED_OUT`) must update the heap tuple and maintain all matching B-Tree indexes.
- **Visibility Map Maintenance:** PostgreSQL's `Index Only Scan` relies on the Visibility Map (VM) to confirm that all tuples on a heap page are visible to all current transactions. Without regular `AUTOVACUUM` or `VACUUM ANALYZE`, an `Index Only Scan` degrades into heap fetches.

---

## 7. How to Reproduce the Benchmark

To run the complete Portfolio 2 benchmark inside the active Docker environment:

```bash
# 1. Scale the database to 15,008 bookings and 15,008 payments
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-2/01-data-generator.sql

# 2. Run unoptimized queries (capturing baseline EXPLAIN plans)
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-2/02-unoptimized-queries.sql

# 3. Apply strategic optimization indexes and VACUUM ANALYZE
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-2/03-optimization-indexes.sql

# 4. Run optimized queries (measuring execution plan improvements)
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-2/04-optimized-queries.sql
```

---

## 8. Technical Reflection & Lessons Learned

### 8.1 Personal Engineering Takeaways
- **Visibility Map & `VACUUM ANALYZE` for Index-Only Scans:** During my initial benchmark run, I noticed that even after creating a covering index with `INCLUDE`, PostgreSQL still performed a `Bitmap Heap Scan` touching 298 heap blocks because the newly inserted 15,000 rows did not yet have their all-visible bits set in the Visibility Map. Running `VACUUM ANALYZE` after bulk data loading updated the Visibility Map and immediately unlocked `Index Only Scan` with `Heap Fetches: 0`.
- **Trigger Overhead During Bulk Seeding:** When generating 15,000 historical bookings in `01-data-generator.sql`, firing the overlap-check trigger `trg_validate_booking_rules` 15,000 times sequentially would have caused $O(N^2)$ range lookups. Temporarily disabling the trigger during deterministic non-overlapping bulk generation and re-enabling it afterward kept the data generation under 2 seconds while preserving strict runtime trigger protection.

---

## 9. Academic Integrity and AI Use Declaration

*(In accordance with Section 11 of the Continuous Assessment Syllabus)*

1. **AI Tools Used:** Claude / AI Programming Assistant
2. **Specific Tasks Where AI Was Used:**
   - Reviewing PostgreSQL 16 `INCLUDE` covering index column ordering and Visibility Map (`VACUUM ANALYZE`) behavior for Index-Only Scans.
   - Formatting raw `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)` outputs into Markdown comparison tables.
3. **Student Verification & Ownership:**
   - I designed the hospitality analytical queries (corporate/OTA channel surveillance, Night Audit gateway exceptions, room running revenue window functions, loyalty cap compliance, and Executive Tower tax yield).
   - I wrote and executed the volumetric generator and index scripts inside the live PostgreSQL 16 container and verified all execution plan metrics.
