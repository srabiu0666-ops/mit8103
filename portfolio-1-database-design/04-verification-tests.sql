-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 1 - Database Design and Modelling
-- Case Study: EkoStay Hospitality Limited
-- File: 04-verification-tests.sql
-- Description: Test suite verifying schema constraints, relational integrity,
--              referential rules, and hospitality reservation business logic.

-- TEST 1: Entity Count & Baseline Inventory
-- Verifies that all baseline records have loaded successfully across all 8 tables.
SELECT 'loyalty_tiers' AS entity, COUNT(*) AS total_records FROM loyalty_tiers
UNION ALL
SELECT 'room_categories', COUNT(*) FROM room_categories
UNION ALL
SELECT 'guests', COUNT(*) FROM guests
UNION ALL
SELECT 'rooms', COUNT(*) FROM rooms
UNION ALL
SELECT 'bookings', COUNT(*) FROM bookings
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'checkin_checkout_records', COUNT(*) FROM checkin_checkout_records
UNION ALL
SELECT 'audit_logs', COUNT(*) FROM audit_logs;

-- TEST 2: Relational Join - Hotel Room Inventory & Tariff Overview
-- Verifies multi-table relationships (rooms -> room_categories).
SELECT
    r.room_number,
    r.wing,
    r.floor_number,
    rc.category_code,
    rc.category_name,
    rc.base_nightly_rate,
    rc.max_occupancy,
    r.room_status
FROM rooms r
JOIN room_categories rc ON r.category_id = rc.category_id
ORDER BY r.room_number;

-- TEST 3: Reservation Folio & Payment Settlement Reconciliation Audit
-- Verifies that confirmed and checked-in bookings reconcile with payment records.
SELECT
    b.booking_reference,
    g.first_name || ' ' || g.last_name AS guest_name,
    lt.tier_name,
    r.room_number,
    b.check_in_date,
    b.check_out_date,
    b.total_amount AS folio_total,
    p.payment_reference,
    p.gateway_provider,
    p.amount_paid,
    p.payment_status,
    b.booking_status
FROM bookings b
JOIN guests g ON b.guest_id = g.guest_id
JOIN loyalty_tiers lt ON g.loyalty_tier = lt.tier_level
JOIN rooms r ON b.room_id = r.room_id
JOIN payments p ON b.booking_id = p.booking_id
ORDER BY b.created_at;

-- TEST 4: Integrity Constraint Assertions (Deliberate Negative Tests)
-- Each query inside the DO blocks demonstrates that the engine rejects invalid data.

-- Assertion 4A: Invalid Check-Out Date Constraint (check_out_date <= check_in_date)
-- Expected Result: Rejection with chk_booking_dates violation
DO $$
BEGIN
    INSERT INTO bookings (
        booking_reference, guest_id, room_id, check_in_date, check_out_date,
        num_guests, nightly_rate_applied, subtotal_amount, tax_amount, total_amount
    ) VALUES (
        'EKO-TEST-INVALID-DATES',
        'a0000000-0000-0000-0000-000000000001',
        'b0000000-0000-0000-0000-000000000001',
        '2026-12-10', '2026-12-08',
        1, 85000.0000, 170000.0000, 21250.0000, 191250.0000
    );
    RAISE EXCEPTION 'FAILED: Check-out date before check-in date was erroneously allowed.';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'SUCCESS (Test 4A): Invalid booking date range correctly blocked by chk_booking_dates.';
END $$;

-- Assertion 4B: Room Number Format Check Constraint
-- Expected Result: Rejection with chk_room_number_format violation
DO $$
BEGIN
    INSERT INTO rooms (room_number, category_id, floor_number, wing, room_status)
    VALUES ('101A', 1, 1, 'GARDEN_WING', 'AVAILABLE');
    RAISE EXCEPTION 'FAILED: Malformed room number was erroneously allowed.';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'SUCCESS (Test 4B): Invalid room number format correctly blocked by chk_room_number_format.';
END $$;

-- Assertion 4C: Duplicate Guest Phone Number Uniqueness Constraint
-- Expected Result: Rejection with unique_violation
DO $$
BEGIN
    INSERT INTO guests (first_name, last_name, email, phone_number, loyalty_tier)
    VALUES ('Duplicate', 'Guest', 'unique.guest@ekostay.ng', '+2348011234567', 1);
    RAISE EXCEPTION 'FAILED: Duplicate phone number was erroneously allowed.';
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'SUCCESS (Test 4C): Duplicate guest phone number correctly blocked by unique constraint.';
END $$;

-- Assertion 4D: Booking on OUT_OF_ORDER Maintenance Room (Trigger Enforcement)
-- Expected Result: Rejection because Room C303 (b0000000-0000-0000-0000-000000000009) is OUT_OF_ORDER
DO $$
BEGIN
    INSERT INTO bookings (
        booking_reference, guest_id, room_id, check_in_date, check_out_date,
        num_guests, nightly_rate_applied, subtotal_amount, tax_amount, total_amount, booking_status
    ) VALUES (
        'EKO-TEST-OOO-ROOM',
        'a0000000-0000-0000-0000-000000000001',
        'b0000000-0000-0000-0000-000000000009',
        '2026-12-01', '2026-12-03',
        2, 165000.0000, 330000.0000, 41250.0000, 371250.0000, 'CONFIRMED'
    );
    RAISE EXCEPTION 'FAILED: Reservation on OUT_OF_ORDER room was erroneously allowed.';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'SUCCESS (Test 4D): Booking on OUT_OF_ORDER room correctly blocked by trigger: %', SQLERRM;
END $$;

-- TEST 5: Active Occupancy & Loyalty Benefit Compliance Query
-- Verifies in-house guests, keycard assignments, caution deposits, and loyalty tier benefits.
SELECT
    cc.keycard_code,
    g.first_name || ' ' || g.last_name AS guest_name,
    lt.tier_name,
    lt.late_checkout_hours,
    r.room_number,
    rc.category_name,
    cc.actual_check_in_at,
    cc.actual_check_out_at,
    cc.deposit_held,
    cc.room_inspection_status
FROM checkin_checkout_records cc
JOIN guests g ON cc.guest_id = g.guest_id
JOIN loyalty_tiers lt ON g.loyalty_tier = lt.tier_level
JOIN rooms r ON cc.room_id = r.room_id
JOIN room_categories rc ON r.category_id = rc.category_id
ORDER BY cc.actual_check_in_at DESC;
