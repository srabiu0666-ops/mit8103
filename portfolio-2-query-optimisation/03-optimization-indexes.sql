-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 2 - Query Processing and Optimisation
-- Case Study: EkoStay Hospitality Limited
-- File: 03-optimization-indexes.sql
-- Description: Strategic indexing implementation targeting hospitality query bottlenecks.
--              Includes composite B-Trees, partial indexes, and covering indexes with INCLUDE.
-- Author: Rabiu Sekinah (301870666)

-- Clean teardown of optimization indexes if previously applied
DROP INDEX IF EXISTS idx_payments_exceptions_partial;
DROP INDEX IF EXISTS idx_bookings_checkin_channel_covering;
DROP INDEX IF EXISTS idx_bookings_room_checkin_composite;
DROP INDEX IF EXISTS idx_bookings_status_guest_covering;
DROP INDEX IF EXISTS idx_rooms_executive_tower_covering;
DROP INDEX IF EXISTS idx_rooms_number_covering;

-- 1. PARTIAL INDEX: Failed & Refunded Payment Gateway Exceptions (Targets Query 2)
-- Architecture Rationale:
-- Over 96% of hotel payments succeed (`COMPLETED`). Scanning all 15,008 payment records
-- during Night Audit reconciliation wastes buffer memory and I/O.
-- By applying `WHERE payment_status IN ('FAILED', 'REFUNDED')`, this partial index
-- physically indexes only the ~3.5% exception rows, enabling an Index-Only Scan.
CREATE INDEX idx_payments_exceptions_partial
ON payments(paid_at, gateway_provider, payment_method, payment_status)
INCLUDE (payment_id, booking_id, amount_paid)
WHERE payment_status IN ('FAILED', 'REFUNDED');

COMMENT ON INDEX idx_payments_exceptions_partial IS
'Partial covering index filtering exclusively for failed and refunded payment gateway records.';

-- 2. COMPOSITE COVERING INDEX: Date-Window & Channel Surveillance (Targets Query 1 & 5)
-- Architecture Rationale:
-- Query 1 & 5 filter bookings by `check_in_date` range, `booking_channel`, and `booking_status`.
-- Including `guest_id`, `room_id`, `booking_id`, `subtotal_amount`, `tax_amount`, `total_amount`,
-- and `check_out_date` in the INCLUDE payload allows PostgreSQL to evaluate monthly revenue
-- audits via an Index-Only Scan without visiting the bookings heap.
CREATE INDEX idx_bookings_checkin_channel_covering
ON bookings(check_in_date, booking_status, booking_channel)
INCLUDE (booking_id, guest_id, room_id, subtotal_amount, tax_amount, total_amount, check_out_date);

COMMENT ON INDEX idx_bookings_checkin_channel_covering IS
'Composite covering index accelerating date-range and booking-channel revenue audits.';

-- 3. COMPOSITE PRE-SORTED INDEX: Room Folio Running Revenue (Targets Query 3)
-- Architecture Rationale:
-- Query 3 computes running room revenue using a Window Function partitioned by `room_id`
-- and ordered by `check_in_date`. Storing leaf tuples pre-sorted on `(room_id, check_in_date)`
-- enables an Index-Only Scan for room statement generation.
CREATE INDEX idx_bookings_room_checkin_composite
ON bookings(room_id, check_in_date)
INCLUDE (check_out_date, booking_reference, booking_channel, booking_status, subtotal_amount, tax_amount, total_amount);

COMMENT ON INDEX idx_bookings_room_checkin_composite IS
'Pre-sorted composite covering index eliminating heap fetches in room running-revenue window queries.';

-- 4. PARTIAL COVERING INDEX: Active Bookings per Guest Audit (Targets Query 4)
-- Architecture Rationale:
-- Query 4 aggregates active (`CONFIRMED` and `CHECKED_IN`) bookings per guest.
-- Indexing `(check_in_date, guest_id)` with `INCLUDE (total_amount, booking_id)` filtered
-- to active statuses enables an Index-Only Scan on the small subset of active reservations.
CREATE INDEX idx_bookings_status_guest_covering
ON bookings(check_in_date, guest_id)
INCLUDE (total_amount, booking_id)
WHERE booking_status IN ('CONFIRMED', 'CHECKED_IN');

COMMENT ON INDEX idx_bookings_status_guest_covering IS
'Partial covering index for loyalty tier booking cap and monthly spend aggregation.';

-- 5. PARTIAL COVERING INDEX: Executive Tower Suite Turnover (Targets Query 5)
-- Architecture Rationale:
-- Filters exclusively for rooms in the `EXECUTIVE_TOWER` wing and includes `room_number`
-- and `category_id` so Executive Tower revenue reports avoid scanning all hotel wings.
CREATE INDEX idx_rooms_executive_tower_covering
ON rooms(room_id)
INCLUDE (room_number, category_id)
WHERE wing = 'EXECUTIVE_TOWER';

COMMENT ON INDEX idx_rooms_executive_tower_covering IS
'Partial covering index for Executive Tower suite revenue and tax yield reporting.';

-- 6. ROOM NUMBER LOOKUP COVERING INDEX: Instant Room Code Resolution
CREATE INDEX idx_rooms_number_covering
ON rooms(room_number)
INCLUDE (room_id, category_id, wing, room_status);

COMMENT ON INDEX idx_rooms_number_covering IS
'Covering index for zero-heap-fetch room number lookups.';

-- Refresh planner statistics AND build visibility maps via VACUUM ANALYZE so PostgreSQL
-- can immediately execute Index-Only Scans without heap page fetches.
VACUUM ANALYZE payments;
VACUUM ANALYZE bookings;
VACUUM ANALYZE rooms;
VACUUM ANALYZE guests;
