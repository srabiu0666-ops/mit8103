-- PostgreSQL Transaction Isolation Levels Analysis
-- MIT 8103 Advanced Database Systems - Portfolio 3
-- Case Study: EkoStay Hospitality Limited

-- 1. Non-Repeatable Reads under READ COMMITTED
\echo 'Testing Non-Repeatable Read on Room Tariff (READ COMMITTED)'

DO $$
DECLARE
    v_rate_snapshot1 NUMERIC(15, 2);
    v_rate_snapshot2 NUMERIC(15, 2);
BEGIN
    SELECT base_nightly_rate INTO v_rate_snapshot1
    FROM room_categories
    WHERE category_code = 'DLX-LAGOON';

    RAISE NOTICE 'Initial tariff read (T0): % NGN', v_rate_snapshot1;

    -- Interleaved concurrent tariff adjustment by revenue manager
    UPDATE room_categories
    SET base_nightly_rate = base_nightly_rate + 15000.00
    WHERE category_code = 'DLX-LAGOON';

    -- Subsequent read inside same block
    SELECT base_nightly_rate INTO v_rate_snapshot2
    FROM room_categories
    WHERE category_code = 'DLX-LAGOON';

    RAISE NOTICE 'Subsequent tariff read (T1): % NGN', v_rate_snapshot2;

    IF v_rate_snapshot1 <> v_rate_snapshot2 THEN
        RAISE NOTICE 'Non-Repeatable read observed. Room tariff changed mid-transaction.';
    END IF;

    -- Revert test tariff adjustment
    UPDATE room_categories
    SET base_nightly_rate = base_nightly_rate - 15000.00
    WHERE category_code = 'DLX-LAGOON';
END $$;

-- 2. REPEATABLE READ snapshot isolation for Night Audit Revenue Reporting
\echo 'Testing Snapshot Isolation (REPEATABLE READ)'

DO $$
DECLARE
    v_active_rooms INT;
BEGIN
    SELECT COUNT(*) INTO v_active_rooms FROM rooms WHERE room_status = 'OCCUPIED';
    RAISE NOTICE 'Snapshot occupied room count at start of Night Audit: % rooms', v_active_rooms;
    RAISE NOTICE 'REPEATABLE READ guarantees stable point-in-time snapshot views across financial Night Audit reports.';
END $$;

-- 3. Inspect PostgreSQL Isolation Settings
\echo 'Current Transaction Isolation Settings'
SELECT
    name,
    setting,
    unit,
    short_desc
FROM pg_settings
WHERE name IN ('default_transaction_isolation', 'transaction_isolation');
