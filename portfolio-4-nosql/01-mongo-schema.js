// MongoDB Schema Setup for EkoStay Smart Room IoT & Concierge Document Store
// MIT 8103 Advanced Database Systems - Portfolio 4

const dbName = 'ekostay_nosql';
const dbInstance = db.getSiblingDB(dbName);

print('Configuring EkoStay collections on ' + dbName);

// Drop old collections to ensure clean setup
dbInstance.room_iot_telemetry.drop();
dbInstance.guest_concierge_requests.drop();

// 1. room_iot_telemetry collection with JSON schema validation
dbInstance.createCollection('room_iot_telemetry', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['room_number', 'guest_id', 'device_id', 'event_type', 'timestamp', 'property_location'],
            properties: {
                room_number: {
                    bsonType: 'string',
                    description: '4-character hotel room identifier matching PostgreSQL rooms table'
                },
                guest_id: {
                    bsonType: 'string',
                    description: 'Guest UUID string matching PostgreSQL guests table'
                },
                device_id: {
                    bsonType: 'string',
                    description: 'Smart door lock, BLE beacon, or guest mobile hardware ID'
                },
                ip_address: {
                    bsonType: 'string'
                },
                event_type: {
                    enum: ['DIGITAL_KEY_UNLOCK', 'KEYCARD_TAP_DENIED', 'HVAC_SETPOINT_CHANGE', 'DO_NOT_DISTURB_TOGGLE', 'PANIC_BUTTON_ALERT']
                },
                access_channel: {
                    enum: ['BLE_MOBILE_KEY', 'RFID_KEYCARD', 'IN_ROOM_TABLET', 'REMOTE_WEB_API']
                },
                timestamp: {
                    bsonType: 'date'
                },
                property_location: {
                    bsonType: 'object',
                    required: ['city', 'country', 'type', 'coordinates'],
                    properties: {
                        property_branch: { bsonType: 'string' },
                        city: { bsonType: 'string' },
                        state: { bsonType: 'string' },
                        country: { bsonType: 'string' },
                        type: { enum: ['Point'] },
                        coordinates: {
                            bsonType: 'array',
                            minItems: 2,
                            maxItems: 2,
                            items: { bsonType: ['double', 'int', 'decimal'] },
                            description: '[longitude, latitude] GeoJSON format'
                        }
                    }
                },
                sensor_metrics: {
                    bsonType: 'object',
                    properties: {
                        cabin_temp_celsius: { bsonType: ['double', 'int', 'decimal'] },
                        humidity_pct: { bsonType: ['double', 'int', 'decimal'] },
                        lock_battery_pct: { bsonType: ['int', 'double'] },
                        vpn_or_proxy_detected: { bsonType: 'bool' }
                    }
                }
            }
        }
    }
});

// Indexes for room_iot_telemetry
dbInstance.room_iot_telemetry.createIndex(
    { room_number: 1, timestamp: -1 },
    { name: 'idx_room_timestamp_desc' }
);

dbInstance.room_iot_telemetry.createIndex(
    { 'property_location.coordinates': '2dsphere' },
    { name: 'idx_telemetry_geospatial' }
);

// TTL index to automatically prune raw IoT and access telemetry after 90 days (NDPR compliance)
dbInstance.room_iot_telemetry.createIndex(
    { timestamp: 1 },
    { expireAfterSeconds: 7776000, name: 'idx_ttl_90_days' }
);

// 2. guest_concierge_requests collection (Polymorphic service & incident tickets)
dbInstance.createCollection('guest_concierge_requests', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['ticket_id', 'booking_reference', 'room_number', 'guest_id', 'request_category', 'priority_score', 'ticket_status', 'created_at'],
            properties: {
                ticket_id: { bsonType: 'string' },
                booking_reference: { bsonType: 'string' },
                room_number: { bsonType: 'string' },
                guest_id: { bsonType: 'string' },
                request_category: {
                    enum: ['SECURITY_INCIDENT', 'IN_ROOM_DINING', 'AIRPORT_CHAUFFEUR', 'FACILITY_MAINTENANCE', 'HOUSEKEEPING_TURNDOWN']
                },
                priority_score: { bsonType: 'int', minimum: 0, maximum: 100 },
                ticket_status: {
                    enum: ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'ESCALATED_TO_SECURITY']
                },
                resolution_actions: {
                    bsonType: 'array',
                    items: { bsonType: 'string' }
                },
                staff_activity_log: {
                    bsonType: 'array',
                    items: {
                        bsonType: 'object',
                        required: ['staff_id', 'note', 'timestamp'],
                        properties: {
                            staff_id: { bsonType: 'string' },
                            note: { bsonType: 'string' },
                            timestamp: { bsonType: 'date' }
                        }
                    }
                },
                created_at: { bsonType: 'date' },
                updated_at: { bsonType: 'date' }
            }
        }
    }
});

dbInstance.guest_concierge_requests.createIndex(
    { ticket_status: 1, priority_score: -1 },
    { name: 'idx_status_priority_score' }
);

dbInstance.guest_concierge_requests.createIndex(
    { room_number: 1, booking_reference: 1 },
    { name: 'idx_concierge_room_booking' }
);

print('Collections and indexes created successfully.');
