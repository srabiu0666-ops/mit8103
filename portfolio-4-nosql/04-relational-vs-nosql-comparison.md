# Relational (PostgreSQL) vs Document (MongoDB) Architecture Matrix

**Case Study:** EkoStay Hospitality Limited  
**Author:** Rabiu Sekinah (`301870666`)  
**Context:** MIT 8103 Advanced Database Systems – Portfolio 4  

---

## 1. Architectural Comparison Matrix

| Architectural Dimension | Relational Store: PostgreSQL 16 | Document Store: MongoDB 7.0 |
| :--- | :--- | :--- |
| **Primary Domain in EkoStay** | Core Reservation & Folio System (`guests`, `rooms`, `bookings`, `payments`, `checkin_checkout_records`) | Smart Room IoT Telemetry (`room_iot_telemetry`) & Polymorphic Concierge/Incident Tickets (`guest_concierge_requests`) |
| **Data Model Paradigm** | Tabular, strictly typed, normalized to Boyce-Codd Normal Form (BCNF) | Hierarchical, semi-structured BSON documents with `$jsonSchema` validation |
| **Integrity & Constraints** | Foreign Keys (`ON DELETE RESTRICT`), CHECK constraints, date-overlap triggers, room format regex | JSON Schema `$jsonSchema` document validators, enum checks, GeoJSON coordinate rules |
| **Consistency Guarantees** | Immediate consistency; full ACID compliance under pessimistic row locks (`FOR UPDATE`) | Tunable consistency (WiredTiger journaled writes; configurable write/read concerns) |
| **CAP Theorem Positioning** | **CP System:** Prioritizes strict Consistency to prevent double-booking and payment loss | **CP/AP Configurable:** Tunable via `w: "majority"` vs `w: 1` and `readPreference: "secondaryPreferred"` |
| **Transaction Boundaries** | Multi-table atomic transactions via PL/pgSQL procedures (`sp_create_room_reservation`) | Single-document atomic updates for nested `staff_activity_log` and `resolution_actions` arrays |
| **Schema Evolution** | Structured DDL migrations (`ALTER TABLE`); uniform columns across all tuples | Polymorphic documents: dining orders, HVAC diagnostics, and security incidents coexist without NULL bloat |
| **Query Engine** | Declarative SQL, Window Functions (`SUM() OVER`), CTEs, cost-based join optimizer | Multi-stage Aggregation Pipelines (`$match`, `$group`, `$unwind`, `$facet`), `2dsphere` spatial queries |
| **Storage Optimization** | B-Tree composite indexes, partial indexes, and covering indexes with `INCLUDE` | Compound B-Tree indexes, `2dsphere` geospatial indexes, and TTL auto-expiring indexes |
| **Lifecycle Management** | Long-term financial retention required by FIRS and hospitality tax regulations | Automated 90-day raw telemetry purging via Time-To-Live (TTL) index (`expireAfterSeconds: 7776000`) |

---

## 2. In-Depth Trade-Off Analysis for EkoStay Hospitality

### 2.1 Why Not Store Room Reservations & Folios in MongoDB?
Storing room inventory, booking date ranges, and financial folio settlements directly in a NoSQL document store introduces severe operational risks for a hotel chain:
1. **Concurrent Double-Booking Vulnerability:** Preventing two guests from booking Room `E502` for overlapping dates requires locking the target room row and evaluating range predicates (`check_in_date < new_checkout AND check_out_date > new_checkin`) inside an ACID transaction. PostgreSQL handles this natively with `SELECT ... FOR UPDATE` and relational triggers.
2. **Statutory Tax & Folio Precision:** Hospitality invoices must reconcile base tariffs, loyalty tier discounts (`0%–15%`), and 12.5% Nigerian VAT + Consumption Tax to four decimal places (`NUMERIC(18, 4)`) across `bookings` and `payments`.

### 2.2 Why Not Store Smart-Room IoT Telemetry & Concierge Tickets in PostgreSQL?
Conversely, forcing high-frequency smart-room sensor streams and diverse guest service requests into normalized relational tables creates three distinct bottlenecks:
1. **Write Amplification & Heap Bloat:** Every hotel room equipped with BLE smart locks, wall tablets, and HVAC climate sensors emits dozens of events per hour. Inserting millions of transient sensor rows into PostgreSQL causes continuous B-Tree index page splits and `VACUUM` overhead.
2. **Polymorphic Concierge Payload Rigidity:** Guest service tickets vary wildly in structure:
   - An `IN_ROOM_DINING` ticket contains an array of menu items, quantities, dietary allergies, and cutlery counts (`dining_order_details`).
   - A `FACILITY_MAINTENANCE` ticket contains Daikin HVAC serial numbers, target vs measured temperatures, and repair hour estimates (`engineering_diagnostics`).
   - A `SECURITY_INCIDENT` ticket contains flagged Tor IP addresses, attack vectors, and security patrol dispatch flags (`incident_metadata`).
   In PostgreSQL, representing these in a single table requires dozens of sparse NULL columns or complex Entity-Attribute-Value (EAV) joins. In MongoDB, each ticket is stored naturally as a self-contained polymorphic document while still enforcing common header fields via `$jsonSchema`.
3. **Automated 90-Day NDPR Data Retention:** Under the Nigeria Data Protection Regulation (NDPR), raw guest door-lock and location telemetry should expire after 90 days. MongoDB's native TTL index (`expireAfterSeconds: 7776000`) purges expired documents automatically in the background without locking active tables.

---

## 3. Polyglot Persistence Architecture in EkoStay

By combining PostgreSQL 16 and MongoDB 7.0, EkoStay implements a **Polyglot Persistence** architecture:
- **System of Record (PostgreSQL 16):** Owns guest identities, room tariffs, reservation date allocations, payment settlements, and front-desk check-in/out records.
- **System of Telemetry & Concierge Operations (MongoDB 7.0):** Ingests BLE/RFID smart-lock events, HVAC telemetry, and polymorphic guest concierge/security workflows, cross-referenced via `room_number`, `guest_id`, and `booking_reference`.
