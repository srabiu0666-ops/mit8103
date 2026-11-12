-- Primary-Replica Replication & Read-Write Query Splitting
-- MIT 8103 Advanced Database Systems - Portfolio 5
-- Case Study: EkoStay Hospitality Limited
-- Author: Rabiu Sekinah (301870666)

-- Clean teardown of simulation metadata objects if re-running
DROP FUNCTION IF EXISTS fn_route_ekostay_query(TEXT, VARCHAR, BOOLEAN) CASCADE;
DROP TABLE IF EXISTS distributed_cluster_nodes CASCADE;
DROP PUBLICATION IF EXISTS ekostay_crs_pub;

\echo '1. Configuring EkoStay Multi-Region Cluster Topology Registry'

CREATE TABLE distributed_cluster_nodes (
    node_id VARCHAR(30) PRIMARY KEY,
    region VARCHAR(40) NOT NULL,
    availability_zone VARCHAR(30) NOT NULL,
    node_role VARCHAR(20) NOT NULL CHECK (node_role IN ('PRIMARY_WRITER', 'SYNC_STANDBY', 'ASYNC_READ_REPLICA')),
    endpoint_host VARCHAR(100) NOT NULL,
    replication_mode VARCHAR(20) NOT NULL CHECK (replication_mode IN ('PRIMARY', 'SYNCHRONOUS', 'ASYNCHRONOUS')),
    measured_lag_ms NUMERIC(8, 2) NOT NULL DEFAULT 0.00,
    node_status VARCHAR(20) NOT NULL DEFAULT 'HEALTHY' CHECK (node_status IN ('HEALTHY', 'DEGRADED', 'OFFLINE')),
    last_heartbeat TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO distributed_cluster_nodes (
    node_id, region, availability_zone, node_role, endpoint_host, replication_mode, measured_lag_ms, node_status
) VALUES
    ('ekostay-pg-primary-01', 'NG-Lagos (Local Zone)',    'af-south-1-los-1a', 'PRIMARY_WRITER',     'pg-primary.lagos.internal.ekostay.ng:5432',  'PRIMARY',      0.00,  'HEALTHY'),
    ('ekostay-pg-standby-02', 'NG-Lagos (Victoria Isl)',  'af-south-1-los-1b', 'SYNC_STANDBY',       'pg-standby.lagos.internal.ekostay.ng:5432',  'SYNCHRONOUS',  1.35,  'HEALTHY'),
    ('ekostay-pg-replica-03', 'NG-Abuja (Maitama Hub)',   'af-south-1a',       'ASYNC_READ_REPLICA', 'pg-replica.abuja.internal.ekostay.ng:5432',  'ASYNCHRONOUS', 13.60, 'HEALTHY'),
    ('ekostay-pg-dr-04',      'EU-West (Ireland DR)',     'eu-west-1a',        'ASYNC_READ_REPLICA', 'pg-dr.dublin.internal.ekostay.ng:5432',      'ASYNCHRONOUS', 66.80, 'HEALTHY');

SELECT
    node_id,
    region,
    node_role,
    replication_mode,
    measured_lag_ms,
    node_status
FROM distributed_cluster_nodes
ORDER BY measured_lag_ms ASC;

\echo '2. Creating Logical Replication Publication for Core CRS/PMS Tables'

-- Publish core EkoStay tables for downstream analytical and cross-region replicas
CREATE PUBLICATION ekostay_crs_pub
    FOR TABLE rooms, bookings, payments, checkin_checkout_records
    WITH (publish = 'insert, update');

SELECT
    pubname,
    puballtables,
    pubinsert,
    pubupdate,
    pubdelete
FROM pg_publication
WHERE pubname = 'ekostay_crs_pub';

SELECT
    pubname,
    schemaname,
    tablename
FROM pg_publication_tables
WHERE pubname = 'ekostay_crs_pub'
ORDER BY tablename;

\echo '3. Inspecting Live PostgreSQL WAL Position and Recovery Role'

SELECT
    pg_is_in_recovery() AS is_read_replica,
    CASE WHEN pg_is_in_recovery() THEN 'READ_REPLICA_STANDBY' ELSE 'PRIMARY_READ_WRITE_LEADER' END AS active_engine_role,
    pg_current_wal_lsn() AS current_wal_lsn,
    pg_walfile_name(pg_current_wal_lsn()) AS active_wal_segment_file,
    current_setting('wal_level') AS configured_wal_level,
    current_setting('max_wal_senders') AS max_wal_senders;

\echo '4. Implementing Read-Write Query Router Function (PgBouncer / HAProxy Routing Logic)'

CREATE OR REPLACE FUNCTION fn_route_ekostay_query(
    p_sql_operation TEXT,
    p_workflow_category VARCHAR(40),
    p_require_read_your_writes BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    selected_node_id VARCHAR(30),
    selected_region VARCHAR(40),
    selected_role VARCHAR(20),
    endpoint VARCHAR(100),
    routing_reason TEXT
) AS $$
DECLARE
    v_is_mutation BOOLEAN;
BEGIN
    v_is_mutation := (
        p_sql_operation ~* '^\s*(INSERT|UPDATE|DELETE|CALL|SELECT\s+\*\s+FROM\s+sp_create_room_reservation|SELECT\s+\*\s+FROM\s+sp_book_room_pair)'
        OR p_sql_operation ~* 'FOR\s+UPDATE'
    );

    IF v_is_mutation THEN
        RETURN QUERY
        SELECT
            n.node_id,
            n.region,
            n.node_role,
            n.endpoint_host,
            'Write/Lock operation detected: routed strictly to Primary Writer with synchronous standby commit.'::TEXT
        FROM distributed_cluster_nodes n
        WHERE n.node_role = 'PRIMARY_WRITER'
          AND n.node_status = 'HEALTHY'
        LIMIT 1;

    ELSIF p_require_read_your_writes THEN
        RETURN QUERY
        SELECT
            n.node_id,
            n.region,
            n.node_role,
            n.endpoint_host,
            'Session consistency required (Read-Your-Own-Writes after reservation): routed to Sync Standby (lag < 2ms).'::TEXT
        FROM distributed_cluster_nodes n
        WHERE n.node_role IN ('SYNC_STANDBY', 'PRIMARY_WRITER')
          AND n.node_status = 'HEALTHY'
        ORDER BY CASE WHEN n.node_role = 'SYNC_STANDBY' THEN 1 ELSE 2 END
        LIMIT 1;

    ELSE
        RETURN QUERY
        SELECT
            n.node_id,
            n.region,
            n.node_role,
            n.endpoint_host,
            ('Read-only analytical workload (' || p_workflow_category || '): offloaded to lowest-lag Async Read Replica.')::TEXT
        FROM distributed_cluster_nodes n
        WHERE n.node_role = 'ASYNC_READ_REPLICA'
          AND n.node_status = 'HEALTHY'
          AND n.measured_lag_ms < 50.00
        ORDER BY n.measured_lag_ms ASC
        LIMIT 1;
    END IF;
END;
$$ LANGUAGE plpgsql;

\echo '5. Verifying Read-Write Splitting Across EkoStay Hospitality Workloads'

-- Workload A: Room Reservation & Payment Settlement (Write / Row Lock)
SELECT * FROM fn_route_ekostay_query(
    'SELECT * FROM sp_create_room_reservation(''a0000000-0000-0000-0000-000000000001'', ''A101'', ''2026-12-10'', ''2026-12-12'', 2, ''DEBIT_CARD'', ''PAYSTACK'')',
    'ROOM_RESERVATION_WRITE',
    TRUE
);

-- Workload B: Post-Booking Immediate Folio Confirmation Screen (Read-Your-Writes Consistency)
SELECT * FROM fn_route_ekostay_query(
    'SELECT booking_reference, booking_status, total_amount FROM bookings WHERE guest_id = ''a0000000-0000-0000-0000-000000000001''',
    'POST_BOOKING_FOLIO_VIEW',
    TRUE
);

-- Workload C: Monthly RevPAR & Night Audit Revenue Report (Heavy Analytical Read)
SELECT * FROM fn_route_ekostay_query(
    'SELECT wing, count(*), sum(total_amount) FROM bookings JOIN rooms USING (room_id) GROUP BY wing',
    'NIGHT_AUDIT_REVPAR_ANALYTICS',
    FALSE
);
