// Smart Room IoT Telemetry & Concierge Seed Data for EkoStay MongoDB
// MIT 8103 Advanced Database Systems - Portfolio 4

const dbInstance = db.getSiblingDB('ekostay_nosql');

print('Seeding smart room IoT telemetry events...');

// 1. room_iot_telemetry records
const telemetryEvents = [
    // Guest 3: Ibrahim Suleiman - Legitimate BLE mobile key unlock in Diplomatic Suite D402 (Lagos Victoria Island)
    {
        room_number: 'D402',
        guest_id: 'a0000000-0000-0000-0000-000000000003',
        device_id: 'BLE-IPHONE16PRO-SULEIMAN',
        ip_address: '197.210.64.15',
        event_type: 'DIGITAL_KEY_UNLOCK',
        access_channel: 'BLE_MOBILE_KEY',
        timestamp: new Date('2026-10-12T13:10:00Z'),
        property_location: {
            property_branch: 'EkoStay Grand Victoria Island',
            city: 'Lagos',
            state: 'Lagos State',
            country: 'Nigeria',
            type: 'Point',
            coordinates: [3.4219, 6.4281] // [longitude, latitude] Victoria Island, Lagos
        },
        sensor_metrics: {
            cabin_temp_celsius: 21.5,
            humidity_pct: 48.0,
            lock_battery_pct: 94,
            vpn_or_proxy_detected: false
        }
    },
    {
        room_number: 'D402',
        guest_id: 'a0000000-0000-0000-0000-000000000003',
        device_id: 'TABLET-WALL-D402',
        ip_address: '10.20.4.102',
        event_type: 'HVAC_SETPOINT_CHANGE',
        access_channel: 'IN_ROOM_TABLET',
        timestamp: new Date('2026-10-12T13:15:30Z'),
        property_location: {
            property_branch: 'EkoStay Grand Victoria Island',
            city: 'Lagos',
            state: 'Lagos State',
            country: 'Nigeria',
            type: 'Point',
            coordinates: [3.4219, 6.4281]
        },
        sensor_metrics: {
            cabin_temp_celsius: 19.5,
            humidity_pct: 46.5,
            lock_battery_pct: 94,
            vpn_or_proxy_detected: false
        }
    },

    // Guest 5: Chinedu Okafor - Normal BLE & Tablet usage in Lagoon View Room B201
    {
        room_number: 'B201',
        guest_id: 'a0000000-0000-0000-0000-000000000005',
        device_id: 'BLE-GALAXYS24-OKAFOR',
        ip_address: '105.112.98.22',
        event_type: 'DIGITAL_KEY_UNLOCK',
        access_channel: 'BLE_MOBILE_KEY',
        timestamp: new Date('2026-10-13T14:25:00Z'),
        property_location: {
            property_branch: 'EkoStay Grand Victoria Island',
            city: 'Lagos',
            state: 'Lagos State',
            country: 'Nigeria',
            type: 'Point',
            coordinates: [3.4219, 6.4281]
        },
        sensor_metrics: {
            cabin_temp_celsius: 22.0,
            humidity_pct: 51.0,
            lock_battery_pct: 88,
            vpn_or_proxy_detected: false
        }
    },
    {
        room_number: 'B201',
        guest_id: 'a0000000-0000-0000-0000-000000000005',
        device_id: 'TABLET-WALL-B201',
        ip_address: '10.20.2.101',
        event_type: 'DO_NOT_DISTURB_TOGGLE',
        access_channel: 'IN_ROOM_TABLET',
        timestamp: new Date('2026-10-13T21:00:00Z'),
        property_location: {
            property_branch: 'EkoStay Grand Victoria Island',
            city: 'Lagos',
            state: 'Lagos State',
            country: 'Nigeria',
            type: 'Point',
            coordinates: [3.4219, 6.4281]
        },
        sensor_metrics: {
            cabin_temp_celsius: 20.5,
            humidity_pct: 49.0,
            lock_battery_pct: 88,
            vpn_or_proxy_detected: false
        }
    },

    // Guest 6: Funke Williams - RFID keycard unlock in Executive Twin C301
    {
        room_number: 'C301',
        guest_id: 'a0000000-0000-0000-0000-000000000006',
        device_id: 'RFID-READER-C301',
        ip_address: '10.20.3.101',
        event_type: 'DIGITAL_KEY_UNLOCK',
        access_channel: 'RFID_KEYCARD',
        timestamp: new Date('2026-10-14T10:20:00Z'),
        property_location: {
            property_branch: 'EkoStay Maitama Abuja',
            city: 'Abuja',
            state: 'Federal Capital Territory',
            country: 'Nigeria',
            type: 'Point',
            coordinates: [7.4913, 9.0820] // [longitude, latitude] Maitama, Abuja
        },
        sensor_metrics: {
            cabin_temp_celsius: 21.0,
            humidity_pct: 42.0,
            lock_battery_pct: 91,
            vpn_or_proxy_detected: false
        }
    },

    // Guest 11: Kunle Coker (BLACKLISTED) - ANOMALOUS REMOTE API KEY SPOOFING & UNAUTHORIZED ENTRY ATTEMPT
    // Event A: Denied RFID keycard tap at Room C303 (OUT_OF_ORDER room in Lagos)
    {
        room_number: 'C303',
        guest_id: 'a0000000-0000-0000-0000-000000000011',
        device_id: 'RFID-CLONE-CARD-099',
        ip_address: '197.210.45.88',
        event_type: 'KEYCARD_TAP_DENIED',
        access_channel: 'RFID_KEYCARD',
        timestamp: new Date('2026-10-18T02:00:00Z'),
        property_location: {
            property_branch: 'EkoStay Grand Victoria Island',
            city: 'Lagos',
            state: 'Lagos State',
            country: 'Nigeria',
            type: 'Point',
            coordinates: [3.4219, 6.4281]
        },
        sensor_metrics: {
            cabin_temp_celsius: 26.8,
            humidity_pct: 64.0,
            lock_battery_pct: 76,
            vpn_or_proxy_detected: false
        }
    },
    // Event B: 12 minutes later, remote web API unlock attempt on Diplomatic Suite D402 from Frankfurt Tor VPN
    {
        room_number: 'D402',
        guest_id: 'a0000000-0000-0000-0000-000000000011',
        device_id: 'API-BOT-LINUX-X86',
        ip_address: '185.220.101.5',
        event_type: 'KEYCARD_TAP_DENIED',
        access_channel: 'REMOTE_WEB_API',
        timestamp: new Date('2026-10-18T02:12:30Z'),
        property_location: {
            property_branch: 'Foreign Tor Relay',
            city: 'Frankfurt',
            state: 'Hesse',
            country: 'Germany',
            type: 'Point',
            coordinates: [8.6821, 50.1109] // [longitude, latitude] Frankfurt, Germany
        },
        sensor_metrics: {
            cabin_temp_celsius: 19.5,
            humidity_pct: 46.0,
            lock_battery_pct: 93,
            vpn_or_proxy_detected: true
        }
    },
    // Event C: Second remote API unlock attempt from Frankfurt VPN exit node
    {
        room_number: 'E501',
        guest_id: 'a0000000-0000-0000-0000-000000000011',
        device_id: 'API-BOT-LINUX-X86',
        ip_address: '185.220.101.5',
        event_type: 'KEYCARD_TAP_DENIED',
        access_channel: 'REMOTE_WEB_API',
        timestamp: new Date('2026-10-18T02:13:15Z'),
        property_location: {
            property_branch: 'Foreign Tor Relay',
            city: 'Frankfurt',
            state: 'Hesse',
            country: 'Germany',
            type: 'Point',
            coordinates: [8.6821, 50.1109]
        },
        sensor_metrics: {
            cabin_temp_celsius: 20.0,
            humidity_pct: 45.0,
            lock_battery_pct: 97,
            vpn_or_proxy_detected: true
        }
    }
];

dbInstance.room_iot_telemetry.insertMany(telemetryEvents);
print('Inserted ' + telemetryEvents.length + ' smart room IoT telemetry records.');

// 2. guest_concierge_requests records (Polymorphic service & security cases)
const conciergeTickets = [
    {
        ticket_id: 'TKT-2026-OCT-001',
        booking_reference: 'EKO-RES-20261010-0003',
        room_number: 'D402',
        guest_id: 'a0000000-0000-0000-0000-000000000011',
        request_category: 'SECURITY_INCIDENT',
        priority_score: 96,
        ticket_status: 'ESCALATED_TO_SECURITY',
        resolution_actions: ['KEYCARD_TOKEN_REVOKE', 'GUEST_PROFILE_BLACKLIST', 'FIREWALL_IP_BLOCK'],
        staff_activity_log: [
            {
                staff_id: 'SECURITY_CHIEF_BALOGUN',
                note: 'Smart lock gateway blocked cloned RFID tap on C303 followed by remote API unlock replay from Frankfurt Tor IP 185.220.101.5.',
                timestamp: new Date('2026-10-18T02:15:00Z')
            },
            {
                staff_id: 'DUTY_MANAGER_SEYI',
                note: 'Rotated BLE encryption keys for Diplomatic Suite D402 and Presidential Penthouse E501.',
                timestamp: new Date('2026-10-18T02:25:00Z')
            }
        ],
        incident_metadata: {
            flagged_ips: ['185.220.101.5', '197.210.45.88'],
            attack_vector: 'BLE_API_REPLAY_AND_RFID_CLONE',
            security_wing_patrol_dispatched: true
        },
        created_at: new Date('2026-10-18T02:14:00Z'),
        updated_at: new Date('2026-10-18T02:30:00Z')
    },
    {
        ticket_id: 'TKT-2026-OCT-002',
        booking_reference: 'EKO-RES-20261010-0003',
        room_number: 'D402',
        guest_id: 'a0000000-0000-0000-0000-000000000003',
        request_category: 'IN_ROOM_DINING',
        priority_score: 65,
        ticket_status: 'RESOLVED',
        resolution_actions: ['BUTLER_TRAY_DELIVERED', 'FOLIO_POSTED'],
        staff_activity_log: [
            {
                staff_id: 'BUTLER_DESK_04',
                note: 'VIP Platinum guest ordered grilled Atlantic prawns, jollof rice, and sparkling water for 2 guests.',
                timestamp: new Date('2026-10-13T19:10:00Z')
            },
            {
                staff_id: 'BUTLER_DESK_04',
                note: 'Delivered within 24 minutes; complimentary fruit platter included per Platinum Royal tier benefit.',
                timestamp: new Date('2026-10-13T19:34:00Z')
            }
        ],
        dining_order_details: {
            items: [
                { item_name: 'Grilled Lagos Tiger Prawns', qty: 2, unit_price_ngn: 28000 },
                { item_name: 'San Pellegrino 750ml', qty: 2, unit_price_ngn: 6500 }
            ],
            dietary_allergies: ['Peanuts'],
            cutlery_sets: 2
        },
        created_at: new Date('2026-10-13T19:08:00Z'),
        updated_at: new Date('2026-10-13T19:35:00Z')
    },
    {
        ticket_id: 'TKT-2026-OCT-003',
        booking_reference: 'EKO-RES-20261011-0004',
        room_number: 'C303',
        guest_id: 'a0000000-0000-0000-0000-000000000005',
        request_category: 'FACILITY_MAINTENANCE',
        priority_score: 85,
        ticket_status: 'IN_PROGRESS',
        resolution_actions: ['ROOM_MARKED_OUT_OF_ORDER', 'HVAC_VALVE_ORDERED'],
        staff_activity_log: [
            {
                staff_id: 'CHIEF_ENGINEER_BODE',
                note: 'IoT sensor in C303 reported cabin temperature 26.8C above 21.0C setpoint; chilled water actuator valve seized.',
                timestamp: new Date('2026-10-15T09:00:00Z')
            }
        ],
        engineering_diagnostics: {
            hvac_unit_serial: 'DAIKIN-VRV-C303',
            measured_temp_c: 26.8,
            target_temp_c: 21.0,
            estimated_repair_hours: 18
        },
        created_at: new Date('2026-10-15T08:50:00Z'),
        updated_at: new Date('2026-10-15T09:15:00Z')
    }
];

dbInstance.guest_concierge_requests.insertMany(conciergeTickets);
print('Inserted ' + conciergeTickets.length + ' polymorphic guest concierge & security tickets.');
print('EkoStay MongoDB Seed Data complete.');
