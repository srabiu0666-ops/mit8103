-- Horizontal Sharding & Declarative Range Partitioning
-- MIT 8103 Advanced Database Systems - Portfolio 5
-- Case Study: EkoStay Hospitality Limited
-- Author: Rabiu Sekinah (301870666)

-- Clean teardown of partitioned and sharded tables if re-running
DROP TABLE IF EXISTS bookings_partitioned CASCADE;
DROP TABLE IF EXISTS rooms_sharded CASCADE;

\echo '1. Creating Monthly Range-Partitioned Reservation Table (bookings_partitioned)'

-- Note: PostgreSQL requires any PRIMARY KEY or UNIQUE constraint on a partitioned table
-- to include all partition key columns (check_in_date).
CREATE TABLE bookings_partitioned (
    booking_id UUID NOT NULL DEFAULT gen_random_uuid(),
    booking_reference VARCHAR(64) NOT NULL,
    guest_id UUID NOT NULL REFERENCES guests(guest_id) ON DELETE RESTRICT,
    room_id UUID NOT NULL REFERENCES rooms(room_id) ON DELETE RESTRICT,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    num_guests INT NOT NULL CHECK (num_guests >= 1),
    nightly_rate_applied NUMERIC(18, 4) NOT NULL CHECK (nightly_rate_applied > 0.0000),
    discount_amount NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (discount_amount >= 0.0000),
    subtotal_amount NUMERIC(18, 4) NOT NULL CHECK (subtotal_amount > 0.0000),
    tax_amount NUMERIC(18, 4) NOT NULL CHECK (tax_amount >= 0.0000),
    total_amount NUMERIC(18, 4) NOT NULL CHECK (total_amount > 0.0000),
    booking_status VARCHAR(20) NOT NULL DEFAULT 'CONFIRMED',
    booking_channel VARCHAR(25) NOT NULL DEFAULT 'DIRECT_WEB',
    special_requests VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_part_booking_dates CHECK (check_out_date > check_in_date),
    PRIMARY KEY (booking_id, check_in_date),
    UNIQUE (booking_reference, check_in_date)
) PARTITION BY RANGE (check_in_date);

-- Create monthly child partitions covering EkoStay's 2026 operational windows
CREATE TABLE bookings_p2026_05 PARTITION OF bookings_partitioned
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

CREATE TABLE bookings_p2026_06 PARTITION OF bookings_partitioned
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

CREATE TABLE bookings_p2026_07 PARTITION OF bookings_partitioned
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');

CREATE TABLE bookings_p2026_08 PARTITION OF bookings_partitioned
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');

CREATE TABLE bookings_p2026_09 PARTITION OF bookings_partitioned
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');

CREATE TABLE bookings_p2026_10 PARTITION OF bookings_partitioned
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');

CREATE TABLE bookings_p2026_11 PARTITION OF bookings_partitioned
    FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');

CREATE TABLE bookings_p2026_12 PARTITION OF bookings_partitioned
    FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

CREATE TABLE bookings_p_default PARTITION OF bookings_partitioned DEFAULT;

-- Create partitioned B-Tree indexes propagated automatically to all child partitions
CREATE INDEX idx_bookings_part_room_checkin
    ON bookings_partitioned(room_id, check_in_date DESC);

CREATE INDEX idx_bookings_part_channel_status_checkin
    ON bookings_partitioned(booking_channel, booking_status, check_in_date)
    INCLUDE (total_amount, subtotal_amount, tax_amount);

-- Migrate all reservation rows from the monolithic bookings table into the partitioned hierarchy,
-- distributing synthetic history across the 6-month window (May 2026 - Oct 2026) while preserving
-- baseline October/November/December 2026 records verbatim.
INSERT INTO bookings_partitioned (
    booking_id, booking_reference, guest_id, room_id, check_in_date, check_out_date,
    num_guests, nightly_rate_applied, discount_amount, subtotal_amount, tax_amount,
    total_amount, booking_status, booking_channel, special_requests, created_at, updated_at
)
SELECT
    booking_id,
    booking_reference,
    guest_id,
    room_id,
    CASE
        WHEN booking_reference LIKE 'EKO-BK-%' THEN
            DATE '2026-05-01' + (abs(hashtext(booking_reference)) % 180)
        ELSE check_in_date
    END AS adj_check_in,
    CASE
        WHEN booking_reference LIKE 'EKO-BK-%' THEN
            (DATE '2026-05-01' + (abs(hashtext(booking_reference)) % 180)) + (check_out_date - check_in_date)
        ELSE check_out_date
    END AS adj_check_out,
    num_guests,
    nightly_rate_applied,
    discount_amount,
    subtotal_amount,
    tax_amount,
    total_amount,
    booking_status,
    booking_channel,
    special_requests,
    created_at,
    updated_at
FROM bookings;

ANALYZE bookings_partitioned;

\echo '2. Inspecting Tuple Distribution Across Monthly Partitions'

SELECT
    inhrelid::regclass AS partition_name,
    pg_get_expr(c.relpartbound, c.oid) AS partition_range_bound,
    c.reltuples::bigint AS tuple_count,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size
FROM pg_inherits i
JOIN pg_class c ON i.inhrelid = c.oid
WHERE i.inhparent = 'bookings_partitioned'::regclass
ORDER BY c.relname;

\echo '3. Creating 4-Way Hash-Sharded Room Inventory Table (rooms_sharded)'

CREATE TABLE rooms_sharded (
    room_id UUID NOT NULL,
    room_number CHAR(4) NOT NULL,
    category_id INT NOT NULL REFERENCES room_categories(category_id) ON DELETE RESTRICT,
    floor_number INT NOT NULL CHECK (floor_number BETWEEN 1 AND 25),
    wing VARCHAR(25) NOT NULL,
    room_status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE',
    is_smoking BOOLEAN NOT NULL DEFAULT FALSE,
    shard_property_node VARCHAR(40) NOT NULL DEFAULT 'NG-LAGOS-VI-PRIMARY',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (room_number, room_id)
) PARTITION BY HASH (room_number);

-- Create 4 logical hash shards (Modulus 4, Remainder 0..3) representing distributed property shard nodes
CREATE TABLE rooms_shard_00 PARTITION OF rooms_sharded
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);

CREATE TABLE rooms_shard_01 PARTITION OF rooms_sharded
    FOR VALUES WITH (MODULUS 4, REMAINDER 1);

CREATE TABLE rooms_shard_02 PARTITION OF rooms_sharded
    FOR VALUES WITH (MODULUS 4, REMAINDER 2);

CREATE TABLE rooms_shard_03 PARTITION OF rooms_sharded
    FOR VALUES WITH (MODULUS 4, REMAINDER 3);

-- Populate sharded rooms from baseline rooms table
INSERT INTO rooms_sharded (
    room_id, room_number, category_id, floor_number, wing,
    room_status, is_smoking, shard_property_node, created_at, updated_at
)
SELECT
    room_id,
    room_number,
    category_id,
    floor_number,
    wing,
    room_status,
    is_smoking,
    CASE (abs(hashtext(room_number)) % 4)
        WHEN 0 THEN 'SHARD-00 (Lagos-VI-Grand-Node1)'
        WHEN 1 THEN 'SHARD-01 (Lagos-Ikeja-GRA-Node2)'
        WHEN 2 THEN 'SHARD-02 (Abuja-Maitama-Node3)'
        ELSE 'SHARD-03 (PortHarcourt-GRA-Node4)'
    END,
    created_at,
    updated_at
FROM rooms;

ANALYZE rooms_sharded;

\echo '4. Verifying Uniform Hash Sharding Balance Across 4 Property Nodes'

SELECT
    rs.tableoid::regclass AS shard_partition,
    count(*) AS rooms_hosted,
    round((count(*)::numeric / sum(count(*)) OVER ()) * 100, 2) AS distribution_pct,
    round(sum(rc.base_nightly_rate), 2) AS daily_inventory_capacity_ngn
FROM rooms_sharded rs
JOIN room_categories rc ON rs.category_id = rc.category_id
GROUP BY rs.tableoid
ORDER BY rs.tableoid::regclass::text;

\echo '5. Benchmarking Partition Pruning on October 2026 Channel Revenue Audit'

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    booking_channel,
    booking_status,
    count(*) AS reservation_count,
    sum(total_amount) AS total_revenue_ngn
FROM bookings_partitioned
WHERE check_in_date >= DATE '2026-10-01'
  AND check_in_date <  DATE '2026-11-01'
  AND booking_status IN ('CHECKED_OUT', 'CHECKED_IN', 'CONFIRMED')
GROUP BY booking_channel, booking_status
ORDER BY total_revenue_ngn DESC;

\echo '6. Verifying Single-Shard Targeting on Room Code Lookup (Room A101)'

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    room_number,
    wing,
    floor_number,
    room_status,
    shard_property_node,
    tableoid::regclass AS routed_shard
FROM rooms_sharded
WHERE room_number = 'A101';
