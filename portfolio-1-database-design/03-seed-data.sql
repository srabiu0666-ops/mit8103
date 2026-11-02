-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 1 - Database Design and Modelling
-- Case Study: EkoStay Hospitality Limited
-- File: 03-seed-data.sql
-- Description: Realistic baseline dataset reflecting the Nigerian hospitality
--              ecosystem (Loyalty Tiers, Guests, Room Categories, Rooms, Bookings, Payments, Check-In/Out, Audit).

-- 1. SEED: loyalty_tiers (EkoStay Rewards Programme)
INSERT INTO loyalty_tiers (tier_level, tier_name, min_nights_required, discount_percentage, late_checkout_hours, max_active_bookings, description)
VALUES
(1, 'Classic Guest', 0, 0.00, 0, 2, 'Standard entry tier for walk-in and first-time online guests. Standard 12:00 PM check-out.'),
(2, 'Silver Executive', 5, 5.00, 1, 4, 'Frequent business traveler tier requiring 5+ annual nights. Includes 5% tariff discount and 1:00 PM check-out.'),
(3, 'Gold Ambassador', 15, 10.00, 2, 8, 'VIP corporate and diplomatic tier requiring 15+ annual nights. Includes 10% discount and 2:00 PM check-out.'),
(4, 'Platinum Royal', 30, 15.00, 4, 15, 'Top-tier luxury membership with 15% discount, priority suite upgrades, and 4:00 PM late check-out.');

-- 2. SEED: room_categories (Standardized Tariff Catalog in NGN)
INSERT INTO room_categories (category_id, category_code, category_name, base_nightly_rate, caution_deposit_amount, max_occupancy, bed_configuration, square_meters, description)
VALUES
(1, 'STD-KING', 'Classic Standard King', 85000.00, 30000.00, 2, '1 King Bed', 32, 'Ergonomic business room overlooking Eko Gardens with high-speed fiber Wi-Fi and workstation.'),
(2, 'DLX-LAGOON', 'Deluxe Lagoon View', 135000.00, 50000.00, 2, '1 California King Bed', 44, 'Panoramic Kuramo Lagoon view room with private balcony, rain shower, and smart climate control.'),
(3, 'EXEC-TWIN', 'Executive Club Twin', 165000.00, 50000.00, 3, '2 Queen Beds', 52, 'Executive floor accommodation including VIP lounge breakfast and evening cocktail access.'),
(4, 'DIPL-SUITE', 'Diplomatic Suite', 280000.00, 100000.00, 4, '1 King Bed + Sofa Bed', 85, 'Two-bay luxury suite with private dining parlor, kitchenette, and dedicated butler service.'),
(5, 'PRES-PENT', 'Presidential Penthouse', 650000.00, 250000.00, 6, '2 King Master Suites', 190, 'Top-floor oceanfront penthouse featuring private boardroom, jacuzzi terrace, and security vestibule.');

SELECT setval('room_categories_category_id_seq', 5, true);

-- 3. SEED: guests (12 Baseline Guests across Nigerian and International Profiles)
INSERT INTO guests (guest_id, first_name, last_name, email, phone_number, nin_hash, passport_hash, nationality, loyalty_tier, guest_status)
VALUES
('a0000000-0000-0000-0000-000000000001', 'Tunde', 'Bakare', 'tunde.bakare@ekostay.ng', '+2348011234567',
 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
 'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb', 'Nigerian', 3, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000002', 'Ngozi', 'Achebe', 'ngozi.achebe@ekostay.ng', '+2348022345678',
 '4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a',
 '3e23e8160039594a33894f6564e1b1348bbd7a0088d42c4acb73eeaed59c009d', 'Nigerian', 2, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000003', 'Ibrahim', 'Suleiman', 'ibrahim.suleiman@ekostay.ng', '+2348033456789',
 'ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d',
 '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae', 'Nigerian', 4, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000004', 'Zainab', 'Mohammed', 'zainab.mohammed@ekostay.ng', '+2348044567890',
 '7902699be42c8a8e46fbbb4501726517e86b22c56a189f7625a6da49081b2451', NULL, 'Nigerian', 1, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000005', 'Chinedu', 'Okafor', 'chinedu.okafor@ekostay.ng', '+2348055678901',
 'fcba950aca43224aad2221e3fb904e20197d20b62b79e3bc778d0def7f664377',
 '70c7283c153cad20f3153c5f318e517a32371687c42399778ec304214bbdd73d', 'Nigerian', 2, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000006', 'Funke', 'Williams', 'funke.williams@ekostay.ng', '+2348066789012',
 '2f741529ef8f2f01f80ca024b439c7fd69e6b3687353f86e33057e96b349254b',
 '2e7d2c03a9507ae265ecf5b5356885a53393a2029d24139499ddf66f09b9c73b', 'Nigerian', 3, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000007', 'Musa', 'Danjuma', 'musa.danjuma@ekostay.ng', '+2348077890123',
 '5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9', NULL, 'Nigerian', 1, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000008', 'Amaka', 'Nwachukwu', 'amaka.nwachukwu@ekostay.ng', '+2348088901234',
 '18ac3e7343f016890c510e93f935261169d9e3f565436429830faf0934f4f8e4',
 '9b71d224bd62f3785d96d46ad3ea3d73319bfbc2890caadae2dff72519673ca7', 'Nigerian', 2, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000009', 'Segun', 'Adeleke', 'segun.adeleke@ekostay.ng', '+2348099012345',
 '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b',
 'd4735e3a265e16eee03f59718b9b5d03019c07d8b6c51f90da3a666eec13ab35', 'Nigerian', 4, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000010', 'Hadiza', 'Bello', 'hadiza.bello@ekostay.ng', '+2348019876543',
 '4e07408562bedb8b60ce05c1decfe3ad16b72230967de01f640b7e4729b49fce',
 '4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a', 'Nigerian', 2, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000011', 'Kunle', 'Coker', 'kunle.coker@ekostay.ng', '+2348028765432',
 '8527a891e224136950ff32ca212b45bc93f69fbb801c3b1ebedac52775f99e61', NULL, 'Nigerian', 1, 'BLACKLISTED'),

('a0000000-0000-0000-0000-000000000012', 'Folashade', 'Ogundipe', 'folashade.ogundipe@ekostay.ng', '+2348037654321',
 '9a0f4438b8d4c9a83709b4d8307dbbe51909e46a788bb2cfae89921477431201',
 '8b1e5549c9e5da9481a0c5e9418eccf6201af57b899cc3dfbf90032588542312', 'Nigerian', 3, 'ACTIVE');

-- 4. SEED: rooms (14 Physical Hotel Rooms across Wings & Floors)
INSERT INTO rooms (room_id, room_number, category_id, floor_number, wing, room_status, is_smoking)
VALUES
('b0000000-0000-0000-0000-000000000001', 'A101', 1, 1, 'GARDEN_WING', 'AVAILABLE', FALSE),
('b0000000-0000-0000-0000-000000000002', 'A102', 1, 1, 'GARDEN_WING', 'AVAILABLE', FALSE),
('b0000000-0000-0000-0000-000000000003', 'A103', 1, 1, 'GARDEN_WING', 'DIRTY_CLEANING', FALSE),
('b0000000-0000-0000-0000-000000000004', 'B201', 2, 2, 'LAGOON_WING', 'OCCUPIED', FALSE),
('b0000000-0000-0000-0000-000000000005', 'B202', 2, 2, 'LAGOON_WING', 'AVAILABLE', FALSE),
('b0000000-0000-0000-0000-000000000006', 'B203', 2, 2, 'LAGOON_WING', 'AVAILABLE', FALSE),
('b0000000-0000-0000-0000-000000000007', 'C301', 3, 3, 'ATLANTIC_WING', 'OCCUPIED', FALSE),
('b0000000-0000-0000-0000-000000000008', 'C302', 3, 3, 'ATLANTIC_WING', 'AVAILABLE', FALSE),
('b0000000-0000-0000-0000-000000000009', 'C303', 3, 3, 'ATLANTIC_WING', 'OUT_OF_ORDER', FALSE),
('b0000000-0000-0000-0000-000000000010', 'D401', 4, 4, 'EXECUTIVE_TOWER', 'AVAILABLE', FALSE),
('b0000000-0000-0000-0000-000000000011', 'D402', 4, 4, 'EXECUTIVE_TOWER', 'OCCUPIED', FALSE),
('b0000000-0000-0000-0000-000000000012', 'D403', 4, 4, 'EXECUTIVE_TOWER', 'AVAILABLE', FALSE),
('b0000000-0000-0000-0000-000000000013', 'E501', 5, 5, 'EXECUTIVE_TOWER', 'AVAILABLE', FALSE),
('b0000000-0000-0000-0000-000000000014', 'E502', 5, 5, 'EXECUTIVE_TOWER', 'AVAILABLE', FALSE);

-- 5. SEED: bookings (Coherent Reservation Ledger with 12.5% VAT + Hospitality Tax)
INSERT INTO bookings (
    booking_id, booking_reference, guest_id, room_id, check_in_date, check_out_date,
    num_guests, nightly_rate_applied, discount_amount, subtotal_amount, tax_amount, total_amount,
    booking_status, booking_channel, special_requests, created_at
)
VALUES
-- 1. Tunde Bakare: Checked-Out stay in A101 (3 nights @ 85,000, 10% Gold discount)
('c0000000-0000-0000-0000-000000000001', 'EKO-RES-20261001-0001',
 'a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001',
 '2026-10-02', '2026-10-05', 2, 85000.0000, 25500.0000, 229500.0000, 28687.5000, 258187.5000,
 'CHECKED_OUT', 'MOBILE_APP', 'High floor away from elevator; airport pickup requested', '2026-10-01 09:30:00+01'),

-- 2. Ngozi Achebe: Checked-Out stay in B202 (2 nights @ 135,000, 5% Silver discount)
('c0000000-0000-0000-0000-000000000002', 'EKO-RES-20261003-0002',
 'a0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000005',
 '2026-10-04', '2026-10-06', 2, 135000.0000, 13500.0000, 256500.0000, 32062.5000, 288562.5000,
 'CHECKED_OUT', 'DIRECT_WEB', 'Hypoallergenic pillows and extra bottled water', '2026-10-03 11:15:00+01'),

-- 3. Ibrahim Suleiman: Checked-In diplomatic stay in D402 (4 nights @ 280,000, 15% Platinum discount)
('c0000000-0000-0000-0000-000000000003', 'EKO-RES-20261010-0003',
 'a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000011',
 '2026-10-12', '2026-10-16', 2, 280000.0000, 168000.0000, 952000.0000, 119000.0000, 1071000.0000,
 'CHECKED_IN', 'CORPORATE_DESK', 'Diplomatic protocol check-in; fruit basket in parlor', '2026-10-10 14:20:00+01'),

-- 4. Chinedu Okafor: Checked-In business stay in B201 (3 nights @ 135,000, 5% Silver discount)
('c0000000-0000-0000-0000-000000000004', 'EKO-RES-20261011-0004',
 'a0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000004',
 '2026-10-13', '2026-10-16', 1, 135000.0000, 20250.0000, 384750.0000, 48093.7500, 432843.7500,
 'CHECKED_IN', 'MOBILE_APP', 'Quiet lagoon view room for remote conference calls', '2026-10-11 16:40:00+01'),

-- 5. Funke Williams: Checked-In executive stay in C301 (2 nights @ 165,000, 10% Gold discount)
('c0000000-0000-0000-0000-000000000005', 'EKO-RES-20261012-0005',
 'a0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000007',
 '2026-10-14', '2026-10-16', 2, 165000.0000, 33000.0000, 297000.0000, 37125.0000, 334125.0000,
 'CHECKED_IN', 'DIRECT_WEB', 'Early check-in requested at 11:00 AM', '2026-10-12 10:05:00+01'),

-- 6. Segun Adeleke: Confirmed future Presidential Penthouse stay in E501 (2 nights @ 650,000, 15% Platinum discount)
('c0000000-0000-0000-0000-000000000006', 'EKO-RES-20261014-0006',
 'a0000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000013',
 '2026-11-01', '2026-11-03', 4, 650000.0000, 195000.0000, 1105000.0000, 138125.0000, 1243125.0000,
 'CONFIRMED', 'CORPORATE_DESK', 'Executive board retreat; private chef catering setup', '2026-10-14 12:30:00+01'),

-- 7. Folashade Ogundipe: Confirmed future stay in D401 (3 nights @ 280,000, 10% Gold discount)
('c0000000-0000-0000-0000-000000000007', 'EKO-RES-20261015-0007',
 'a0000000-0000-0000-0000-000000000012', 'b0000000-0000-0000-0000-000000000010',
 '2026-11-05', '2026-11-08', 2, 280000.0000, 84000.0000, 756000.0000, 94500.0000, 850500.0000,
 'CONFIRMED', 'MOBILE_APP', 'Anniversary decoration and late check-out benefit', '2026-10-15 15:10:00+01'),

-- 8. Zainab Mohammed: Cancelled booking due to payment switch timeout in A102
('c0000000-0000-0000-0000-000000000008', 'EKO-RES-20261016-0008',
 'a0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000002',
 '2026-10-20', '2026-10-22', 1, 85000.0000, 0.0000, 170000.0000, 21250.0000, 191250.0000,
 'CANCELLED', 'OTA_BOOKING_COM', 'Standard check-in', '2026-10-16 19:45:00+01');

-- 6. SEED: payments (Gateway & POS Settlement Records)
INSERT INTO payments (
    payment_id, payment_reference, booking_id, guest_id, payment_method,
    gateway_provider, gateway_session_id, currency, amount_paid, processing_fee,
    payment_status, narration, paid_at
)
VALUES
('d0000000-0000-0000-0000-000000000001', 'EKO-PAY-20261001-0001',
 'c0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
 'DEBIT_CARD', 'PAYSTACK', 'PSK_990182736451001', 'NGN', 258187.5000, 2000.0000,
 'COMPLETED', 'Full settlement for booking EKO-RES-20261001-0001 via Paystack Web', '2026-10-01 09:32:10+01'),

('d0000000-0000-0000-0000-000000000002', 'EKO-PAY-20261003-0002',
 'c0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002',
 'DEBIT_CARD', 'FLUTTERWAVE', 'FLW_881273645092002', 'NGN', 288562.5000, 2000.0000,
 'COMPLETED', 'Full settlement for booking EKO-RES-20261003-0002 via Flutterwave', '2026-10-03 11:18:00+01'),

('d0000000-0000-0000-0000-000000000003', 'EKO-PAY-20261010-0003',
 'c0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000003',
 'CORPORATE_INVOICE', 'NIBSS_NIP_DIRECT', 'NIP_999015261010142500000103', 'NGN', 1071000.0000, 53.7500,
 'COMPLETED', 'Corporate NIP transfer for Diplomatic Suite EKO-RES-20261010-0003', '2026-10-10 14:25:00+01'),

('d0000000-0000-0000-0000-000000000004', 'EKO-PAY-20261011-0004',
 'c0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000005',
 'POS_TERMINAL', 'MONIEPOINT_POS', 'MNP_772615438900004', 'NGN', 432843.7500, 1500.0000,
 'COMPLETED', 'Front-desk POS terminal payment for EKO-RES-20261011-0004', '2026-10-11 16:45:00+01'),

('d0000000-0000-0000-0000-000000000005', 'EKO-PAY-20261012-0005',
 'c0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000006',
 'DEBIT_CARD', 'PAYSTACK', 'PSK_990182736451005', 'NGN', 334125.0000, 2000.0000,
 'COMPLETED', 'Online card payment for Executive Twin EKO-RES-20261012-0005', '2026-10-12 10:08:00+01'),

('d0000000-0000-0000-0000-000000000006', 'EKO-PAY-20261014-0006',
 'c0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000009',
 'BANK_TRANSFER_NIP', 'NIBSS_NIP_DIRECT', 'NIP_999013261014123500000106', 'NGN', 1243125.0000, 53.7500,
 'COMPLETED', 'Presidential Penthouse settlement EKO-RES-20261014-0006', '2026-10-14 12:35:00+01'),

('d0000000-0000-0000-0000-000000000007', 'EKO-PAY-20261015-0007',
 'c0000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000012',
 'DEBIT_CARD', 'FLUTTERWAVE', 'FLW_881273645092007', 'NGN', 850500.0000, 2000.0000,
 'COMPLETED', 'Diplomatic Suite advance payment EKO-RES-20261015-0007', '2026-10-15 15:12:00+01'),

('d0000000-0000-0000-0000-000000000008', 'EKO-PAY-20261016-0008',
 'c0000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000004',
 'POS_TERMINAL', 'INTERSWITCH_POS', 'ISW_665432189000008', 'NGN', 191250.0000, 0.0000,
 'FAILED', 'Issuer bank switch timeout (Response Code 91) on booking EKO-RES-20261016-0008', '2026-10-16 19:48:00+01');

-- 7. SEED: checkin_checkout_records (Front-Desk Operational Stay Logs)
INSERT INTO checkin_checkout_records (
    record_id, booking_id, room_id, guest_id, actual_check_in_at, actual_check_out_at,
    keycard_code, deposit_held, late_checkout_fee, checked_in_by, checked_out_by,
    room_inspection_status, front_desk_notes
)
VALUES
('e0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001',
 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
 '2026-10-02 14:10:00+01', '2026-10-05 13:30:00+01',
 'KC-RFID-A101-8821', 30000.00, 0.00, 'RECEPTION_OFFICER_ADA', 'RECEPTION_OFFICER_FEMI',
 'CLEARED_NO_DAMAGE', 'Gold Ambassador 2-hour complimentary late check-out applied. Caution deposit refunded.'),

('e0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002',
 'b0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000002',
 '2026-10-04 15:00:00+01', '2026-10-06 11:45:00+01',
 'KC-RFID-B202-9914', 50000.00, 0.00, 'RECEPTION_OFFICER_FEMI', 'RECEPTION_OFFICER_ADA',
 'MINIBAR_BILLED', 'Minibar sparkling water billed to card on file; room cleared in good condition.'),

('e0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000003',
 'b0000000-0000-0000-0000-000000000011', 'a0000000-0000-0000-0000-000000000003',
 '2026-10-12 14:05:00+01', NULL,
 'KC-BLE-D402-1042', 100000.00, 0.00, 'DUTY_MANAGER_SEYI', NULL,
 'PENDING_INSPECTION', 'VIP Platinum guest currently in-house in Diplomatic Suite D402.'),

('e0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000004',
 'b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000005',
 '2026-10-13 15:20:00+01', NULL,
 'KC-BLE-B201-3319', 50000.00, 0.00, 'RECEPTION_OFFICER_ADA', NULL,
 'PENDING_INSPECTION', 'Guest checked in via mobile digital keycard.'),

('e0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000005',
 'b0000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000006',
 '2026-10-14 11:15:00+01', NULL,
 'KC-BLE-C301-7740', 50000.00, 0.00, 'RECEPTION_OFFICER_FEMI', NULL,
 'PENDING_INSPECTION', 'Early check-in granted per Gold Ambassador tier benefit.');

-- 8. SEED: audit_logs (Initial Forensic Snapshot)
INSERT INTO audit_logs (table_name, record_id, action, old_state, new_state, changed_by, client_ip)
VALUES
('rooms', 'b0000000-0000-0000-0000-000000000009', 'UPDATE',
 '{"room_number": "C303", "room_status": "AVAILABLE"}',
 '{"room_number": "C303", "room_status": "OUT_OF_ORDER", "reason": "HVAC chiller valve replacement by facility engineering"}',
 'CHIEF_ENGINEER_BODE', '197.210.64.20'),

('guests', 'a0000000-0000-0000-0000-000000000011', 'UPDATE',
 '{"guest_status": "ACTIVE"}',
 '{"guest_status": "BLACKLISTED", "reason": "Confirmed chargeback fraud and property damage during prior stay"}',
 'SECURITY_DIRECTOR_01', '197.210.64.25');
