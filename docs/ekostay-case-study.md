# EkoStay Hospitality Group Case Study Specification

**Document Version:** 1.0  
**Course:** MIT 8103 – Advanced Database Systems  
**Institution:** MIVA Open University  
**Case Study Title:** EkoStay Hospitality Limited – Enterprise Hotel Reservation, Property Management & Smart Room Telemetry Database System  

---

## 1. Executive Summary & Organisation Profile

**EkoStay Hospitality Limited** is an enterprise hotel chain and hospitality management organisation operating luxury and business properties across Nigeria's major commercial corridors—Lagos (Victoria Island and Ikeja), Abuja (Maitama), and Port Harcourt (GRA). Modeled on high-occupancy Nigerian hospitality operations such as Eko Hotels & Suites, Transcorp Hilton, and Marriott Lagos, EkoStay manages room inventory, online and walk-in reservations, loyalty tier programs, payment settlements, front-desk check-in/check-out records, and smart-room IoT housekeeping telemetry.

To prevent double-booking across distribution channels (Direct Mobile App, Web Portal, Corporate Travel Desks, and Online Travel Agencies), enforce statutory Nigerian taxes (7.5% Value Added Tax and 5% State Hospitality Consumption Tax), and comply with National Identity Management Commission (NIMC) and Nigeria Immigration Service (NIS) guest registration mandates, EkoStay requires an enterprise-grade database architecture guaranteeing strict ACID transactional integrity, low-latency analytical processing, and multi-region high availability.

---

## 2. Nature of Business and System Architecture

EkoStay operates a unified Central Reservation System (CRS) and Property Management System (PMS). The database layer serves as the single source of truth for:
- **Room Inventory & Rate Management:** Managing physical room units across floors and wings, standardized room categories, max occupancy rules, and base nightly tariffs.
- **Reservation & Folio Engine:** Processing room bookings, date-range availability validation, loyalty tier discounts, statutory tax computation, and guest folio balances.
- **Payment Settlement & Channel Reconciliation:** Recording multi-channel payment transactions (Paystack, Flutterwave, Interswitch POS, Corporate Bank Transfers) with settlement references and refund tracking.
- **Front-Desk & Housekeeping Operations:** Tracking digital keycard issuance, physical check-in/check-out timestamps, security deposit holds, and room operational statuses (`AVAILABLE`, `OCCUPIED`, `DIRTY_CLEANING`, `OUT_OF_ORDER`).
- **Smart Room IoT & Concierge Telemetry:** Ingesting high-frequency BLE/NFC smart-lock access logs, HVAC/energy sensor readings, and polymorphic guest service/concierge tickets in MongoDB.

---

## 3. Database Users and Actors

The database supports both human actors and automated hospitality services:

1. **Hotel Guests (Individual & Corporate Travelers):**
   - Search room availability by check-in/check-out dates and room category, place reservations, make online payments, and request digital keycards or concierge services.
2. **Front-Desk Receptionists & Duty Managers:**
   - Verify guest NIN/Passport identity hashes, execute room check-ins and check-outs, process POS folio settlements, and handle room upgrades or late check-out extensions.
3. **Housekeeping & Facility Engineers:**
   - Receive real-time room turnover queues (`DIRTY_CLEANING` to `AVAILABLE`), log maintenance incidents, and place rooms under `OUT_OF_ORDER` status when engineering repairs are required.
4. **Revenue & Finance Auditors:**
   - Reconcile daily payment gateway settlements, audit failed or refunded booking transactions, monitor RevPAR (Revenue Per Available Room) and ADR (Average Daily Rate), and verify VAT/Consumption Tax remittances.
5. **System Backend Services & DBAs:**
   - Execute Night Audit batch jobs, partition maintenance, smart-room IoT stream ingestion, and read-write query routing across regional database nodes.

---

## 4. Major Data to be Stored

| Data Category | Key Attributes | Storage Requirements |
| :--- | :--- | :--- |
| **Loyalty Tiers** | `tier_level`, `tier_name`, `min_nights_required`, `discount_percentage`, `late_checkout_hours`, `max_active_bookings` | Reference lookup table governing guest loyalty privileges and booking ceilings. |
| **Guest Master Data** | `guest_id`, `first_name`, `last_name`, `email`, `phone_number`, `nin_hash`, `passport_hash`, `nationality`, `loyalty_tier`, `guest_status` | Salted SHA-256 identity hashes (NDPR compliance); strict uniqueness on email, phone, and identity tokens. |
| **Room Categories** | `category_id`, `category_code`, `category_name`, `base_nightly_rate`, `max_occupancy`, `bed_configuration`, `square_meters` | Standardized tariff schedule in NGN (`NUMERIC(15, 2)`); positive rate constraints. |
| **Rooms Inventory** | `room_id`, `room_number`, `category_id`, `floor_number`, `wing`, `room_status`, `is_smoking` | Unique 4-char room number format (`^[A-Z][0-9]{3}$`, e.g., `A101`, `B304`); operational status enforcement. |
| **Bookings (Reservations)** | `booking_id`, `booking_reference`, `guest_id`, `room_id`, `check_in_date`, `check_out_date`, `num_guests`, `nightly_rate_applied`, `subtotal_amount`, `tax_amount`, `total_amount`, `booking_status`, `booking_channel` | Date range validation (`check_out_date > check_in_date`); non-negative monetary amounts (`NUMERIC(18, 4)`). |
| **Payments** | `payment_id`, `booking_id`, `payment_reference`, `payment_method`, `gateway_provider`, `gateway_session_id`, `amount_paid`, `processing_fee`, `payment_status`, `paid_at` | Traceability across Nigerian payment gateways (Paystack, Flutterwave, Interswitch POS); unique settlement references. |
| **Check-In/Out Records** | `record_id`, `booking_id`, `room_id`, `guest_id`, `actual_check_in_at`, `actual_check_out_at`, `keycard_code`, `deposit_held`, `late_checkout_fee`, `checked_in_by`, `inspection_status` | 1:1 operational stay log linked to confirmed bookings; tracks physical occupancy and security deposits. |
| **Audit Logs** | `log_id`, `table_name`, `record_id`, `action`, `old_state`, `new_state`, `changed_by`, `client_ip`, `created_at` | Trigger-driven JSONB change-data-capture (CDC) for room status and reservation mutations. |

---

## 5. Key Operations Supported by the Database

1. **Guest Registration & Loyalty Tier Classification:**
   - Register guest profiles with E.164 Nigerian phone validation (`+234...`) and SHA-256 hashed NIN/Passport numbers.
   - Apply loyalty tier discounts and active booking limits automatically based on the guest's `loyalty_tier`.
2. **Atomic Room Reservation & Payment Settlement:**
   - Verify room operational status (`room_status <> 'OUT_OF_ORDER'`) and check for overlapping date ranges (`[check_in_date, check_out_date)`).
   - Atomically insert the booking record, compute 12.5% statutory hospitality taxes (7.5% VAT + 5% Consumption Tax), record the payment transaction, and lock the room against concurrent double-booking.
3. **Front-Desk Check-In & Check-Out Lifecycle:**
   - Transition room status to `OCCUPIED` upon guest arrival, issue a digital keycard code, and hold a refundable security deposit.
   - Transition room status to `DIRTY_CLEANING` upon check-out and compute any applicable late check-out fees.
4. **Operational Room Maintenance Enforcement:**
   - Prevent new reservations or check-ins on rooms marked `OUT_OF_ORDER` via database triggers while permitting historical folio queries.
5. **Hospitality Revenue Analytics & Night Audit:**
   - Compute running revenue per room using SQL Window functions, audit payment gateway exceptions (`FAILED`/`REFUNDED`), and rank corporate/VIP guest spend.
6. **Immutable Forensic Auditing:**
   - Automatically capture JSONB `old_state` and `new_state` snapshots in `audit_logs` whenever room statuses or booking totals are modified.

---

## 6. Alignment Across Portfolio Activities

| Milestone | Application to EkoStay Hospitality Case Study |
| :--- | :--- |
| **Portfolio 1: Database Design & Modelling** | Design normalized 8-table relational schema (UNF to BCNF) for EkoStay CRS/PMS, ER diagram, strict domain constraints, operational triggers, and realistic Nigerian hospitality seed data. |
| **Portfolio 2: Query Processing & Optimisation** | Scale dataset to 15,008 bookings and 15,008 payments; execute 5 hospitality analytical queries with `EXPLAIN (ANALYZE, BUFFERS)`, and engineer partial, composite, and covering (`INCLUDE`) indexes. |
| **Portfolio 3: Transactions & Concurrency** | Implement ACID stored procedure `sp_create_room_reservation` with deterministic lock ordering, test commit/rollback/savepoints, prevent concurrent double-booking (`SELECT ... FOR UPDATE`), and resolve deadlocks during multi-room group bookings. |
| **Portfolio 4: NoSQL & Advanced Data Models** | Implement polyglot persistence with MongoDB 7.0 (`room_iot_telemetry` and `guest_concierge_requests`) featuring `$jsonSchema` validation, `2dsphere` spatial indexing, 90-day TTL expiration, and 4 aggregation pipelines. |
| **Portfolio 5: Distributed & Cloud Systems** | Partition `bookings_partitioned` by monthly check-in ranges, shard `rooms_sharded` across 4 hash nodes, configure logical replication and read-write query routing, and verify CAP/PACELC consistency and failover. |
| **Final Documentation** | Deliver comprehensive synthesis report, architectural trade-off evaluation, practical debugging logs, and academic integrity / AI use declaration. |
