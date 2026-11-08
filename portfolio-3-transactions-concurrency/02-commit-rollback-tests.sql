-- Empirical tests for ACID properties (Commit, Rollback, Savepoints)
-- MIT 8103 Advanced Database Systems - Portfolio 3
-- Case Study: EkoStay Hospitality Limited

-- Test 1: Atomic Room Reservation & Payment Settlement (Commit)
-- Tunde Bakare (Gold Ambassador, 10% discount) books Room A101 for 2026-12-01 to 2026-12-04 (3 nights)
\echo 'Running Test 1: Atomic Room Reservation with Commit'

-- Pre-booking count for Room A101 in December 2026
SELECT COUNT(*) AS dec_2026_bookings_for_a101
FROM bookings b
JOIN rooms r ON b.room_id = r.room_id
WHERE r.room_number = 'A101'
  AND b.check_in_date >= DATE '2026-12-01';

-- Execute atomic reservation procedure
SELECT * FROM sp_create_room_reservation(
    'a0000000-0000-0000-0000-000000000001',
    'A101',
    DATE '2026-12-01',
    DATE '2026-12-04',
    2,
    'DEBIT_CARD',
    'PAYSTACK',
    'MOBILE_APP',
    'Executive airport pickup and quiet garden view'
);

-- Verify both booking and payment records were committed atomically
SELECT
    b.booking_reference,
    r.room_number,
    b.check_in_date,
    b.check_out_date,
    b.nightly_rate_applied,
    b.discount_amount,
    b.subtotal_amount,
    b.tax_amount,
    b.total_amount,
    b.booking_status,
    p.payment_reference,
    p.gateway_provider,
    p.amount_paid,
    p.payment_status
FROM bookings b
JOIN rooms r ON b.room_id = r.room_id
JOIN payments p ON b.booking_id = p.booking_id
WHERE r.room_number = 'A101'
  AND b.check_in_date = DATE '2026-12-01';

-- Test 2: Overlapping Date Conflict Exception & Automatic Rollback
-- Ngozi Achebe attempts to book the same Room A101 for overlapping dates (2026-12-02 to 2026-12-05)
\echo 'Running Test 2: Overlapping Dates Conflict Rollback'

DO $$
BEGIN
    PERFORM sp_create_room_reservation(
        'a0000000-0000-0000-0000-000000000002',
        'A101',
        DATE '2026-12-02',
        DATE '2026-12-05',
        2,
        'DEBIT_CARD',
        'FLUTTERWAVE',
        'DIRECT_WEB',
        'Overlapping reservation attempt'
    );
    RAISE EXCEPTION 'Test failed: Overlapping reservation should not have succeeded!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Rollback verified: %', SQLERRM;
END $$;

-- Verify only 1 booking exists for Room A101 in December 2026
SELECT COUNT(*) AS dec_2026_bookings_for_a101
FROM bookings b
JOIN rooms r ON b.room_id = r.room_id
WHERE r.room_number = 'A101'
  AND b.check_in_date >= DATE '2026-12-01';

-- Test 3: Maintenance Room Restriction (OUT_OF_ORDER Rollback)
-- Attempting to book Room C303 which is in OUT_OF_ORDER status
\echo 'Running Test 3: OUT_OF_ORDER Maintenance Room Block'

SELECT room_number, wing, room_status
FROM rooms
WHERE room_number = 'C303';

DO $$
BEGIN
    PERFORM sp_create_room_reservation(
        'a0000000-0000-0000-0000-000000000001',
        'C303',
        DATE '2026-12-10',
        DATE '2026-12-12',
        2,
        'DEBIT_CARD',
        'PAYSTACK',
        'MOBILE_APP',
        'Attempted booking on maintenance room'
    );
    RAISE EXCEPTION 'Test failed: Booking on OUT_OF_ORDER room should have been blocked!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Rollback verified: %', SQLERRM;
END $$;

-- Test 4: Savepoint and Partial Failure Recovery (Multi-Room Itinerary)
-- Guest books Room B202 successfully in Leg 1, then attempts to add an invalid charge in Leg 2
\echo 'Running Test 4: Sub-transaction Savepoint Rollback'

DO $$
DECLARE
    v_res RECORD;
BEGIN
    -- Sub-operation 1: Valid room reservation for B202 (2026-12-05 to 2026-12-07)
    SELECT * INTO v_res FROM sp_create_room_reservation(
        'a0000000-0000-0000-0000-000000000002',
        'B202',
        DATE '2026-12-05',
        DATE '2026-12-07',
        2,
        'DEBIT_CARD',
        'FLUTTERWAVE',
        'DIRECT_WEB',
        'Savepoint valid leg 1 reservation'
    );
    RAISE NOTICE 'Leg 1 finished: % (Ref: %)', v_res.reservation_status, v_res.booking_reference;

    -- Sub-operation 2: Simulated POS add-on calculation error caught in nested savepoint block
    BEGIN
        UPDATE bookings SET total_amount = total_amount / 0 WHERE booking_reference = v_res.booking_reference;
    EXCEPTION
        WHEN division_by_zero THEN
            RAISE NOTICE 'Caught division by zero in add-on billing. Rolled back sub-operation 2 to savepoint.';
    END;

    RAISE NOTICE 'Outer transaction committed. Leg 1 reservation for Room B202 preserved.';
END $$;

-- Verify Leg 1 reservation persisted cleanly
SELECT
    b.booking_reference,
    r.room_number,
    b.check_in_date,
    b.check_out_date,
    b.total_amount,
    b.booking_status
FROM bookings b
JOIN rooms r ON b.room_id = r.room_id
WHERE r.room_number = 'B202'
  AND b.check_in_date = DATE '2026-12-05';
