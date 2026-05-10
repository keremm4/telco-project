# Telco Project — i2i Systems

SQL solutions for telecom data analysis using Oracle XE.

---

## Repository Structure

```
telco-project/
├── CUSTOMERS.csv                  # Raw customer data (10,000 rows)
├── MONTHLY_STATS.csv              # Monthly usage & payment data (9,950 rows)
├── TARIFFS.csv                    # Tariff plans (4 rows)
├── TABLE_CREATION_SCRIPTS.sql     # Table DDL with constraints and indexes
├── SOLUTIONS.sql                  # All query solutions with explanations
├── docker-compose.yml             # One-command environment setup
└── init/
    └── 01_create_tables.sql       # Auto-runs on container first start
```

---

## Setup Guide

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [DBeaver](https://dbeaver.io/)

---

### Step 1 — Start the Database

Clone this repository and run:

```bash
docker-compose up -d
```

This will:
- Pull the `gvenzl/oracle-xe:21-slim` image
- Start Oracle XE on port `1521`
- Automatically run `init/01_create_tables.sql` to create all tables

Wait ~2 minutes for the database to initialize. Check when it's ready:

```bash
docker logs telco-oracle-xe
```

You should see: `DATABASE IS READY TO USE!`

---

### Step 2 — Connect with DBeaver

Open DBeaver and create a new connection:

| Field    | Value        |
|----------|--------------|
| Type     | Oracle       |
| Host     | localhost    |
| Port     | 1521         |
| Database | XE           |
| Username | telco_user   |
| Password | telco123     |

Click **Test Connection** to verify.

---

### Step 3 — Import CSV Data

Tables are already created by the init script. Import the data via DBeaver:

1. In the Database Navigator, right-click **TARIFFS** → **Import Data**
2. Select `TARIFFS.csv` as the source → map columns → Finish
3. Repeat for **CUSTOMERS** (`CUSTOMERS.csv`)
4. Repeat for **MONTHLY_STATS** (`MONTHLY_STATS.csv`)

> **Important:** Import in this order — TARIFFS first, then CUSTOMERS, then MONTHLY_STATS — to satisfy foreign key constraints.

**Date format for CUSTOMERS.SIGNUP_DATE:** `DD/MM/YYYY`

---

### Step 4 — Run the Queries

Open `SOLUTIONS.sql` in DBeaver and run each query individually to see results.

---

## Database Schema

```
TARIFFS (TARIFF_ID PK, NAME, MONTHLY_FEE, DATA_LIMIT, MINUTE_LIMIT, SMS_LIMIT)
    │
    └──< CUSTOMERS (CUSTOMER_ID PK, NAME, CITY, SIGNUP_DATE, TARIFF_ID FK)
              │
              └──< MONTHLY_STATS (ID PK, CUSTOMER_ID FK/UQ, DATA_USAGE,
                                  MINUTE_USAGE, SMS_USAGE, PAYMENT_STATUS)
```

---

## Stopping the Database

```bash
docker-compose down          # stop but keep data
docker-compose down -v       # stop and delete all data
```
