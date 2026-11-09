# Portfolio 3: Transactions and Concurrency

**Course:** MIT 8103 – Advanced Database Systems  
**Academic Session:** 2026/2027  
**Case Study:** EkoStay Hospitality Limited  
**Deliverable:** ACID Guarantees, Stored Procedures, Concurrency Control, Isolation Levels, and Deadlock Resolution  
**Component Score Weight:** 7 Marks  
**Author:** Rabiu Sekinah (`301870666`)  

---

## 1. Executive Summary & Hospitality Reservation Context

In an enterprise hotel reservation system receiving concurrent booking requests across mobile apps, web portals, corporate travel desks, and online travel agencies (OTAs like Booking.com), transactional integrity and concurrency control are critical. A double-booking race condition on a luxury suite, an unrecorded payment leg, or a circular deadlock during multi-room corporate block reservations directly harms guest trust and hotel revenue.

In this third portfolio milestone, I implemented and verified EkoStay's core reservation transaction engine. I developed two ACID-compliant PL/pgSQL stored procedures (`sp_create_room_reservation` and `sp_book_room_pair`), verified atomic commits and rollbacks under operational failure scenarios, demonstrated double-booking prevention using pessimistic row-level locks (`SELECT ... FOR UPDATE`), evaluated PostgreSQL's MVCC isolation levels, and enforced deterministic lock ordering to mathematically eliminate deadlocks.

---

## 2. ACID Implementation Architecture in EkoStay

| Property | EkoStay Implementation Mechanism | Practical Verification |
| :--- | :--- | :--- |
| **Atomicity** | PL/pgSQL transaction block inserting both `bookings` and `payments` atomically; sub-transactions via nested `BEGIN ... EXCEPTION` savepoints. | Verified in `02-commit-rollback-tests.sql`: Failed date-overlap or maintenance checks rollback 100% of reservation and payment mutations. |
| **Consistency** | Database-level invariants: `chk_booking_dates`, `chk_room_status`, occupancy limits (`max_occupancy`), and loyalty tier booking ceilings. | Verified in `02-commit-rollback-tests.sql`: Bookings on `OUT_OF_ORDER` rooms (`C303`) and overlapping date ranges are rejected. |
| **Isolation** | PostgreSQL Multi-Version Concurrency Control (MVCC) combined with pessimistic row-level locks (`FOR UPDATE OF r`) on `rooms`. | Verified in `03-concurrency-control.sql`: Concurrent requests for Presidential Penthouse `E502` are serialized, preventing double-booking. |
| **Durability** | PostgreSQL Write-Ahead Logging (WAL) with `fsync` flushing to disk before client acknowledgment, plus trigger-driven `audit_logs`. | Committed reservations and folio payments persist across container restarts with immutable JSONB audit trails. |

---

## 3. Atomic Stored Procedures: `sp_create_room_reservation` & `sp_book_room_pair`

The primary stored procedure (`01-room-reservation-procedure.sql`) encapsulates all business and tax rules required for atomic room reservations:

```text
sp_create_room_reservation(
    p_guest_id, p_room_number, p_check_in_date, p_check_out_date,
    p_num_guests, p_payment_method, p_gateway_provider, p_booking_channel, p_special_requests
)
```

### Execution Flow & Key Invariants:
1. **Input Date & Occupancy Validation:** Rejects non-positive stay durations (`check_out_date <= check_in_date`) and invalid guest counts.
2. **Pessimistic Room Row Locking (`SELECT ... FOR UPDATE OF r`):** Acquires an exclusive row lock on the target room in `rooms`, serializing any concurrent transaction attempting to book the same room.
3. **Operational Status & Capacity Guard:** Confirms the room is not `OUT_OF_ORDER` and `p_num_guests <= max_occupancy`.
4. **Guest Standing & Loyalty Ceiling Check:** Confirms the guest is `ACTIVE` (blocking `BLACKLISTED` guests) and verifies active bookings do not exceed `loyalty_tiers.max_active_bookings`.
5. **Overlapping Date Range Check:** Queries `bookings` under the held room lock (`check_in_date < p_check_out_date AND check_out_date > p_check_in_date`) to guarantee zero date collisions.
6. **Tariff, Loyalty Discount & 12.5% Tax Calculation:** Computes gross room tariff, deducts the guest's loyalty tier discount (`0%` to `15%`), and adds statutory Nigerian hospitality taxes (7.5% VAT + 5% State Consumption Tax = 12.5%).
7. **Atomic Folio & Payment Posting:** Inserts the confirmed reservation into `bookings` and the settled payment record into `payments` within a single transaction.

---

## 4. Empirical Verification & Test Evidence

### 4.1 Test 1: Successful Atomic Reservation & Payment (COMMIT)
- **Scenario:** Tunde Bakare (`Gold Ambassador`, 10% discount) books Room `A101` (`₦85,000/night`) for 3 nights (`2026-12-01` to `2026-12-04`).
- **Result (`evidence/01-commit-rollback-output.log`):**
  - Gross charge: `₦255,000.0000` | Gold 10% Discount: `₦25,500.0000` | Net Subtotal: `₦229,500.0000` | 12.5% Tax: `₦28,687.5000` | Total Folio Charged: `₦258,187.5000`.
  - Atomically generated booking `EKO-RES-20261112211324549-b8ef` and Paystack payment `EKO-PAY-20261112211324549-9c51`.

### 4.2 Test 2: Overlapping Dates Conflict (Automatic ROLLBACK)
- **Scenario:** Ngozi Achebe attempts to book Room `A101` for overlapping dates (`2026-12-02` to `2026-12-05`).
- **Output:**
  ```text
  NOTICE: Rollback verified: Reservation rejected: Room A101 is already booked under reference EKO-RES-20261112211324549-b8ef for overlapping dates (2026-12-02 to 2026-12-05).
  ```
- **Post-Test Verification:** Total December 2026 bookings for Room `A101` remained `1`.

### 4.3 Test 3: Maintenance Room Restriction (`OUT_OF_ORDER` ROLLBACK)
- **Scenario:** Attempting to book Room `C303` while it is under `OUT_OF_ORDER` engineering maintenance.
- **Output:**
  ```text
  NOTICE: Rollback verified: Reservation rejected: Room C303 is currently in OUT_OF_ORDER maintenance status.
  ```

### 4.4 Test 4: Nested Sub-Transaction & Savepoint Rollback
- **Scenario:** Leg 1 reserves Room `B202` (`2026-12-05` to `2026-12-07`, total `₦288,562.5000`); Leg 2 simulates a POS add-on calculation division-by-zero exception inside a nested block.
- **Output:**
  ```text
  NOTICE: Leg 1 finished: SUCCESS (Ref: EKO-RES-20261112211324964-bd60)
  NOTICE: Caught division by zero in add-on billing. Rolled back sub-operation 2 to savepoint.
  NOTICE: Outer transaction committed. Leg 1 reservation for Room B202 preserved.
  ```

---

## 5. Concurrency Control: Double-Booking Race Conditions & Deadlock Prevention

### 5.1 Preventing the Double-Booking Anomaly (`SELECT ... FOR UPDATE`)
In `03-concurrency-control.sql`, I simulated a peak-season race condition where two channels simultaneously request Presidential Penthouse `E502`:
- **Request 1 (Mobile App):** Ibrahim Suleiman requests `E502` for `2026-12-20` to `2026-12-23`.
- **Request 2 (OTA Booking.com):** Segun Adeleke requests `E502` for `2026-12-21` to `2026-12-24`.

Without row-level locking on the parent `rooms` row, two concurrent transactions under `READ COMMITTED` could both query `bookings` simultaneously, see zero existing rows for `E502`, and both insert overlapping bookings (because range overlap checks cannot be enforced by a simple single-column unique B-Tree index).

**Pessimistic Locking Resolution:**
- Request 1 executes `SELECT ... FROM rooms WHERE room_number = 'E502' FOR UPDATE OF r`, acquiring an exclusive lock on the `E502` room row.
- Request 2 blocks on `FOR UPDATE OF r` until Request 1 commits.
- Once Request 1 commits (`EKO-RES-20261112211327160-7cd9`, `₦1,864,687.5000`), Request 2 unblocks, runs the overlap check against the newly committed state, and aborts cleanly:
  ```text
  NOTICE: Request 1 Result: SUCCESS (Ref: EKO-RES-20261112211327160-7cd9, Total: 1864687.5000 NGN)
  NOTICE: Request 2 rejected as expected under serialized room lock: Reservation rejected: Room E502 is already booked under reference EKO-RES-20261112211327160-7cd9 for overlapping dates (2026-12-21 to 2026-12-24).
  ```

### 5.2 Deadlock Prevention in Multi-Room Group Bookings
A classic circular deadlock (`SQLSTATE 40P01`) occurs when corporate travel desks book pairs of rooms in opposite orders:
- **Session 1:** Locks Room `D402`, then waits to lock Room `D403`.
- **Session 2:** Locks Room `D403`, then waits to lock Room `D402`.

**EkoStay Mathematical Resolution (`sp_book_room_pair`):**
In `01-room-reservation-procedure.sql` and `05-deadlock-handling.sql`, I eliminated Coffman's *Circular Wait* condition by sorting the requested room numbers lexicographically before acquiring locks:
```sql
IF p_room_number_1 < p_room_number_2 THEN
    v_lock_first := p_room_number_1;
    v_lock_second := p_room_number_2;
ELSE
    v_lock_first := p_room_number_2;
    v_lock_second := p_room_number_1;
END IF;

SELECT room_id INTO v_dummy_id FROM rooms WHERE room_number = v_lock_first FOR UPDATE;
SELECT room_id INTO v_dummy_id FROM rooms WHERE room_number = v_lock_second FOR UPDATE;
```
Whether a caller passes `('D402', 'D403')` or `('D403', 'D402')`, both sessions acquire locks in the exact order `D402 -> D403`, completely preventing circular deadlocks.

---

## 6. PostgreSQL Isolation Levels Analysis

| Isolation Level | Behavior in EkoStay | Hospitality Use Case |
| :--- | :--- | :--- |
| **READ COMMITTED** *(Default)* | Each statement sees a fresh snapshot of data committed before the statement began. | Ideal for high-throughput room reservations when paired with `SELECT ... FOR UPDATE OF r` on `rooms`. |
| **REPEATABLE READ** | The entire transaction sees a consistent snapshot taken at the first query of the transaction. | Ideal for multi-query Night Audit financial reports (`04-isolation-levels.sql`) so mid-report tariff edits do not skew totals. |
| **SERIALIZABLE** | Full Serializable Snapshot Isolation (SSI) using SIREAD predicate locks. | Prevents write skew without explicit row locks, but incurs `40001` serialization aborts under heavy booking contention. |

---

## 7. How to Execute the Portfolio 3 Test Suite

```bash
# 1. Compile the reservation stored procedures
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-3/01-room-reservation-procedure.sql

# 2. Run atomic COMMIT, ROLLBACK, and Savepoint verification tests
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-3/02-commit-rollback-tests.sql

# 3. Run concurrency control (Penthouse double-booking & OCC housekeeping tests)
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-3/03-concurrency-control.sql

# 4. Run isolation levels analysis
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-3/04-isolation-levels.sql

# 5. Run multi-room deadlock prevention verification
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-3/05-deadlock-handling.sql
```

---

## 8. Technical Reflection & Lessons Learned

### 8.1 Key Engineering Insights
- **Why Locking the Parent `rooms` Row Solves Empty-Range Phantom Reads:**  
  In a hotel reservation system, checking `SELECT ... FROM bookings WHERE room_id = X FOR UPDATE` does **not** prevent double-booking if there are currently zero bookings for that date range—because `FOR UPDATE` cannot lock rows that do not exist yet! By locking the parent physical room row (`SELECT ... FROM rooms WHERE room_number = p_room_number FOR UPDATE OF r`), we serialize all reservation attempts for that room regardless of whether `bookings` currently has matching rows.
- **Scoped `FOR UPDATE OF r` on Joined Queries:**  
  When joining `rooms r` and `room_categories rc` inside `sp_create_room_reservation`, using an unqualified `FOR UPDATE` would lock both the room row and the shared `room_categories` row—which would unnecessarily serialize bookings across *different* rooms of the same category. Qualifying `FOR UPDATE OF r` locks only the specific physical room row.

---

## 9. Academic Integrity and AI Use Declaration

*(In accordance with Section 11 of the Continuous Assessment Syllabus)*

1. **AI Tools Used:** Claude / AI Programming Assistant
2. **Specific Tasks Where AI Was Used:**
   - Reviewing PostgreSQL `FOR UPDATE OF <table_alias>` syntax when joining `rooms` and `room_categories` inside PL/pgSQL.
   - Verifying nested `BEGIN ... EXCEPTION` sub-transaction savepoint semantics.
3. **Student Verification & Ownership:**
   - I designed the hospitality reservation procedure, loyalty discount and 12.5% Nigerian tax computation, parent-room locking strategy, and lexicographical multi-room lock ordering.
   - I executed all five SQL scripts inside the live PostgreSQL 16 Docker container and captured the empirical outputs in `evidence/`.
