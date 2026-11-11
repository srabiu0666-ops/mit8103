# Portfolio 4: NoSQL and Advanced Data Models

**Course:** MIT 8103 – Advanced Database Systems  
**Academic Session:** 2026/2027  
**Case Study:** EkoStay Hospitality Limited  
**Deliverable:** Polyglot Architecture, MongoDB Document Models, JSON Schema Validators, TTL & Geospatial Indexing, Aggregation Pipelines  
**Component Score Weight:** 7 Marks  
**Author:** Rabiu Sekinah (`301870666`)  

---

## 1. Executive Summary & Polyglot Architecture

In modern enterprise hospitality systems, no single database engine optimally satisfies both ACID room reservation folios and high-frequency smart-room IoT telemetry.

In this fourth portfolio milestone, I implemented **Polyglot Persistence** for EkoStay Hospitality Limited:
- **Relational Store (PostgreSQL 16):** Retains exclusive ownership of guest master identities, room inventory, date-range reservation locks, statutory tax calculations, and payment settlements.
- **Document Store (MongoDB 7.0):** Ingests high-velocity BLE/RFID smart door-lock events, HVAC climate sensor telemetry, and polymorphic guest concierge and security incident tickets.

This milestone demonstrates document data modelling, `$jsonSchema` validation, Time-To-Live (TTL) automated data retention, `2dsphere` geospatial indexing, and multi-stage aggregation pipelines.

---

## 2. Document Schema Models & Validation Rules

To prevent schema drift while preserving document flexibility, I configured `$jsonSchema` validators inside `01-mongo-schema.js` for two core collections in `ekostay_nosql`:

### 2.1 Collection: `room_iot_telemetry`
Captures smart door-lock authentication events (`BLE_MOBILE_KEY`, `RFID_KEYCARD`, `IN_ROOM_TABLET`, `REMOTE_WEB_API`), cabin environmental telemetry (`cabin_temp_celsius`, `humidity_pct`, `lock_battery_pct`), and GeoJSON property coordinates.

```json
{
  "room_number": "D402",
  "guest_id": "a0000000-0000-0000-0000-000000000011",
  "device_id": "API-BOT-LINUX-X86",
  "ip_address": "185.220.101.5",
  "event_type": "KEYCARD_TAP_DENIED",
  "access_channel": "REMOTE_WEB_API",
  "timestamp": "2026-10-18T02:12:30.000Z",
  "property_location": {
    "property_branch": "Foreign Tor Relay",
    "city": "Frankfurt",
    "state": "Hesse",
    "country": "Germany",
    "type": "Point",
    "coordinates": [8.6821, 50.1109]
  },
  "sensor_metrics": {
    "cabin_temp_celsius": 19.5,
    "humidity_pct": 46.0,
    "lock_battery_pct": 93,
    "vpn_or_proxy_detected": true
  }
}
```

### 2.2 Collection: `guest_concierge_requests`
A polymorphic document collection supporting diverse hotel operations (`SECURITY_INCIDENT`, `IN_ROOM_DINING`, `FACILITY_MAINTENANCE`, `AIRPORT_CHAUFFEUR`, `HOUSEKEEPING_TURNDOWN`). Each ticket embeds a chronological `staff_activity_log`, `resolution_actions` array, and category-specific nested sub-documents (`incident_metadata`, `dining_order_details`, or `engineering_diagnostics`).

```json
{
  "ticket_id": "TKT-2026-OCT-001",
  "booking_reference": "EKO-RES-20261010-0003",
  "room_number": "D402",
  "guest_id": "a0000000-0000-0000-0000-000000000011",
  "request_category": "SECURITY_INCIDENT",
  "priority_score": 96,
  "ticket_status": "ESCALATED_TO_SECURITY",
  "resolution_actions": ["KEYCARD_TOKEN_REVOKE", "GUEST_PROFILE_BLACKLIST", "FIREWALL_IP_BLOCK"],
  "staff_activity_log": [
    {
      "staff_id": "SECURITY_CHIEF_BALOGUN",
      "note": "Smart lock gateway blocked cloned RFID tap on C303 followed by remote API unlock replay from Frankfurt Tor IP 185.220.101.5.",
      "timestamp": "2026-10-18T02:15:00.000Z"
    }
  ]
}
```

---

## 3. Advanced Indexing Strategies in MongoDB

I implemented three specialized index types in `01-mongo-schema.js`:

1. **Compound Index (`{ room_number: 1, timestamp: -1 }`):**  
   Accelerates real-time security and facility lookups for a specific room's recent smart-lock and HVAC sensor history.
2. **2dsphere Geospatial Index (`{ "property_location.coordinates": "2dsphere" }`):**  
   Enables spatial proximity and impossible-travel calculations on RFC 7946 GeoJSON `Point` coordinates (`[longitude, latitude]`), verifying whether a mobile digital-key unlock request originated inside the hotel geofence.
3. **Time-To-Live (TTL) Index (`{ timestamp: 1 }` with `expireAfterSeconds: 7776000`):**  
   Automatically purges raw room IoT and access telemetry documents after 90 days, enforcing Nigeria Data Protection Regulation (NDPR) storage minimization without cron-job delete scripts.

---

## 4. Aggregation Pipelines & Empirical Results

In `03-mongo-queries.js`, I executed four multi-stage aggregation pipelines (`evidence/mongo-aggregation-output.log`):

### 4.1 Pipeline 1: Smart-Lock Security & Foreign Access Surveillance
- **Objective:** Filter smart-lock events where `vpn_or_proxy_detected: true`, `country != 'Nigeria'`, or `event_type == 'KEYCARD_TAP_DENIED'`.
- **Empirical Finding:** Immediately isolated blacklisted guest Kunle Coker (`a0000000-...-0011`) attempting a physical cloned RFID tap on Room `C303` in Lagos (`02:00:00Z`) followed 12 minutes later by remote web API unlock replay attacks on Diplomatic Suite `D402` and Presidential Penthouse `E501` from a Frankfurt Tor exit node (`185.220.101.5`).

### 4.2 Pipeline 2: Guest Device & Room Access Velocity
- **Objective:** Group telemetry by `guest_id` using `$addToSet` to count distinct rooms targeted, devices used, access channels, and average cabin temperature.
- **Empirical Finding:** Flagged guest `a0000000-...-0011` targeting **3 distinct rooms (`C303`, `D402`, `E501`)** across two cities (`Lagos`, `Frankfurt`), whereas legitimate in-house guests accessed only their single assigned room (`rooms_count: 1`).

### 4.3 Pipeline 3: Concierge & Security Resolution Action Breakdown (`$unwind`)
- **Objective:** Deconstruct the `resolution_actions` array across incident tickets using `$unwind` to rank operational actions by priority score and frequency.
- **Empirical Finding:** Confirmed security escalations (`KEYCARD_TOKEN_REVOKE`, `GUEST_PROFILE_BLACKLIST`, `FIREWALL_IP_BLOCK`) carried the highest priority score (`96`), followed by engineering maintenance (`ROOM_MARKED_OUT_OF_ORDER`, `HVAC_VALVE_ORDERED` on `C303` at `85`) and VIP butler dining (`65`).

### 4.4 Pipeline 4: Multi-Faceted Smart Hotel Operations Dashboard (`$facet`)
- **Objective:** Execute three parallel aggregations in a single collection scan using `$facet`.
- **Empirical Finding:** Summarized access channel distribution (`RFID_KEYCARD`: 2, `BLE_MOBILE_KEY`: 2, `IN_ROOM_TABLET`: 2, `REMOTE_WEB_API`: 2), event types (`DIGITAL_KEY_UNLOCK`: 3, `KEYCARD_TAP_DENIED`: 3, `DO_NOT_DISTURB_TOGGLE`: 1, `HVAC_SETPOINT_CHANGE`: 1), and total VPN attempts (`2`).

---

## 5. Architectural Suitability & Polyglot Trade-Offs

A complete comparative evaluation between PostgreSQL 16 and MongoDB 7.0 is provided in [`04-relational-vs-nosql-comparison.md`](04-relational-vs-nosql-comparison.md).

---

## 6. How to Execute the Portfolio 4 Test Suite

The MongoDB 7.0 instance is configured in `docker-compose.yml` on host port **`27020`**:

```bash
# 1. Ensure the MongoDB 7.0 container is running
docker compose up -d ekostay-mongo

# 2. Deploy collections, $jsonSchema validators, and TTL/2dsphere indexes
docker compose exec -T ekostay-mongo mongosh --quiet -u ekostay_mongo -p EkoStayMongo2026! --authenticationDatabase admin ekostay_nosql /portfolio-4/01-mongo-schema.js

# 3. Seed smart-room IoT telemetry and polymorphic concierge tickets
docker compose exec -T ekostay-mongo mongosh --quiet -u ekostay_mongo -p EkoStayMongo2026! --authenticationDatabase admin ekostay_nosql /portfolio-4/02-mongo-seed.js

# 4. Execute the 4 aggregation pipelines
docker compose exec -T ekostay-mongo mongosh --quiet -u ekostay_mongo -p EkoStayMongo2026! --authenticationDatabase admin ekostay_nosql /portfolio-4/03-mongo-queries.js
```

---

## 7. Technical Reflection & Practical Debugging Log

### 7.1 Key Engineering Insights
- **Avoiding Unbounded Embedded Arrays:**  
  Instead of embedding every smart-lock tap and HVAC temperature reading inside a single room document in MongoDB (which would grow indefinitely and risk hitting MongoDB's 16MB BSON document limit), I modeled `room_iot_telemetry` as one document per event paired with a compound index `{ room_number: 1, timestamp: -1 }` and a 90-day TTL index. Conversely, `staff_activity_log` and `resolution_actions` are bounded (typically 2–10 entries per concierge ticket), making them ideal for embedding inside `guest_concierge_requests`.

### 7.2 Practical Bug Encountered & Resolved (`mongosh` Number Type Coercion)
When running `02-mongo-seed.js` against `01-mongo-schema.js` inside the `ekostay-mongo` container, MongoDB initially rejected the seed batch with:
```text
MongoBulkWriteError: Document failed validation
```
**Investigation:**  
Inspecting the validator specification revealed that `cabin_temp_celsius` and `humidity_pct` were restricted to `bsonType: 'double'`. In JavaScript / `mongosh`, whole-number float literals such as `48.0`, `22.0`, and `21.0` have no fractional part and are serialized by the BSON driver as 32-bit integers (`int`) rather than 64-bit IEEE-754 floats (`double`), causing strict `bsonType: 'double'` validation to fail.  
**Resolution:**  
I updated the numeric sensor and coordinate validators in `01-mongo-schema.js` to accept `bsonType: ['double', 'int', 'decimal']`, re-executed the seed script in Docker, and confirmed all 8 IoT telemetry documents and 3 concierge tickets inserted cleanly.

---

## 8. Academic Integrity and AI Use Declaration

*(In accordance with Section 11 of the Continuous Assessment Syllabus)*

1. **AI Tools Used:** Claude / AI Programming Assistant
2. **Specific Tasks Where AI Was Used:**
   - Diagnosing BSON integer-vs-double serialization in `mongosh` for `$jsonSchema` validation (`bsonType: ['double', 'int', 'decimal']`).
   - Formatting aggregation pipeline outputs into technical documentation.
3. **Student Verification & Ownership:**
   - I designed the hospitality polyglot persistence model (`room_iot_telemetry` and `guest_concierge_requests`), GeoJSON property coordinates, and the 4 aggregation pipelines.
   - I executed and verified all scripts inside the live MongoDB 7.0 Docker container.
