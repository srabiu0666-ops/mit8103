-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 1 - Database Design and Modelling
-- Case Study: EkoStay Hospitality Limited (Hotel Reservation & Property Management System)
-- File: 01-schema.sql
-- Description: DDL Schema definition with relational tables, primary keys,
--              foreign keys, and data integrity constraints.
-- Target RDBMS: PostgreSQL 14+ (Compatible with ANSI SQL standards)

-- Ensure pgcrypto is available for cryptographic hashing and UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Clean teardown of existing schema objects (in reverse dependency order)
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS checkin_checkout_records CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS bookings CASCADE;
DROP TABLE IF EXISTS rooms CASCADE;
DROP TABLE IF EXISTS room_categories CASCADE;
DROP TABLE IF EXISTS guests CASCADE;
DROP TABLE IF EXISTS loyalty_tiers CASCADE;

-- 1. ENTITY: loyalty_tiers (Reference/Lookup Table)
-- Purpose: Defines EkoStay Rewards membership classifications, discount rates,
--          complimentary late check-out allowances, and concurrent booking limits.
CREATE TABLE loyalty_tiers (
    tier_level INT PRIMARY KEY,
    tier_name VARCHAR(50) NOT NULL UNIQUE,
    min_nights_required INT NOT NULL CHECK (min_nights_required >= 0),
    discount_percentage NUMERIC(5, 2) NOT NULL CHECK (discount_percentage BETWEEN 0.00 AND 50.00),
    late_checkout_hours INT NOT NULL CHECK (late_checkout_hours BETWEEN 0 AND 6),
    max_active_bookings INT NOT NULL CHECK (max_active_bookings > 0),
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE loyalty_tiers IS 'Reference table for EkoStay Rewards guest loyalty tier classifications and benefits.';

-- 2. ENTITY: guests (Guest Master Data)
-- Purpose: Stores verified guest profiles, hashed national/passport identifiers,
--          contact details, and current loyalty standing.
CREATE TABLE guests (
    guest_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone_number VARCHAR(15) NOT NULL UNIQUE,
    nin_hash CHAR(64) UNIQUE, -- SHA-256 hash of 11-digit National Identity Number
    passport_hash CHAR(64) UNIQUE, -- SHA-256 hash of International Passport Number
    nationality VARCHAR(50) NOT NULL DEFAULT 'Nigerian',
    loyalty_tier INT NOT NULL DEFAULT 1 REFERENCES loyalty_tiers(tier_level) ON DELETE RESTRICT,
    guest_status VARCHAR(25) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_guest_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_guest_phone CHECK (phone_number ~ '^\+234[0-9]{10}$'),
    CONSTRAINT chk_guest_status CHECK (guest_status IN ('ACTIVE', 'BLACKLISTED', 'PENDING_VERIFICATION', 'INACTIVE'))
);

COMMENT ON TABLE guests IS 'Master record of EkoStay individual and corporate guests with hashed identity credentials.';

-- 3. ENTITY: room_categories (Standardized Tariff & Accommodation Catalog)
-- Purpose: Separates room class attributes (tariff, occupancy limit, bed type)
--          from physical rooms to satisfy 3NF/BCNF normalization.
CREATE TABLE room_categories (
    category_id SERIAL PRIMARY KEY,
    category_code VARCHAR(15) NOT NULL UNIQUE,
    category_name VARCHAR(60) NOT NULL UNIQUE,
    base_nightly_rate NUMERIC(15, 2) NOT NULL CHECK (base_nightly_rate > 0.00),
    caution_deposit_amount NUMERIC(15, 2) NOT NULL CHECK (caution_deposit_amount >= 0.00),
    max_occupancy INT NOT NULL CHECK (max_occupancy BETWEEN 1 AND 8),
    bed_configuration VARCHAR(50) NOT NULL,
    square_meters INT NOT NULL CHECK (square_meters > 10),
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE room_categories IS 'Standardized room classification catalog with base nightly tariffs and occupancy caps.';

-- 4. ENTITY: rooms (Physical Hotel Room Inventory)
-- Purpose: Maintains physical hotel rooms across wings and floors, linked to
--          room_categories, with operational housekeeping/maintenance statuses.
CREATE TABLE rooms (
    room_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_number CHAR(4) NOT NULL UNIQUE, -- Wing letter + 3-digit room number (e.g., A101, B204)
    category_id INT NOT NULL REFERENCES room_categories(category_id) ON DELETE RESTRICT,
    floor_number INT NOT NULL CHECK (floor_number BETWEEN 1 AND 25),
    wing VARCHAR(25) NOT NULL,
    room_status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE',
    is_smoking BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_room_number_format CHECK (room_number ~ '^[A-Z][0-9]{3}$'),
    CONSTRAINT chk_room_wing CHECK (wing IN ('ATLANTIC_WING', 'LAGOON_WING', 'EXECUTIVE_TOWER', 'GARDEN_WING')),
    CONSTRAINT chk_room_status CHECK (room_status IN ('AVAILABLE', 'OCCUPIED', 'DIRTY_CLEANING', 'OUT_OF_ORDER'))
);

COMMENT ON TABLE rooms IS 'Physical room inventory with real-time operational housekeeping and occupancy states.';

-- 5. ENTITY: bookings (Core Reservation Ledger)
-- Purpose: Records guest reservations, stay date windows, applied nightly rates,
--          statutory VAT/Consumption taxes, and booking lifecycle states.
CREATE TABLE bookings (
    booking_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_reference VARCHAR(64) NOT NULL UNIQUE,
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
    CONSTRAINT chk_booking_dates CHECK (check_out_date > check_in_date),
    CONSTRAINT chk_booking_status CHECK (booking_status IN (
        'PENDING_PAYMENT',
        'CONFIRMED',
        'CHECKED_IN',
        'CHECKED_OUT',
        'CANCELLED',
        'NO_SHOW'
    )),
    CONSTRAINT chk_booking_channel CHECK (booking_channel IN (
        'DIRECT_WEB',
        'MOBILE_APP',
        'WALK_IN',
        'OTA_BOOKING_COM',
        'CORPORATE_DESK'
    ))
);

COMMENT ON TABLE bookings IS 'Primary reservation table recording stay dates, pricing breakdowns, and booking lifecycle.';

-- 6. ENTITY: payments (Hospitality Folio & Gateway Settlement Ledger)
-- Purpose: Records reservation payments, POS charges, gateway session tokens,
--          and settlement statuses across Nigerian payment processors.
CREATE TABLE payments (
    payment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_reference VARCHAR(64) NOT NULL UNIQUE,
    booking_id UUID NOT NULL REFERENCES bookings(booking_id) ON DELETE RESTRICT,
    guest_id UUID NOT NULL REFERENCES guests(guest_id) ON DELETE RESTRICT,
    payment_method VARCHAR(25) NOT NULL,
    gateway_provider VARCHAR(30) NOT NULL,
    gateway_session_id VARCHAR(40) UNIQUE,
    currency CHAR(3) NOT NULL DEFAULT 'NGN',
    amount_paid NUMERIC(18, 4) NOT NULL CHECK (amount_paid > 0.0000),
    processing_fee NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (processing_fee >= 0.0000),
    payment_status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',
    narration VARCHAR(255) NOT NULL,
    paid_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_payment_method CHECK (payment_method IN ('DEBIT_CARD', 'BANK_TRANSFER_NIP', 'POS_TERMINAL', 'CORPORATE_INVOICE', 'WALLET')),
    CONSTRAINT chk_gateway_provider CHECK (gateway_provider IN ('PAYSTACK', 'FLUTTERWAVE', 'INTERSWITCH_POS', 'MONIEPOINT_POS', 'NIBSS_NIP_DIRECT')),
    CONSTRAINT chk_payment_currency CHECK (currency IN ('NGN', 'USD', 'GBP', 'EUR')),
    CONSTRAINT chk_payment_status CHECK (payment_status IN ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED'))
);

COMMENT ON TABLE payments IS 'Financial settlement ledger for guest bookings across web gateways and front-desk POS terminals.';

-- 7. ENTITY: checkin_checkout_records (Front-Desk Operational Stay Log)
-- Purpose: Captures physical guest arrival and departure timestamps, RFID/BLE
--          keycard assignments, caution deposit holds, and room inspection results.
CREATE TABLE checkin_checkout_records (
    record_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL UNIQUE REFERENCES bookings(booking_id) ON DELETE RESTRICT,
    room_id UUID NOT NULL REFERENCES rooms(room_id) ON DELETE RESTRICT,
    guest_id UUID NOT NULL REFERENCES guests(guest_id) ON DELETE RESTRICT,
    actual_check_in_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actual_check_out_at TIMESTAMPTZ,
    keycard_code VARCHAR(30) NOT NULL,
    deposit_held NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (deposit_held >= 0.00),
    late_checkout_fee NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (late_checkout_fee >= 0.00),
    checked_in_by VARCHAR(60) NOT NULL,
    checked_out_by VARCHAR(60),
    room_inspection_status VARCHAR(25) NOT NULL DEFAULT 'PENDING_INSPECTION',
    front_desk_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_checkout_after_checkin CHECK (actual_check_out_at IS NULL OR actual_check_out_at > actual_check_in_at),
    CONSTRAINT chk_inspection_status CHECK (room_inspection_status IN ('PENDING_INSPECTION', 'CLEARED_NO_DAMAGE', 'DAMAGE_CHARGED', 'MINIBAR_BILLED'))
);

COMMENT ON TABLE checkin_checkout_records IS 'Operational front-desk log recording physical check-in/out events, keycards, and room inspections.';

-- 8. ENTITY: audit_logs (Immutable Change-Data-Capture Trail)
-- Purpose: Enterprise forensics table tracking administrative, room status, and
--          reservation state mutations with previous and updated JSONB snapshots.
CREATE TABLE audit_logs (
    log_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id VARCHAR(64) NOT NULL,
    action VARCHAR(10) NOT NULL,
    old_state JSONB,
    new_state JSONB,
    changed_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM_PROCESS',
    client_ip VARCHAR(45),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_audit_action CHECK (action IN ('INSERT', 'UPDATE', 'DELETE'))
);

COMMENT ON TABLE audit_logs IS 'Append-only audit trail capturing structural, room status, and reservation modifications.';
