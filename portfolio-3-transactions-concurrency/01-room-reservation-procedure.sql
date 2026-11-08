-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 3 - Transactions and Concurrency
-- Case Study: EkoStay Hospitality Limited
-- File: 01-room-reservation-procedure.sql
-- Description: ACID-compliant stored functions implementing atomic room reservations,
--              payment settlements, and multi-room group bookings with deterministic
--              row locking, loyalty tier ceiling checks, and double-booking prevention.
-- Author: Rabiu Sekinah (301870666)

-- 1. CORE STORED FUNCTION: sp_create_room_reservation
-- Purpose: Atomically validates room status, prevents concurrent double-booking via
--          pessimistic row locking (SELECT ... FOR UPDATE), verifies loyalty tier active
--          booking limits, calculates 12.5% statutory taxes (7.5% VAT + 5% Consumption Tax),
--          inserts the booking, and settles the payment.
CREATE OR REPLACE FUNCTION sp_create_room_reservation(
    p_guest_id UUID,
    p_room_number CHAR(4),
    p_check_in_date DATE,
    p_check_out_date DATE,
    p_num_guests INT,
    p_payment_method VARCHAR(25),
    p_gateway_provider VARCHAR(30),
    p_booking_channel VARCHAR(25) DEFAULT 'MOBILE_APP',
    p_special_requests VARCHAR(255) DEFAULT 'Standard check-in'
)
RETURNS TABLE (
    reservation_status VARCHAR(20),
    message TEXT,
    booking_reference VARCHAR(64),
    payment_reference VARCHAR(64),
    total_folio_charged NUMERIC(18, 4),
    discount_applied NUMERIC(18, 4)
) AS $$
DECLARE
    v_room_id UUID;
    v_room_status VARCHAR(20);
    v_category_id INT;
    v_base_rate NUMERIC(15, 2);
    v_max_occupancy INT;

    v_guest_status VARCHAR(25);
    v_loyalty_tier INT;
    v_discount_pct NUMERIC(5, 2);
    v_max_active_bookings INT;
    v_current_active_bookings INT := 0;

    v_conflict_ref VARCHAR(64);
    v_nights INT;
    v_gross_room_charge NUMERIC(18, 4);
    v_discount_amt NUMERIC(18, 4);
    v_subtotal_amt NUMERIC(18, 4);
    v_tax_amt NUMERIC(18, 4);
    v_total_amt NUMERIC(18, 4);
    v_processing_fee NUMERIC(18, 4) := 1500.0000;

    v_booking_id UUID;
    v_booking_ref VARCHAR(64);
    v_payment_ref VARCHAR(64);
    v_gateway_session VARCHAR(40);
BEGIN
    -- 1. Input Date & Occupancy Validation
    IF p_check_out_date <= p_check_in_date THEN
        RAISE EXCEPTION 'Reservation rejected: check_out_date (%) must be strictly after check_in_date (%).',
            p_check_out_date, p_check_in_date;
    END IF;

    IF p_num_guests <= 0 THEN
        RAISE EXCEPTION 'Reservation rejected: num_guests must be at least 1.';
    END IF;

    v_nights := (p_check_out_date - p_check_in_date);

    -- 2. Pessimistic Row-Level Lock on Target Room Inventory (SELECT ... FOR UPDATE)
    -- Serializes concurrent reservation requests targeting the same physical room.
    SELECT r.room_id, r.room_status, r.category_id, rc.base_nightly_rate, rc.max_occupancy
    INTO v_room_id, v_room_status, v_category_id, v_base_rate, v_max_occupancy
    FROM rooms r
    JOIN room_categories rc ON r.category_id = rc.category_id
    WHERE r.room_number = p_room_number
    FOR UPDATE OF r;

    IF v_room_id IS NULL THEN
        RAISE EXCEPTION 'Reservation rejected: Room % does not exist in inventory.', p_room_number;
    END IF;

    -- 3. Operational Room Status & Capacity Verification
    IF v_room_status = 'OUT_OF_ORDER' THEN
        RAISE EXCEPTION 'Reservation rejected: Room % is currently in OUT_OF_ORDER maintenance status.', p_room_number;
    END IF;

    IF p_num_guests > v_max_occupancy THEN
        RAISE EXCEPTION 'Reservation rejected: Guest count (%) exceeds max occupancy (%) for Room %.',
            p_num_guests, v_max_occupancy, p_room_number;
    END IF;

    -- 4. Guest Standing & Loyalty Tier Ceiling Verification
    SELECT g.guest_status, g.loyalty_tier, lt.discount_percentage, lt.max_active_bookings
    INTO v_guest_status, v_loyalty_tier, v_discount_pct, v_max_active_bookings
    FROM guests g
    JOIN loyalty_tiers lt ON g.loyalty_tier = lt.tier_level
    WHERE g.guest_id = p_guest_id;

    IF v_guest_status IS NULL THEN
        RAISE EXCEPTION 'Reservation rejected: Guest % does not exist.', p_guest_id;
    END IF;

    IF v_guest_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Reservation rejected: Guest profile % is in % status.', p_guest_id, v_guest_status;
    END IF;

    SELECT COUNT(*) INTO v_current_active_bookings
    FROM bookings b
    WHERE b.guest_id = p_guest_id
      AND b.booking_status IN ('CONFIRMED', 'CHECKED_IN')
      AND b.check_out_date >= CURRENT_DATE;

    IF v_current_active_bookings >= v_max_active_bookings THEN
        RAISE EXCEPTION 'Reservation rejected: Loyalty Tier % active booking limit reached (Current: %, Max Allowed: %).',
            v_loyalty_tier, v_current_active_bookings, v_max_active_bookings;
    END IF;

    -- 5. Overlapping Stay Window Check (Under Exclusive Room Row Lock)
    SELECT b.booking_reference INTO v_conflict_ref
    FROM bookings b
    WHERE b.room_id = v_room_id
      AND b.booking_status IN ('CONFIRMED', 'CHECKED_IN')
      AND b.check_in_date < p_check_out_date
      AND b.check_out_date > p_check_in_date
    LIMIT 1;

    IF v_conflict_ref IS NOT NULL THEN
        RAISE EXCEPTION 'Reservation rejected: Room % is already booked under reference % for overlapping dates (% to %).',
            p_room_number, v_conflict_ref, p_check_in_date, p_check_out_date;
    END IF;

    -- 6. Compute Tariff, Loyalty Discount & 12.5% Statutory Taxes (7.5% VAT + 5% Consumption Tax)
    v_gross_room_charge := round((v_base_rate * v_nights)::numeric, 4);
    v_discount_amt := round((v_gross_room_charge * (v_discount_pct / 100.0))::numeric, 4);
    v_subtotal_amt := v_gross_room_charge - v_discount_amt;
    v_tax_amt := round((v_subtotal_amt * 0.125)::numeric, 4);
    v_total_amt := v_subtotal_amt + v_tax_amt;

    IF p_gateway_provider = 'NIBSS_NIP_DIRECT' THEN
        v_processing_fee := 53.7500;
    ELSIF p_gateway_provider IN ('PAYSTACK', 'FLUTTERWAVE') THEN
        v_processing_fee := 2000.0000;
    END IF;

    -- 7. Atomic Reservation Insertion
    v_booking_id := gen_random_uuid();
    v_booking_ref := 'EKO-RES-' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISSMS') || '-' || substr(md5(random()::text), 1, 4);

    INSERT INTO bookings (
        booking_id, booking_reference, guest_id, room_id, check_in_date, check_out_date,
        num_guests, nightly_rate_applied, discount_amount, subtotal_amount, tax_amount, total_amount,
        booking_status, booking_channel, special_requests, created_at
    ) VALUES (
        v_booking_id,
        v_booking_ref,
        p_guest_id,
        v_room_id,
        p_check_in_date,
        p_check_out_date,
        p_num_guests,
        v_base_rate,
        v_discount_amt,
        v_subtotal_amt,
        v_tax_amt,
        v_total_amt,
        'CONFIRMED',
        p_booking_channel,
        p_special_requests,
        CURRENT_TIMESTAMP
    );

    -- 8. Atomic Folio Payment Settlement Insertion
    v_payment_ref := 'EKO-PAY-' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISSMS') || '-' || substr(md5(random()::text), 1, 4);
    v_gateway_session := substr(p_gateway_provider, 1, 3) || '_' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISS') || '_' || lpad((random() * 999999)::int::text, 6, '0');

    INSERT INTO payments (
        payment_id, payment_reference, booking_id, guest_id, payment_method,
        gateway_provider, gateway_session_id, currency, amount_paid, processing_fee,
        payment_status, narration, paid_at
    ) VALUES (
        gen_random_uuid(),
        v_payment_ref,
        v_booking_id,
        p_guest_id,
        p_payment_method,
        p_gateway_provider,
        v_gateway_session,
        'NGN',
        v_total_amt,
        v_processing_fee,
        'COMPLETED',
        'Atomic reservation payment for ' || v_booking_ref || ' (Room ' || p_room_number || ')',
        CURRENT_TIMESTAMP
    );

    RETURN QUERY SELECT
        'SUCCESS'::VARCHAR(20),
        ('Reservation confirmed and settled for Room ' || p_room_number)::TEXT,
        v_booking_ref,
        v_payment_ref,
        v_total_amt,
        v_discount_amt;
END;
$$ LANGUAGE plpgsql;

-- 2. MULTI-ROOM GROUP BOOKING PROCEDURE WITH DETERMINISTIC LOCK ORDERING: sp_book_room_pair
-- Purpose: When corporate event desks reserve two rooms simultaneously (Room X and Room Y),
--          locking them in arbitrary caller order causes circular wait deadlocks (40P01).
--          This function enforces ascending alphabetical lock ordering on room_number.
CREATE OR REPLACE FUNCTION sp_book_room_pair(
    p_guest_id UUID,
    p_room_number_1 CHAR(4),
    p_room_number_2 CHAR(4),
    p_check_in_date DATE,
    p_check_out_date DATE,
    p_channel VARCHAR(25) DEFAULT 'CORPORATE_DESK'
)
RETURNS TABLE (
    pair_booking_status VARCHAR(20),
    first_room_locked CHAR(4),
    second_room_locked CHAR(4),
    booking_ref_1 VARCHAR(64),
    booking_ref_2 VARCHAR(64),
    combined_total NUMERIC(18, 4)
) AS $$
DECLARE
    v_lock_first CHAR(4);
    v_lock_second CHAR(4);
    v_dummy_id UUID;
    v_res1 RECORD;
    v_res2 RECORD;
BEGIN
    IF p_room_number_1 = p_room_number_2 THEN
        RAISE EXCEPTION 'Dual room booking requires two distinct room numbers.';
    END IF;

    -- Deterministic Global Lock Ordering: Always lock the lexicographically smaller room_number first
    IF p_room_number_1 < p_room_number_2 THEN
        v_lock_first := p_room_number_1;
        v_lock_second := p_room_number_2;
    ELSE
        v_lock_first := p_room_number_2;
        v_lock_second := p_room_number_1;
    END IF;

    SELECT room_id INTO v_dummy_id FROM rooms WHERE room_number = v_lock_first FOR UPDATE;
    SELECT room_id INTO v_dummy_id FROM rooms WHERE room_number = v_lock_second FOR UPDATE;

    -- Execute reservation leg 1 and leg 2 inside the same atomic transaction
    SELECT * INTO v_res1 FROM sp_create_room_reservation(
        p_guest_id, p_room_number_1, p_check_in_date, p_check_out_date, 2,
        'CORPORATE_INVOICE', 'NIBSS_NIP_DIRECT', p_channel, 'Corporate dual-room block leg 1'
    );

    SELECT * INTO v_res2 FROM sp_create_room_reservation(
        p_guest_id, p_room_number_2, p_check_in_date, p_check_out_date, 2,
        'CORPORATE_INVOICE', 'NIBSS_NIP_DIRECT', p_channel, 'Corporate dual-room block leg 2'
    );

    RETURN QUERY SELECT
        'SUCCESS'::VARCHAR(20),
        v_lock_first,
        v_lock_second,
        v_res1.booking_reference,
        v_res2.booking_reference,
        (v_res1.total_folio_charged + v_res2.total_folio_charged);
END;
$$ LANGUAGE plpgsql;
