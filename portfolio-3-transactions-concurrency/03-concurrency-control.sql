-- Concurrency Control & Double-Booking Prevention
-- MIT 8103 Advanced Database Systems - Portfolio 3
-- Case Study: EkoStay Hospitality Limited

-- Inspect active lock states on rooms and bookings
SELECT
    locktype,
    relation::regclass AS table_name,
    mode,
    granted,
    pid
FROM pg_locks
WHERE relation IN ('rooms'::regclass, 'bookings'::regclass);

-- 1. Pessimistic Row Locking (SELECT FOR UPDATE) - Preventing Concurrent Double-Booking
-- Simulate two simultaneous requests for Presidential Penthouse E502 for New Year's Eve
-- Request 1 (Mobile App): Ibrahim Suleiman books E502 for 2026-12-20 to 2026-12-23
-- Request 2 (OTA Channel): Segun Adeleke attempts to book E502 for 2026-12-21 to 2026-12-24
\echo 'Testing Pessimistic Locking (SELECT FOR UPDATE) Against Double-Booking'

DO $$
DECLARE
    v_res1 RECORD;
    v_res2 RECORD;
BEGIN
    RAISE NOTICE 'Executing Reservation Request 1 for Penthouse E502 (2026-12-20 to 2026-12-23)...';
    SELECT * INTO v_res1 FROM sp_create_room_reservation(
        'a0000000-0000-0000-0000-000000000003',
        'E502',
        DATE '2026-12-20',
        DATE '2026-12-23',
        4,
        'BANK_TRANSFER_NIP',
        'NIBSS_NIP_DIRECT',
        'MOBILE_APP',
        'VIP New Year Retreat Request 1'
    );
    RAISE NOTICE 'Request 1 Result: % (Ref: %, Total: % NGN)',
        v_res1.reservation_status, v_res1.booking_reference, v_res1.total_folio_charged;

    RAISE NOTICE 'Executing Concurrent Reservation Request 2 for Penthouse E502 (2026-12-21 to 2026-12-24)...';
    BEGIN
        SELECT * INTO v_res2 FROM sp_create_room_reservation(
            'a0000000-0000-0000-0000-000000000009',
            'E502',
            DATE '2026-12-21',
            DATE '2026-12-24',
            2,
            'DEBIT_CARD',
            'PAYSTACK',
            'OTA_BOOKING_COM',
            'Concurrent overlapping OTA booking attempt'
        );
        RAISE EXCEPTION 'Double-booking bug allowed!';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Request 2 rejected as expected under serialized room lock: %', SQLERRM;
    END;
END $$;

-- Verify only 1 active reservation exists on Penthouse E502 for Dec 2026
SELECT
    b.booking_reference,
    r.room_number,
    g.first_name || ' ' || g.last_name AS booked_guest,
    b.check_in_date,
    b.check_out_date,
    b.total_amount,
    b.booking_status
FROM bookings b
JOIN rooms r ON b.room_id = r.room_id
JOIN guests g ON b.guest_id = g.guest_id
WHERE r.room_number = 'E502'
  AND b.check_in_date >= DATE '2026-12-01';

-- 2. Optimistic Concurrency Control (OCC) Pattern
-- Used when two housekeeping/front-desk agents concurrently update room status using version token (updated_at)
\echo 'Testing Optimistic Concurrency Control (OCC) on Room Housekeeping Status'

DO $$
DECLARE
    v_room_id UUID := 'b0000000-0000-0000-0000-000000000003'; -- Room A103 (DIRTY_CLEANING)
    v_expected_updated_at TIMESTAMPTZ;
    v_rows_affected INT;
BEGIN
    -- Step 1: Housekeeping supervisor reads Room A103 state and version token
    SELECT updated_at INTO v_expected_updated_at
    FROM rooms
    WHERE room_id = v_room_id;

    RAISE NOTICE 'Agent 1 read Room A103 version token: %', v_expected_updated_at;

    -- Step 2: Interleaved update by Facility Engineering marking room AVAILABLE
    UPDATE rooms
    SET room_status = 'AVAILABLE', updated_at = CURRENT_TIMESTAMP + INTERVAL '1 second'
    WHERE room_id = v_room_id;

    RAISE NOTICE 'Concurrent Agent 2 update committed (A103 -> AVAILABLE).';

    -- Step 3: Agent 1 attempts to update using stale version token
    UPDATE rooms
    SET room_status = 'OUT_OF_ORDER'
    WHERE room_id = v_room_id
      AND updated_at = v_expected_updated_at;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected = 0 THEN
        RAISE NOTICE 'OCC Conflict detected: 0 rows updated because Room A103 was modified concurrently.';
    ELSE
        RAISE EXCEPTION 'OCC failed: Stale write was accepted.';
    END IF;

    -- Restore Room A103 status to DIRTY_CLEANING
    UPDATE rooms
    SET room_status = 'DIRTY_CLEANING'
    WHERE room_id = v_room_id;
END $$;
