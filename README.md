# Advanced Database Systems Portfolio: EkoStay Hospitality
**Course Code:** MIT 8103 – Advanced Database Systems  
**Programme:** Master of Information Technology (SPGS), MIVA Open University  
**Academic Session:** 2026/2027 – First Semester Continuous Assessment  
**Student Name:** Rabiu Sekinah  
**Student ID:** 301870666  
**Student Email:** s.rabiu0666@miva.edu.ng  
**GitHub Repository:** https://github.com/srabiu0666-ops/mit8103  
**Case Study Domain:** EkoStay Hospitality Limited (Hotel Reservation, Property Management & Smart Room Telemetry System)  

---

## 1. Executive Summary & Case Study Overview

**EkoStay Hospitality Limited** is an enterprise hotel chain and hospitality management organisation operating luxury and business properties across Nigeria's major commercial hubs—Lagos (Victoria Island and Ikeja), Abuja (Maitama), and Port Harcourt (GRA)—modeled on high-occupancy Nigerian hospitality operators such as Eko Hotels & Suites, Transcorp Hilton, and Marriott Lagos. EkoStay manages physical room inventory, multi-channel reservations (Direct Mobile App, Web Portal, Corporate Travel Desks, Walk-In, and OTAs like Booking.com), loyalty tier benefits, payment gateway settlements, front-desk check-in/check-out records, and smart-room IoT housekeeping and security telemetry.

Per **Section 2 of the Assessment Guidelines**, the EkoStay Hospitality case study is used consistently across all five portfolio milestones:
- **Nature of the Business / System:** Central Reservation System (CRS), Property Management System (PMS), multi-gateway folio payment ledger, front-desk check-in/out engine, and smart-room IoT telemetry platform.
- **Database Users & Actors:** Individual and corporate hotel guests, front-desk receptionists and duty managers, housekeeping and facility engineering staff, finance and Night Audit reconciliation officers, and automated backend reservation/IoT services.
- **Major Data Stored:** Guest loyalty tiers (`loyalty_tiers`), verified guest profiles with SHA-256 hashed NIN and International Passport numbers (`guests`), standardized room tariff categories (`room_categories`), physical hotel rooms (`rooms`), reservation folios (`bookings`), gateway payments (`payments`), front-desk stay records (`checkin_checkout_records`), JSONB trigger-driven audit logs (`audit_logs`), and MongoDB smart-room IoT telemetry (`room_iot_telemetry`) and polymorphic concierge/security tickets (`guest_concierge_requests`).
- **Key Operations Supported:** Guest onboarding and loyalty tier classification, atomic room reservation and payment settlement with 12.5% statutory Nigerian hospitality taxes (7.5% VAT + 5% Consumption Tax), `OUT_OF_ORDER` maintenance room blocking, window-function room revenue statements, real-time smart-lock anomaly detection, and multi-region partitioned query routing.

---

## 2. Portfolio Structure & Repository Map

Following the course syllabus, the repository is organized into five progressive portfolio directories plus comprehensive architectural and LMS submission documentation:

```text
hotel-reservation-portfolio/
├── docs/
│   ├── ekostay-case-study.md                # Detailed hospitality domain, entity dictionary & workflows
│   └── final-ca-submission-documentation.md # LMS synthesis report, reflection & references
├── portfolio-1-database-design/
│   ├── 01-schema.sql                        # Core DDL, types, constraints, 8 relational tables
│   ├── 02-constraints.sql                   # Hospitality rules, triggers, audit capture & FK indexes
│   ├── 03-seed-data.sql                     # Realistic Nigerian hospitality baseline dataset
│   ├── 04-verification-tests.sql            # Schema validation & negative integrity assertions
│   ├── er-diagram.mermaid                   # Entity-Relationship diagram source
│   ├── er-diagram.png                       # Visual ER diagram export (raster)
│   ├── er-diagram.svg                       # Visual ER diagram export (vector)
│   ├── evidence/
│   │   └── verification-test-output.log     # Captured psql verification output
│   └── README.md                            # Technical report: Normalisation (UNF to BCNF)
├── portfolio-2-query-optimisation/
│   ├── 01-data-generator.sql                # Procedural generator (15,008 bookings, 15,008 payments)
│   ├── 02-unoptimized-queries.sql           # 5 hospitality analytical queries with baseline EXPLAIN
│   ├── 03-optimization-indexes.sql          # Partial, composite, and covering (INCLUDE) indexes
│   ├── 04-optimized-queries.sql             # Post-index EXPLAIN (ANALYZE, BUFFERS) execution
│   ├── evidence/
│   │   ├── 01-baseline-explain-plans.log    # Unoptimized execution plans
│   │   └── 02-optimized-explain-plans.log   # Post-index execution plans (up to 20.1x speedup)
│   └── README.md                            # Technical report: Benchmark analysis & planner internals
├── portfolio-3-transactions-concurrency/
│   ├── 01-room-reservation-procedure.sql    # ACID room reservation & group booking procedures
│   ├── 02-commit-rollback-tests.sql         # Positive/negative atomicity & savepoint tests
│   ├── 03-concurrency-control.sql           # Double-booking prevention & OCC housekeeping tests
│   ├── 04-isolation-levels.sql              # MVCC, non-repeatable reads, snapshot analysis
│   ├── 05-deadlock-handling.sql             # Multi-room deadlock prevention via lock ordering
│   ├── evidence/
│   │   ├── 01-commit-rollback-output.log    # Atomic commit/rollback & savepoint evidence
│   │   ├── 02-concurrency-control-output.log# Row lock serialization & OCC conflict logs
│   │   ├── 03-isolation-levels-output.log   # Isolation level verification output
│   │   └── 04-deadlock-handling-output.log  # Deterministic lock acquisition evidence
│   └── README.md                            # Technical report: Concurrency, ACID & lock graphs
├── portfolio-4-nosql/
│   ├── 01-mongo-schema.js                   # Collections with $jsonSchema, 2dsphere & TTL indexes
│   ├── 02-mongo-seed.js                     # Smart room IoT telemetry & polymorphic concierge tickets
│   ├── 03-mongo-queries.js                  # Aggregation pipelines (smart lock security, velocity, $facet)
│   ├── 04-relational-vs-nosql-comparison.md # Architectural trade-off evaluation matrix
│   ├── evidence/
│   │   └── mongo-aggregation-output.log     # Captured mongosh pipeline execution output
│   └── README.md                            # Technical report: Polyglot persistence & document models
├── portfolio-5-distributed-cloud/
│   ├── 01-table-partitioning-sharding.sql   # Monthly Range Partitioning & 4-way Hash Sharding
│   ├── 02-replication-read-write-split.sql  # Logical publication, WAL LSN & Read/Write router
│   ├── 03-distributed-cap-pacelc-verification.sql # Tunable sync commit, idempotency & failover
│   ├── 04-cloud-ha-disaster-recovery.md     # Multi-region AWS Lagos/Abuja/Dublin HA/DR blueprint
│   ├── evidence/
│   │   ├── 01-partition-pruning-output.log  # Partition pruning EXPLAIN (ANALYZE, BUFFERS) output
│   │   ├── 02-replication-routing-output.log# Replication topology & query routing output
│   │   └── 03-distributed-consistency-output.log # PACELC, idempotency & failover promotion logs
│   └── README.md                            # Technical report: Distributed databases & cloud DR
├── docker-compose.yml                       # Reproducible PostgreSQL 16 & MongoDB 7.0 stack
└── README.md                                # Portfolio master guide
```

---

## 3. Core Domain Capabilities & Operations Supported

| Functional Domain | Underlying Database Operations | Key Entities Involved |
| :--- | :--- | :--- |
| **Guest Identity & Loyalty** | Registration, NIN/Passport SHA-256 hashing, Loyalty Tier perks (Tier 1–4) | `guests`, `loyalty_tiers` |
| **Room Inventory & Tariffs** | 4-char room code validation (`^[A-Z][0-9]{3}$`), capacity caps, `OUT_OF_ORDER` enforcement | `rooms`, `room_categories`, `rooms_sharded` |
| **Reservations & Payments** | Atomic date-overlap checks, 12.5% tax calculation, Paystack/Flutterwave/NIP settlements | `bookings`, `payments` |
| **Front-Desk Stay Lifecycle** | RFID/BLE keycard assignment, caution deposit holds, inspection status tracking | `checkin_checkout_records` |
| **Audit Trails & Security** | Trigger-captured JSONB `old_state`/`new_state` snapshots, 90-day TTL IoT logs | `audit_logs`, `room_iot_telemetry` |
| **Smart Room & Concierge** | GeoJSON spatial checks, Tor/VPN key-unlock alerts, polymorphic service tickets | `room_iot_telemetry`, `guest_concierge_requests` |
| **Distributed Scaling & DR** | Monthly partition pruning, 4-node hash sharding, read-write query routing | `bookings_partitioned`, `distributed_cluster_nodes` |

---

## 4. Assessment Component Breakdown & Summary of Evidence

| Milestone | Component Title | Weight | Status | Key Empirical Deliverable |
| :--- | :--- | :---: | :---: | :--- |
| **Portfolio 1** | [Database Design and Modelling](portfolio-1-database-design/README.md) | 7 Marks | **Completed** | 8 BCNF tables, ER diagram, room/date/phone checks, JSONB audit trigger, negative constraint suite |
| **Portfolio 2** | [Query Processing and Optimisation](portfolio-2-query-optimisation/README.md) | 7 Marks | **Completed** | Scaled to 15,008 bookings & payments; partial/covering indexes delivered up to **20.1x speedup & 98.2% I/O reduction** |
| **Portfolio 3** | [Transactions and Concurrency](portfolio-3-transactions-concurrency/README.md) | 7 Marks | **Completed** | `sp_create_room_reservation`, savepoint rollbacks, `SELECT FOR UPDATE` double-booking prevention, deadlock elimination |
| **Portfolio 4** | [NoSQL and Advanced Data Models](portfolio-4-nosql/README.md) | 7 Marks | **Completed** | MongoDB 7.0 `$jsonSchema`, `2dsphere` & 90-day TTL indexes, 4 smart-room & concierge aggregation pipelines |
| **Portfolio 5** | [Distributed and Cloud Database Exercise](portfolio-5-distributed-cloud/README.md) | 6 Marks | **Completed** | Monthly range partitioning (**85.0% I/O pruning**), 4-way hash sharding, read/write router, Patroni HA/DR ($\text{RPO}=0$) |
| **Final Documentation** | [Portfolio Documentation & Technical Reflection](docs/final-ca-submission-documentation.md) | 6 Marks | **Completed** | Comprehensive LMS synthesis document, architectural trade-offs, debugging logs & AI declaration |
| **Total** | | **40 Marks** | **100% Complete** | |

---

## 5. Technology Stack & Environment
- **Relational DBMS:** PostgreSQL 16 (`postgres:16-alpine` – strict constraints, PL/pgSQL procedures, declarative partitioning, `EXPLAIN (ANALYZE, BUFFERS)`)
- **NoSQL Document Store:** MongoDB 7.0 (`mongo:7.0` – `$jsonSchema` validation, GeoJSON `2dsphere` spatial indexing, TTL expiration, aggregation pipelines)
- **Modelling & Tooling:** Mermaid.js, `psql`, `mongosh`, Docker Compose v2, Git / GitHub

---

## 6. Quick Start & End-to-End Reproduction (Docker Environment)

The repository provides a self-contained `docker-compose.yml` that provisions PostgreSQL 16 (automatically initializing Portfolio 1's schema, constraints, and seed dataset on startup) and MongoDB 7.0:

```bash
# 1. Start PostgreSQL 16 and MongoDB 7.0 containers
docker compose up -d

# 2. Portfolio 1: Run relational integrity and constraint verification tests
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-1/04-verification-tests.sql

# 3. Portfolio 2: Generate 15,000+ records, apply optimization indexes, and benchmark queries
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-2/01-data-generator.sql
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-2/03-optimization-indexes.sql
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-2/04-optimized-queries.sql

# 4. Portfolio 3: Compile atomic reservation procedures and run ACID / concurrency / deadlock suite
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-3/01-room-reservation-procedure.sql
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-3/02-commit-rollback-tests.sql
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-3/03-concurrency-control.sql
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-3/05-deadlock-handling.sql

# 5. Portfolio 4: Provision MongoDB schemas, seed IoT telemetry, and execute aggregation pipelines
docker compose exec -T ekostay-mongo mongosh -u ekostay_mongo -p EkoStayMongo2026! --authenticationDatabase admin ekostay_nosql /portfolio-4/01-mongo-schema.js
docker compose exec -T ekostay-mongo mongosh -u ekostay_mongo -p EkoStayMongo2026! --authenticationDatabase admin ekostay_nosql /portfolio-4/02-mongo-seed.js
docker compose exec -T ekostay-mongo mongosh -u ekostay_mongo -p EkoStayMongo2026! --authenticationDatabase admin ekostay_nosql /portfolio-4/03-mongo-queries.js

# 6. Portfolio 5: Execute partitioning, sharding, read-write routing, and CAP/PACELC failover suite
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-5/01-table-partitioning-sharding.sql
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-5/02-replication-read-write-split.sql
docker compose exec -T ekostay-postgres psql -U ekostay_admin -d ekostay_db -f /portfolio-5/03-distributed-cap-pacelc-verification.sql
```

### Database Connection Credentials
| Service | Host | Host Port | Container Port | Database | Username | Password |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- |
| **PostgreSQL 16** | `localhost` | `5436` | `5432` | `ekostay_db` | `ekostay_admin` | `EkoStaySecure2026!` |
| **MongoDB 7.0** | `localhost` | `27020` | `27017` | `ekostay_nosql` | `ekostay_mongo` | `EkoStayMongo2026!` |

---

## 7. Academic Integrity, References & AI Use Declaration

*(Submitted in compliance with Sections 11 and 12 of the MIT 8103 Continuous Assessment Guidelines)*

### 7.1 AI Use Declaration
1. **AI Tools Used:** Claude / AI Programming Assistant
2. **What the AI Tool Was Used For:**
   - Reviewing PostgreSQL 16 PL/pgSQL syntax edge cases (`FOR UPDATE OF r` on joined tables, composite primary keys on declaratively partitioned tables, and `pg_inherits` catalog inspection).
   - Reviewing MongoDB `$jsonSchema` BSON numeric type rules and formatting `EXPLAIN (ANALYZE, BUFFERS)` output into Markdown tables.
3. **How Output Was Reviewed, Corrected, Tested, and Verified:**
   - All domain modelling, Nigerian hospitality business rules (loyalty tier discounts and active booking limits, 12.5% VAT + State Consumption Tax calculation, `OUT_OF_ORDER` maintenance room triggers, and keycard check-in/out tracking), and normalization proofs were designed by me.
   - Every SQL and JavaScript script was executed and verified against live PostgreSQL 16 and MongoDB 7.0 Docker containers.
   - I diagnosed and fixed multiple implementation issues during live container testing (including serial sequence synchronization in Portfolio 1, Visibility Map `VACUUM ANALYZE` refresh for Index-Only Scans in Portfolio 2, scoped `FOR UPDATE OF r` locking in Portfolio 3, `mongosh` BSON int/double coercion in Portfolio 4, and qualified `rs.tableoid` catalog queries in Portfolio 5), capturing the real execution output logs in each portfolio's `evidence/` directory.

### 7.2 References & Technical Standards
1. Silberschatz, A., Korth, H. F., & Sudarshan, S. (2019). *Database System Concepts* (7th ed.). McGraw-Hill Education.
2. Kleppmann, M. (2017). *Designing Data-Intensive Applications: The Big Ideas Behind Reliable, Scalable, and Maintainable Systems*. O'Reilly Media.
3. PostgreSQL Global Development Group. (2026). *PostgreSQL 16 Documentation: Concurrency Control, Table Partitioning, and High Availability*. https://www.postgresql.org/docs/16/
4. MongoDB, Inc. (2026). *MongoDB 7.0 Manual: Schema Validation, 2dsphere Indexes, and Aggregation Pipeline*. https://www.mongodb.com/docs/v7.0/
5. Abadi, D. J. (2012). Consistency Tradeoffs in Modern Distributed Database System Design: CAP is Only Part of the Story. *IEEE Computer*, 45(2), 37–42.
