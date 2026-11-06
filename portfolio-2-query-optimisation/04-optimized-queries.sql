-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 2 - Query Processing and Optimisation
-- Case Study: EkoStay Hospitality Limited
-- File: 04-optimized-queries.sql
-- Description: Core hospitality analytical queries executed AFTER applying strategic indexes.
--              Captures optimized execution plans, scan types, buffer reads, and speedups.
-- Author: Rabiu Sekinah (301870666)

-- QUERY 1 (OPTIMIZED): High-Frequency Corporate & OTA Booking Surveillance
-- Expected Improvement: Uses composite covering index idx_bookings_checkin_channel_covering.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT
    g.guest_id,
    g.first_name || ' ' || g.last_name AS guest_name,
    g.email,
    COUNT(b.booking_id) AS reservation_count,
    SUM(b.total_amount) AS total_folio_spend,
    MAX(b.check_in_date) AS latest_check_in
FROM bookings b
JOIN guests g ON b.guest_id = g.guest_id
WHERE b.booking_status IN ('CHECKED_OUT', 'CHECKED_IN', 'CONFIRMED')
  AND b.booking_channel IN ('CORPORATE_DESK', 'OTA_BOOKING_COM')
  AND b.check_in_date BETWEEN DATE '2026-08-01' AND DATE '2026-08-31'
GROUP BY g.guest_id, g.first_name, g.last_name, g.email
HAVING COUNT(b.booking_id) >= 3 AND SUM(b.total_amount) > 500000.0000
ORDER BY total_folio_spend DESC;

-- QUERY 2 (OPTIMIZED): Night Audit Payment Gateway Settlement Exceptions
-- Expected Improvement: Sequential Scan on 15,008 payment rows replaced by Index-Only Scan
--                       on partial index idx_payments_exceptions_partial.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT
    p.gateway_provider,
    p.payment_method,
    p.payment_status,
    COUNT(p.payment_id) AS exception_count,
    SUM(p.amount_paid) AS total_exception_volume,
    ROUND(AVG(p.amount_paid), 2) AS avg_exception_ticket
FROM payments p
JOIN bookings b ON p.booking_id = b.booking_id
WHERE p.payment_status IN ('FAILED', 'REFUNDED')
  AND p.paid_at >= '2026-06-01 00:00:00+01'
GROUP BY p.gateway_provider, p.payment_method, p.payment_status
ORDER BY total_exception_volume DESC;

-- QUERY 3 (OPTIMIZED): Room Folio Statement with Chronological Running Revenue
-- Expected Improvement: Eliminates intermediate Sort before WindowAgg via pre-sorted
--                       composite covering index idx_bookings_room_checkin_composite.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT
    b.check_in_date,
    b.check_out_date,
    b.booking_reference,
    b.booking_channel,
    b.booking_status,
    b.subtotal_amount,
    b.tax_amount,
    b.total_amount,
    SUM(b.total_amount) OVER (
        PARTITION BY b.room_id
        ORDER BY b.check_in_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_room_revenue
FROM bookings b
JOIN rooms r ON b.room_id = r.room_id
WHERE r.room_number = 'A101'
  AND b.check_in_date >= DATE '2026-05-01'
ORDER BY b.check_in_date DESC;

-- QUERY 4 (OPTIMIZED): Loyalty Tier Active Booking Ceiling & Revenue Compliance Audit
-- Expected Improvement: Uses partial covering index idx_bookings_status_guest_covering.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH active_guest_bookings AS (
    SELECT
        b.guest_id,
        COUNT(b.booking_id) AS active_booking_count,
        SUM(b.total_amount) AS active_folio_total
    FROM bookings b
    WHERE b.booking_status IN ('CONFIRMED', 'CHECKED_IN')
      AND b.check_in_date >= DATE '2026-10-15'
    GROUP BY b.guest_id
)
SELECT
    g.first_name || ' ' || g.last_name AS guest_name,
    g.phone_number,
    lt.tier_name,
    lt.max_active_bookings AS tier_booking_cap,
    agb.active_booking_count,
    (agb.active_booking_count - lt.max_active_bookings) AS excess_bookings,
    agb.active_folio_total
FROM active_guest_bookings agb
JOIN guests g ON agb.guest_id = g.guest_id
JOIN loyalty_tiers lt ON g.loyalty_tier = lt.tier_level
WHERE agb.active_booking_count > lt.max_active_bookings
ORDER BY agb.active_folio_total DESC
LIMIT 25;

-- QUERY 5 (OPTIMIZED): Executive Tower Luxury Suite Turnover & Tax Yield Ranking
-- Expected Improvement: Uses partial covering index idx_rooms_executive_tower_covering
--                       and composite covering index idx_bookings_checkin_channel_covering.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT
    r.room_number,
    rc.category_name,
    COUNT(b.booking_id) AS completed_stays,
    SUM(b.subtotal_amount) AS net_room_revenue,
    SUM(b.tax_amount) AS total_vat_and_consumption_tax,
    SUM(b.total_amount) AS gross_folio_revenue,
    ROUND(AVG(b.total_amount), 2) AS avg_booking_value,
    MAX(b.check_out_date) AS latest_checkout
FROM bookings b
JOIN rooms r ON b.room_id = r.room_id
JOIN room_categories rc ON r.category_id = rc.category_id
WHERE r.wing = 'EXECUTIVE_TOWER'
  AND b.booking_status IN ('CHECKED_OUT', 'CHECKED_IN')
  AND b.check_in_date BETWEEN DATE '2026-10-01' AND DATE '2026-10-31'
GROUP BY r.room_number, rc.category_name
ORDER BY gross_folio_revenue DESC
LIMIT 15;
