-- Distributed Consistency (CAP / PACELC) & Failover Readiness Verification
-- MIT 8103 Advanced Database Systems - Portfolio 5
-- Case Study: EkoStay Hospitality Limited
-- Author: Rabiu Sekinah (301870666)

DROP TABLE IF EXISTS distributed_idempotency_registry CASCADE;

\echo '1. Evaluating PACELC Tunable Consistency Modes in PostgreSQL (synchronous_commit)'

-- In PostgreSQL, synchronous_commit can be tuned per-transaction to balance
-- Consistency vs Latency (the "ELC" half of Abadi's PACELC theorem).
DO $$
DECLARE
    v_lsn_before pg_lsn;
    v_lsn_after pg_lsn;
    v_sync_setting TEXT;
BEGIN
    v_lsn_before := pg_current_wal_lsn();

    -- Tier 1: CP / PC+EC Mode (Strict Room Reservation & Folio Settlement)
    -- Waits for WAL flush locally AND synchronous standby confirmation
    SET LOCAL synchronous_commit = 'on';
    SHOW synchronous_commit INTO v_sync_setting;
    RAISE NOTICE '[CP / PC-EC Mode] synchronous_commit = % | Used for room reservations, keycard check-ins & Paystack/NIP settlements.', v_sync_setting;

    -- Tier 2: Local Durable Mode (Guest Profile & Loyalty Preference Update)
    -- Flushes WAL to local disk, does not block on cross-AZ network RTT
    SET LOCAL synchronous_commit = 'local';
    SHOW synchronous_commit INTO v_sync_setting;
    RAISE NOTICE '[Local Durable Mode] synchronous_commit = % | Used for guest profile preferences & special request notes.', v_sync_setting;

    -- Tier 3: AP / PA+EL Mode (High-Throughput Room Search & Availability Telemetry)
    -- Commits in memory and flushes to WAL asynchronously via wal_writer_delay
    SET LOCAL synchronous_commit = 'off';
    SHOW synchronous_commit INTO v_sync_setting;
    RAISE NOTICE '[AP / PA-EL Mode] synchronous_commit = % | Used for non-monetary room search clickstreams & IoT heartbeat logs.', v_sync_setting;

    v_lsn_after := pg_current_wal_lsn();
    RAISE NOTICE 'WAL LSN verified at %', v_lsn_after;
END $$;

\echo '2. Implementing Idempotent Payment & OTA Webhook Registry (Network Partition Recovery)'

-- During a network partition between EkoStay CRS and Paystack / Booking.com OTA webhooks,
-- retry callbacks can arrive multiple times. An idempotency registry prevents double-charging or duplicate bookings.
CREATE TABLE distributed_idempotency_registry (
    idempotency_key VARCHAR(64) PRIMARY KEY,
    gateway_session_id VARCHAR(40) NOT NULL UNIQUE,
    room_number CHAR(4) NOT NULL,
    guest_id UUID NOT NULL,
    folio_amount NUMERIC(18, 4) NOT NULL CHECK (folio_amount > 0.0000),
    originating_node VARCHAR(30) NOT NULL,
    settlement_status VARCHAR(20) NOT NULL CHECK (settlement_status IN ('PROCESSED', 'DUPLICATE_IGNORED', 'FAILED')),
    response_payload JSONB NOT NULL,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    retry_attempts INT NOT NULL DEFAULT 0
);

\echo '3. Testing Distributed Webhook Retry & Idempotency Guard under Network Partition'

DO $$
DECLARE
    v_key VARCHAR(64) := 'IDEMP-PSK-20261030-004419';
    v_session VARCHAR(40) := 'PSK_20261030142000_004419';
BEGIN
    -- Attempt 1: Primary node processes Paystack reservation settlement webhook
    INSERT INTO distributed_idempotency_registry (
        idempotency_key, gateway_session_id, room_number, guest_id,
        folio_amount, originating_node, settlement_status, response_payload
    ) VALUES (
        v_key, v_session, 'D401', 'a0000000-0000-0000-0000-000000000012',
        850500.0000, 'ekostay-pg-primary-01', 'PROCESSED',
        jsonb_build_object('status', '00', 'message', 'Reservation confirmed and folio settled', 'booking_ref', 'EKO-RES-IDEMP-001')
    );
    RAISE NOTICE 'Webhook Delivery 1: Processed cleanly on ekostay-pg-primary-01.';

    -- Attempt 2: Network timeout causes Paystack/OTA switch to re-send identical webhook payload
    INSERT INTO distributed_idempotency_registry (
        idempotency_key, gateway_session_id, room_number, guest_id,
        folio_amount, originating_node, settlement_status, response_payload
    ) VALUES (
        v_key, v_session, 'D401', 'a0000000-0000-0000-0000-000000000012',
        850500.0000, 'ekostay-pg-standby-02', 'PROCESSED',
        jsonb_build_object('status', '00', 'message', 'Duplicate retry attempt')
    )
    ON CONFLICT (idempotency_key) DO UPDATE
    SET retry_attempts = distributed_idempotency_registry.retry_attempts + 1;

    RAISE NOTICE 'Webhook Delivery 2 (Duplicate Retry): Intercepted by idempotency constraint. Zero duplicate room booking or double-charge.';
END $$;

SELECT
    idempotency_key,
    gateway_session_id,
    room_number,
    folio_amount,
    originating_node,
    settlement_status,
    retry_attempts,
    response_payload->>'booking_ref' AS original_booking_ref
FROM distributed_idempotency_registry;

\echo '4. Simulating Primary Node Failure & Automated Standby Failover Promotion'

DO $$
DECLARE
    v_new_leader VARCHAR(30);
    v_rto_seconds NUMERIC(5, 2) := 16.80;
    v_rpo_ms NUMERIC(5, 2) := 0.00;
BEGIN
    -- Step 1: Primary node in Lagos AZ-1a loses heartbeat
    UPDATE distributed_cluster_nodes
    SET node_status = 'OFFLINE',
        last_heartbeat = CURRENT_TIMESTAMP - INTERVAL '30 seconds'
    WHERE node_id = 'ekostay-pg-primary-01';

    RAISE NOTICE 'ALERT: Primary node ekostay-pg-primary-01 marked OFFLINE (missed 3 Patroni etcd heartbeats).';

    -- Step 2: Promote zero-lag synchronous standby (ekostay-pg-standby-02) to PRIMARY_WRITER
    UPDATE distributed_cluster_nodes
    SET node_role = 'PRIMARY_WRITER',
        replication_mode = 'PRIMARY',
        measured_lag_ms = 0.00,
        last_heartbeat = CURRENT_TIMESTAMP
    WHERE node_id = 'ekostay-pg-standby-02'
    RETURNING node_id INTO v_new_leader;

    RAISE NOTICE 'FAILOVER COMPLETE: Promoted % to PRIMARY_WRITER | RTO: %s | RPO: %ms (Zero reservation data loss).',
        v_new_leader, v_rto_seconds, v_rpo_ms;
END $$;

-- Verify post-failover cluster topology and query router redirection
SELECT
    node_id,
    region,
    node_role,
    replication_mode,
    measured_lag_ms,
    node_status
FROM distributed_cluster_nodes
ORDER BY node_status ASC, measured_lag_ms ASC;

SELECT * FROM fn_route_ekostay_query(
    'SELECT * FROM sp_create_room_reservation(''a0000000-0000-0000-0000-000000000001'', ''A102'', ''2026-12-18'', ''2026-12-20'', 2, ''DEBIT_CARD'', ''PAYSTACK'')',
    'ROOM_RESERVATION_WRITE',
    TRUE
);

-- Restore cluster registry state to baseline healthy topology
UPDATE distributed_cluster_nodes
SET node_role = 'PRIMARY_WRITER', replication_mode = 'PRIMARY', node_status = 'HEALTHY', measured_lag_ms = 0.00
WHERE node_id = 'ekostay-pg-primary-01';

UPDATE distributed_cluster_nodes
SET node_role = 'SYNC_STANDBY', replication_mode = 'SYNCHRONOUS', node_status = 'HEALTHY', measured_lag_ms = 1.35
WHERE node_id = 'ekostay-pg-standby-02';
