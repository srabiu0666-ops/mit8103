-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 1 - Database Design and Modelling
-- Case Study: EkoStay Hospitality Limited
-- File: 02-constraints.sql
-- Description: Business rules, operational triggers, audit trail capture,
--              and foreign key relational indexes.

-- 1. FOREIGN KEY & ACCESS PATH INDEXES
-- Purpose: Accelerate join performance, enforce efficient referential integrity
--          checks, and prevent table scans during relational lookups.
CREATE INDEX idx_guests_loyalty_tier ON guests(loyalty_tier);
CREATE INDEX idx_rooms_category_id ON rooms(category_id);
CREATE INDEX idx_bookings_guest_id ON bookings(guest_id);
CREATE INDEX idx_bookings_room_id ON bookings(room_id);
CREATE INDEX idx_bookings_created_at ON bookings(created_at);
CREATE INDEX idx_payments_booking_id ON payments(booking_id);
CREATE INDEX idx_payments_guest_id ON payments(guest_id);
CREATE INDEX idx_checkin_room_id ON checkin_checkout_records(room_id);
CREATE INDEX idx_audit_logs_entity ON audit_logs(table_name, record_id);

-- 2. TRIGGER FUNCTION: fn_update_timestamp
-- Purpose: Automatically updates the 'updated_at' column whenever a row is modified.
CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_guests_updated_at
BEFORE UPDATE ON guests
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_rooms_updated_at
BEFORE UPDATE ON rooms
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_bookings_updated_at
BEFORE UPDATE ON bookings
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

-- 3. TRIGGER FUNCTION: fn_audit_room_and_booking_changes
-- Purpose: Automatically records any status or pricing mutation on rooms
--          and bookings into the immutable audit_logs table.
CREATE OR REPLACE FUNCTION fn_audit_room_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.room_status <> NEW.room_status OR OLD.category_id <> NEW.category_id) THEN
        INSERT INTO audit_logs (
            table_name,
            record_id,
            action,
            old_state,
            new_state,
            changed_by,
            client_ip
        ) VALUES (
            'rooms',
            OLD.room_id::VARCHAR,
            'UPDATE',
            jsonb_build_object(
                'room_number', OLD.room_number,
                'room_status', OLD.room_status,
                'category_id', OLD.category_id,
                'updated_at', OLD.updated_at
            ),
            jsonb_build_object(
                'room_number', NEW.room_number,
                'room_status', NEW.room_status,
                'category_id', NEW.category_id,
                'updated_at', CURRENT_TIMESTAMP
            ),
            CURRENT_USER,
            inet_client_addr()::VARCHAR
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_room_mutations
AFTER UPDATE ON rooms
FOR EACH ROW
EXECUTE FUNCTION fn_audit_room_changes();

CREATE OR REPLACE FUNCTION fn_audit_booking_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.booking_status <> NEW.booking_status OR OLD.total_amount <> NEW.total_amount) THEN
        INSERT INTO audit_logs (
            table_name,
            record_id,
            action,
            old_state,
            new_state,
            changed_by,
            client_ip
        ) VALUES (
            'bookings',
            OLD.booking_id::VARCHAR,
            'UPDATE',
            jsonb_build_object(
                'booking_reference', OLD.booking_reference,
                'booking_status', OLD.booking_status,
                'total_amount', OLD.total_amount,
                'updated_at', OLD.updated_at
            ),
            jsonb_build_object(
                'booking_reference', NEW.booking_reference,
                'booking_status', NEW.booking_status,
                'total_amount', NEW.total_amount,
                'updated_at', CURRENT_TIMESTAMP
            ),
            CURRENT_USER,
            inet_client_addr()::VARCHAR
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_booking_mutations
AFTER UPDATE ON bookings
FOR EACH ROW
EXECUTE FUNCTION fn_audit_booking_changes();

-- 4. TRIGGER FUNCTION: fn_validate_room_and_guest_for_booking
-- Purpose: Enforces operational hospitality rules before inserting a booking:
--          1. Rejects bookings for rooms in OUT_OF_ORDER maintenance status.
--          2. Rejects bookings for guests in BLACKLISTED status.
--          3. Rejects bookings where num_guests exceeds the room category's max_occupancy.
--          4. Prevents overlapping active bookings on the same room for the requested dates.
CREATE OR REPLACE FUNCTION fn_validate_room_and_guest_for_booking()
RETURNS TRIGGER AS $$
DECLARE
    v_room_status VARCHAR(20);
    v_room_number CHAR(4);
    v_max_occupancy INT;
    v_guest_status VARCHAR(25);
    v_conflict_ref VARCHAR(64);
BEGIN
    -- Retrieve room status and category capacity
    SELECT r.room_status, r.room_number, rc.max_occupancy
    INTO v_room_status, v_room_number, v_max_occupancy
    FROM rooms r
    JOIN room_categories rc ON r.category_id = rc.category_id
    WHERE r.room_id = NEW.room_id;

    IF v_room_status IS NULL THEN
        RAISE EXCEPTION 'Room % does not exist.', NEW.room_id;
    END IF;

    -- Rule 1: Block reservations on OUT_OF_ORDER rooms
    IF v_room_status = 'OUT_OF_ORDER' AND NEW.booking_status IN ('PENDING_PAYMENT', 'CONFIRMED', 'CHECKED_IN') THEN
        RAISE EXCEPTION 'Booking rejected: Room % (%) is currently in OUT_OF_ORDER maintenance status.',
            v_room_number, NEW.room_id;
    END IF;

    -- Rule 2: Block exceeding room category max occupancy
    IF NEW.num_guests > v_max_occupancy THEN
        RAISE EXCEPTION 'Booking rejected: Requested guest count (%) exceeds maximum occupancy (%) for Room %.',
            NEW.num_guests, v_max_occupancy, v_room_number;
    END IF;

    -- Rule 3: Block reservations for BLACKLISTED guests
    SELECT guest_status INTO v_guest_status
    FROM guests
    WHERE guest_id = NEW.guest_id;

    IF v_guest_status = 'BLACKLISTED' THEN
        RAISE EXCEPTION 'Booking rejected: Guest % is currently BLACKLISTED.', NEW.guest_id;
    END IF;

    -- Rule 4: Prevent double-booking date overlaps for active reservations
    IF NEW.booking_status IN ('CONFIRMED', 'CHECKED_IN') THEN
        SELECT b.booking_reference INTO v_conflict_ref
        FROM bookings b
        WHERE b.room_id = NEW.room_id
          AND b.booking_id <> NEW.booking_id
          AND b.booking_status IN ('CONFIRMED', 'CHECKED_IN')
          AND b.check_in_date < NEW.check_out_date
          AND b.check_out_date > NEW.check_in_date
        LIMIT 1;

        IF v_conflict_ref IS NOT NULL THEN
            RAISE EXCEPTION 'Booking rejected: Room % is already reserved under % for overlapping dates (% to %).',
                v_room_number, v_conflict_ref, NEW.check_in_date, NEW.check_out_date;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_booking_rules
BEFORE INSERT ON bookings
FOR EACH ROW
EXECUTE FUNCTION fn_validate_room_and_guest_for_booking();
