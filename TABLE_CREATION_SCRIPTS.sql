-- ============================================================
-- TABLE_CREATION_SCRIPTS.sql
-- Telco Project — i2i Systems
-- Oracle XE Table Creation, Constraints, and Indexes
-- ============================================================

-- Drop tables if they already exist (safe re-run)
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE MONTHLY_STATS CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE CUSTOMERS CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE TARIFFS CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- ============================================================
-- 1. TARIFFS
-- Stores available subscription tariff plans.
-- DATA_LIMIT and MINUTE_LIMIT of 0 means unlimited for that
-- dimension (e.g., Kurumsal SMS is SMS-only, unlimited data/min).
-- ============================================================
CREATE TABLE TARIFFS (
    TARIFF_ID    NUMBER(5)       NOT NULL,
    NAME         VARCHAR2(100)   NOT NULL,
    MONTHLY_FEE  NUMBER(10, 2)   NOT NULL,
    DATA_LIMIT   NUMBER(10)      NOT NULL,   -- MB; 0 = unlimited
    MINUTE_LIMIT NUMBER(10)      NOT NULL,   -- minutes; 0 = unlimited
    SMS_LIMIT    NUMBER(10)      NOT NULL,   -- count; 0 = unlimited

    CONSTRAINT PK_TARIFFS PRIMARY KEY (TARIFF_ID),
    CONSTRAINT CHK_TARIFFS_FEE     CHECK (MONTHLY_FEE  >= 0),
    CONSTRAINT CHK_TARIFFS_DATA    CHECK (DATA_LIMIT   >= 0),
    CONSTRAINT CHK_TARIFFS_MINUTE  CHECK (MINUTE_LIMIT >= 0),
    CONSTRAINT CHK_TARIFFS_SMS     CHECK (SMS_LIMIT    >= 0)
);

-- ============================================================
-- 2. CUSTOMERS
-- Stores customer personal and subscription information.
-- TARIFF_ID references TARIFFS.
-- ============================================================
CREATE TABLE CUSTOMERS (
    CUSTOMER_ID  NUMBER(10)      NOT NULL,
    NAME         NVARCHAR2(100)  NOT NULL,   -- NVARCHAR2 for Turkish characters (ş, ğ, ü, etc.)
    CITY         NVARCHAR2(100)  NOT NULL,
    SIGNUP_DATE  DATE            NOT NULL,
    TARIFF_ID    NUMBER(5)       NOT NULL,

    CONSTRAINT PK_CUSTOMERS      PRIMARY KEY (CUSTOMER_ID),
    CONSTRAINT FK_CUSTOMERS_TARIFF
        FOREIGN KEY (TARIFF_ID) REFERENCES TARIFFS(TARIFF_ID)
);

-- Index for tariff lookups (used heavily in distribution queries)
CREATE INDEX IDX_CUSTOMERS_TARIFF   ON CUSTOMERS(TARIFF_ID);
-- Index for date-based queries (earliest customers, signup analysis)
CREATE INDEX IDX_CUSTOMERS_SIGNUP   ON CUSTOMERS(SIGNUP_DATE);
-- Index for city grouping queries
CREATE INDEX IDX_CUSTOMERS_CITY     ON CUSTOMERS(CITY);

-- ============================================================
-- 3. MONTHLY_STATS
-- Stores this month's usage and payment data per customer.
-- Not every customer has a record (insertion error — 50 missing).
-- PAYMENT_STATUS is restricted to known values via CHECK constraint.
-- ============================================================
CREATE TABLE MONTHLY_STATS (
    ID             NUMBER(10)      NOT NULL,
    CUSTOMER_ID    NUMBER(10)      NOT NULL,
    DATA_USAGE     NUMBER(12, 2)   NOT NULL,   -- MB used this month
    MINUTE_USAGE   NUMBER(10)      NOT NULL,   -- minutes used
    SMS_USAGE      NUMBER(10)      NOT NULL,   -- SMS sent
    PAYMENT_STATUS VARCHAR2(10)    NOT NULL,

    CONSTRAINT PK_MONTHLY_STATS     PRIMARY KEY (ID),
    CONSTRAINT FK_MONTHLY_CUSTOMER
        FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMERS(CUSTOMER_ID),
    CONSTRAINT UQ_MONTHLY_CUSTOMER  UNIQUE (CUSTOMER_ID),   -- one record per customer per month
    CONSTRAINT CHK_DATA_USAGE       CHECK (DATA_USAGE   >= 0),
    CONSTRAINT CHK_MINUTE_USAGE     CHECK (MINUTE_USAGE >= 0),
    CONSTRAINT CHK_SMS_USAGE        CHECK (SMS_USAGE    >= 0),
    CONSTRAINT CHK_PAYMENT_STATUS   CHECK (PAYMENT_STATUS IN ('PAID', 'UNPAID', 'LATE'))
);

-- Index for payment-status queries
CREATE INDEX IDX_MONTHLY_PAYMENT    ON MONTHLY_STATS(PAYMENT_STATUS);
-- Index for customer lookups
CREATE INDEX IDX_MONTHLY_CUSTOMER   ON MONTHLY_STATS(CUSTOMER_ID);
