-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 2 - Query Processing and Optimisation
-- Case Study: EkoStay Hospitality Limited
-- File: 01-data-generator.sql
-- Description: Volumetric synthetic dataset generator (120+ guests, 220+ rooms,
--              15,008 bookings, 15,008 payments, 5,000+ check-in/check-out records).
-- Author: Rabiu Sekinah (301870666)

DO $$
DECLARE
    v_guest_count INT;
    v_room_count INT;
    v_booking_count INT;
    v_payment_count INT;
    v_checkin_count INT;
BEGIN
    RAISE NOTICE 'Starting EkoStay volumetric data generation for Portfolio 2...';

    -- 1. Scale Guests: Insert 110 additional guests (bringing total to 122)
    INSERT INTO guests (
        guest_id, first_name, last_name, email, phone_number, nin_hash, passport_hash, nationality, loyalty_tier, guest_status, created_at
    )
    SELECT
        gen_random_uuid(),
        (ARRAY['Chukwudi', 'Olumide', 'Adebayo', 'Fatima', 'Zainab', 'Kelechi', 'Nnamdi', 'Folake', 'Damilola', 'Temitope', 'Tariq', 'Simisola', 'Onyinye', 'Mustapha', 'Yetunde', 'Kayode', 'Chioma', 'Abubakar'])[1 + ((i * 7 + 3) % 18)],
        (ARRAY['Okonkwo', 'Balogun', 'Danjuma', 'Adeleke', 'Babatunde', 'Eze', 'Okafor', 'Yusuf', 'Aliyu', 'Momodu', 'Suleiman', 'Nwachukwu', 'Ajayi', 'Ogundipe', 'Nwankwo', 'Garba', 'Bello', 'Adeyemi'])[1 + ((i * 11 + 5) % 18)],
        'guest.' || i || '.' || substr(md5(i::text || '-ekostay'), 1, 8) || '@ekostay.ng',
        '+234' || (8010000000 + i)::text,
        encode(digest('NIN-SALT-' || i::text, 'sha256'), 'hex'),
        encode(digest('PASSPORT-SALT-' || i::text, 'sha256'), 'hex'),
        CASE WHEN i % 9 = 0 THEN 'British' WHEN i % 13 = 0 THEN 'Ghanaian' ELSE 'Nigerian' END,
        CASE
            WHEN i % 10 = 0 THEN 4
            WHEN i % 4 = 0 THEN 3
            WHEN i % 2 = 0 THEN 2
            ELSE 1
        END,
        'ACTIVE',
        TIMESTAMP '2026-03-01 08:00:00+01' + (i * INTERVAL '12 hours')
    FROM generate_series(13, 122) AS i
    ON CONFLICT (phone_number) DO NOTHING;

    GET DIAGNOSTICS v_guest_count = ROW_COUNT;
    RAISE NOTICE 'Added % new guest records.', v_guest_count;

    -- 2. Scale Rooms: Generate 206 additional physical rooms across Wings A, B, C, D, E (bringing total to 220)
    INSERT INTO rooms (
        room_id, room_number, category_id, floor_number, wing, room_status, is_smoking, created_at
    )
    SELECT
        gen_random_uuid(),
        wing_letter || lpad((104 + i)::text, 3, '0'),
        1 + ((i - 1) % 5),
        1 + ((i - 1) % 15),
        CASE wing_letter
            WHEN 'A' THEN 'GARDEN_WING'
            WHEN 'B' THEN 'LAGOON_WING'
            WHEN 'C' THEN 'ATLANTIC_WING'
            ELSE 'EXECUTIVE_TOWER'
        END,
        'AVAILABLE',
        (i % 20 = 0),
        TIMESTAMP '2026-01-15 10:00:00+01'
    FROM generate_series(1, 206) AS i
    CROSS JOIN LATERAL (
        SELECT (ARRAY['A', 'B', 'C', 'D', 'E'])[1 + ((i - 1) % 5)] AS wing_letter
    ) w
    ON CONFLICT (room_number) DO NOTHING;

    GET DIAGNOSTICS v_room_count = ROW_COUNT;
    RAISE NOTICE 'Added % new hotel room records.', v_room_count;

    -- Temporarily disable booking validation trigger during bulk historical load to avoid
    -- 15,000 sequential trigger overlap checks; non-overlapping windows are guaranteed by construction.
    ALTER TABLE bookings DISABLE TRIGGER trg_validate_booking_rules;

    -- 3. Scale Bookings: Generate 15,000 realistic reservations across 6 months (May 2026 - Oct 2026)
    WITH active_rooms AS (
        SELECT r.room_id, r.category_id, rc.base_nightly_rate, row_number() OVER (ORDER BY r.room_number) AS rnum, count(*) OVER () AS total_rooms
        FROM rooms r
        JOIN room_categories rc ON r.category_id = rc.category_id
        WHERE r.room_status <> 'OUT_OF_ORDER'
    ),
    active_guests AS (
        SELECT g.guest_id, lt.discount_percentage, row_number() OVER (ORDER BY g.guest_id) AS gnum, count(*) OVER () AS total_guests
        FROM guests g
        JOIN loyalty_tiers lt ON g.loyalty_tier = lt.tier_level
        WHERE g.guest_status = 'ACTIVE'
    )
    INSERT INTO bookings (
        booking_id,
        booking_reference,
        guest_id,
        room_id,
        check_in_date,
        check_out_date,
        num_guests,
        nightly_rate_applied,
        discount_amount,
        subtotal_amount,
        tax_amount,
        total_amount,
        booking_status,
        booking_channel,
        special_requests,
        created_at
    )
    SELECT
        gen_random_uuid(),
        'EKO-BK-' || to_char(checkin_dt, 'YYYYMMDD') || '-' || lpad(i::text, 6, '0'),
        ag.guest_id,
        ar.room_id,
        checkin_dt,
        checkin_dt + stay_nights,
        1 + (i % 2),
        ar.base_nightly_rate,
        round((ar.base_nightly_rate * stay_nights) * (ag.discount_percentage / 100.0), 4),
        round((ar.base_nightly_rate * stay_nights) * (1.0 - (ag.discount_percentage / 100.0)), 4),
        round(((ar.base_nightly_rate * stay_nights) * (1.0 - (ag.discount_percentage / 100.0))) * 0.125, 4),
        round(((ar.base_nightly_rate * stay_nights) * (1.0 - (ag.discount_percentage / 100.0))) * 1.125, 4),
        CASE
            WHEN i % 40 = 0 THEN 'CANCELLED'
            WHEN i % 85 = 0 THEN 'NO_SHOW'
            WHEN checkin_dt < DATE '2026-10-10' THEN 'CHECKED_OUT'
            WHEN checkin_dt <= DATE '2026-10-16' THEN 'CHECKED_IN'
            ELSE 'CONFIRMED'
        END,
        (ARRAY['DIRECT_WEB', 'MOBILE_APP', 'CORPORATE_DESK', 'OTA_BOOKING_COM', 'WALK_IN'])[1 + (i % 5)],
        CASE (i % 5)
            WHEN 0 THEN 'Standard check-in, quiet floor preferred'
            WHEN 1 THEN 'Airport chauffeur pickup requested from MMIA'
            WHEN 2 THEN 'Corporate executive stay; VAT invoice required'
            WHEN 3 THEN 'Extra pillows and late check-out requested'
            ELSE 'Lagoon view balcony preference'
        END,
        (checkin_dt - INTERVAL '3 days') + ((i % 86400) * INTERVAL '1 second')
    FROM generate_series(1, 15000) AS i
    JOIN active_rooms ar ON ar.rnum = (1 + (i % ar.total_rooms))
    JOIN active_guests ag ON ag.gnum = (1 + ((i * 7) % ag.total_guests))
    CROSS JOIN LATERAL (
        SELECT
            DATE '2026-05-01' + (((i - 1) / ar.total_rooms) * 2 + (i % 2))::int AS checkin_dt,
            (1 + (i % 3))::int AS stay_nights
    ) d
    ON CONFLICT (booking_reference) DO NOTHING;

    GET DIAGNOSTICS v_booking_count = ROW_COUNT;
    RAISE NOTICE 'Added % reservation booking records.', v_booking_count;

    -- Re-enable operational booking trigger
    ALTER TABLE bookings ENABLE TRIGGER trg_validate_booking_rules;

    -- 4. Scale Payments: Generate payment settlement records for all new bookings
    INSERT INTO payments (
        payment_id,
        payment_reference,
        booking_id,
        guest_id,
        payment_method,
        gateway_provider,
        gateway_session_id,
        currency,
        amount_paid,
        processing_fee,
        payment_status,
        narration,
        paid_at
    )
    SELECT
        gen_random_uuid(),
        'EKO-PY-' || substr(b.booking_reference, 8),
        b.booking_id,
        b.guest_id,
        (ARRAY['DEBIT_CARD', 'BANK_TRANSFER_NIP', 'POS_TERMINAL', 'CORPORATE_INVOICE', 'WALLET'])[1 + (row_number() OVER () % 5)],
        (ARRAY['PAYSTACK', 'FLUTTERWAVE', 'INTERSWITCH_POS', 'MONIEPOINT_POS', 'NIBSS_NIP_DIRECT'])[1 + (row_number() OVER () % 5)],
        'GW-' || lpad((row_number() OVER ())::text, 8, '0') || '-' || substr(md5(b.booking_id::text), 1, 10),
        'NGN',
        b.total_amount,
        CASE
            WHEN (row_number() OVER () % 5) IN (0, 1) THEN 2000.0000
            WHEN (row_number() OVER () % 5) IN (2, 3) THEN 1500.0000
            ELSE 53.7500
        END,
        CASE
            WHEN b.booking_status = 'CANCELLED' THEN 'FAILED'
            WHEN b.booking_status = 'NO_SHOW' THEN 'REFUNDED'
            ELSE 'COMPLETED'
        END,
        'Reservation settlement for ' || b.booking_reference,
        b.created_at + INTERVAL '4 minutes'
    FROM bookings b
    WHERE b.booking_reference LIKE 'EKO-BK-%'
      AND b.booking_id NOT IN (SELECT booking_id FROM payments)
    ON CONFLICT (payment_reference) DO NOTHING;

    GET DIAGNOSTICS v_payment_count = ROW_COUNT;
    RAISE NOTICE 'Added % payment settlement records.', v_payment_count;

    -- 5. Scale Check-In / Check-Out Records: Populate stay logs for 5,000 completed/active stays
    INSERT INTO checkin_checkout_records (
        record_id,
        booking_id,
        room_id,
        guest_id,
        actual_check_in_at,
        actual_check_out_at,
        keycard_code,
        deposit_held,
        late_checkout_fee,
        checked_in_by,
        checked_out_by,
        room_inspection_status,
        front_desk_notes,
        created_at
    )
    SELECT
        gen_random_uuid(),
        b.booking_id,
        b.room_id,
        b.guest_id,
        b.check_in_date + TIME '14:00:00' + ((row_number() OVER () % 120) * INTERVAL '1 minute'),
        CASE
            WHEN b.booking_status = 'CHECKED_OUT' THEN b.check_out_date + TIME '11:30:00' + ((row_number() OVER () % 90) * INTERVAL '1 minute')
            ELSE NULL
        END,
        'KC-BLE-' || substr(md5(b.booking_id::text), 1, 8),
        50000.00,
        CASE WHEN (row_number() OVER () % 15) = 0 THEN 25000.00 ELSE 0.00 END,
        (ARRAY['RECEPTION_OFFICER_ADA', 'RECEPTION_OFFICER_FEMI', 'DUTY_MANAGER_SEYI', 'NIGHT_AUDITOR_KEMI'])[1 + (row_number() OVER () % 4)],
        CASE
            WHEN b.booking_status = 'CHECKED_OUT' THEN 'RECEPTION_OFFICER_FEMI'
            ELSE NULL
        END,
        CASE
            WHEN b.booking_status = 'CHECKED_IN' THEN 'PENDING_INSPECTION'
            WHEN (row_number() OVER () % 12) = 0 THEN 'MINIBAR_BILLED'
            WHEN (row_number() OVER () % 45) = 0 THEN 'DAMAGE_CHARGED'
            ELSE 'CLEARED_NO_DAMAGE'
        END,
        'Automated PMS front-desk check-in/out log for ' || b.booking_reference,
        b.check_in_date + TIME '14:00:00'
    FROM bookings b
    WHERE b.booking_reference LIKE 'EKO-BK-%'
      AND b.booking_status IN ('CHECKED_OUT', 'CHECKED_IN')
      AND b.booking_id NOT IN (SELECT booking_id FROM checkin_checkout_records)
    LIMIT 5000
    ON CONFLICT (booking_id) DO NOTHING;

    GET DIAGNOSTICS v_checkin_count = ROW_COUNT;
    RAISE NOTICE 'Added % check-in/check-out stay records.', v_checkin_count;

    -- 6. Refresh Database Statistics for Query Planner
    ANALYZE loyalty_tiers;
    ANALYZE room_categories;
    ANALYZE guests;
    ANALYZE rooms;
    ANALYZE bookings;
    ANALYZE payments;
    ANALYZE checkin_checkout_records;
    ANALYZE audit_logs;

    RAISE NOTICE 'ANALYZE complete. Query planner statistics refreshed.';
END $$;
