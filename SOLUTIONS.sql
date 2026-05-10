-- ============================================================
-- SOLUTIONS.sql
-- Telco Project — i2i Systems
-- SQL Query Solutions for All Functional Requirements
-- ============================================================


-- ============================================================
-- 1. TARIFF-BASED CUSTOMER QUERIES
-- ============================================================

-- ------------------------------------------------------------
-- 1.1 List the customers subscribed to the 'Kobiye Destek' tariff.
-- ------------------------------------------------------------
/*
  EXPLANATION:
  We join the CUSTOMERS table with the TARIFFS table on TARIFF_ID to
  match each customer with their plan. The WHERE clause filters only
  those rows where the tariff name equals 'Kobiye Destek'. This join
  approach is preferred over a subquery here because it allows us to
  directly access tariff attributes alongside customer data in a single
  pass, which is both readable and efficient given the indexed TARIFF_ID.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE,
    t.NAME AS TARIFF_NAME
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
WHERE t.NAME = 'Kobiye Destek'
ORDER BY c.CUSTOMER_ID;

-- ------------------------------------------------------------
-- 1.2 Find the newest customer who subscribed to 'Kobiye Destek'.
-- ------------------------------------------------------------
/*
  EXPLANATION:
  We reuse the same join structure as 1.1 but this time we want only
  the single most recent record. We achieve this with ORDER BY SIGNUP_DATE
  DESC and FETCH FIRST 1 ROW ONLY, which is Oracle's equivalent of LIMIT 1.
  In the event of a tie (two customers signing up on the same day), the
  CUSTOMER_ID tiebreaker ensures a deterministic result rather than an
  arbitrary one. This is important for reproducibility of the query output.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE,
    t.NAME AS TARIFF_NAME
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
WHERE t.NAME = 'Kobiye Destek'
ORDER BY c.SIGNUP_DATE DESC, c.CUSTOMER_ID DESC
FETCH FIRST 1 ROW ONLY;


-- ============================================================
-- 2. TARIFF DISTRIBUTION
-- ============================================================

-- ------------------------------------------------------------
-- 2.1 Find the distribution of tariffs among all customers.
-- ------------------------------------------------------------
/*
  EXPLANATION:
  We group customers by their TARIFF_ID and join with TARIFFS to display
  the human-readable tariff name. For each group we count the number of
  customers and calculate the percentage share relative to the total
  customer base using a window function (COUNT(*) OVER ()). This avoids
  a self-join or subquery to get the total, making the query cleaner and
  more efficient since the total is computed in a single scan. Results are
  ordered descending so the most popular tariff appears first.
*/
SELECT
    t.TARIFF_ID,
    t.NAME                                        AS TARIFF_NAME,
    COUNT(c.CUSTOMER_ID)                          AS CUSTOMER_COUNT,
    ROUND(
        COUNT(c.CUSTOMER_ID) * 100.0
        / COUNT(c.CUSTOMER_ID) OVER (),
    2)                                            AS PERCENTAGE
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
GROUP BY t.TARIFF_ID, t.NAME
ORDER BY CUSTOMER_COUNT DESC;


-- ============================================================
-- 3. CUSTOMER SIGNUP ANALYSIS
-- ============================================================

-- ------------------------------------------------------------
-- 3.1 Identify the earliest customers to sign up.
-- ------------------------------------------------------------
/*
  EXPLANATION:
  The hint reminds us that the earliest sign-up date does not necessarily
  correspond to the lowest CUSTOMER_ID values, meaning IDs were not
  necessarily assigned in chronological order. We therefore sort by
  SIGNUP_DATE ascending to find the true earliest registrants. We use
  FETCH FIRST 10 ROWS WITH TIES so that if multiple customers share the
  earliest date, none are arbitrarily excluded. The result gives a reliable
  view of who actually joined the platform first, regardless of their ID.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE,
    t.NAME AS TARIFF_NAME
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
ORDER BY c.SIGNUP_DATE ASC
FETCH FIRST 10 ROWS WITH TIES;

-- ------------------------------------------------------------
-- 3.2 Distribution of these earliest customers across cities.
-- ------------------------------------------------------------
/*
  EXPLANATION:
  To find the city distribution of the earliest customers, we first isolate
  the minimum signup date using a subquery, then group the customers who
  share that date by city. Using a subquery for the minimum date is cleaner
  than a window function here because we need a hard filter, not just a
  ranking. The COUNT per city with a grand total via ROLLUP gives a
  complete distribution picture in a single result set, which is useful for
  reporting. GROUPING() is used to label the total row clearly.
*/
SELECT
    CASE WHEN GROUPING(c.CITY) = 1 THEN 'TOTAL' ELSE c.CITY END AS CITY,
    COUNT(*) AS CUSTOMER_COUNT
FROM CUSTOMERS c
WHERE c.SIGNUP_DATE = (SELECT MIN(SIGNUP_DATE) FROM CUSTOMERS)
GROUP BY ROLLUP(c.CITY)
ORDER BY CUSTOMER_COUNT DESC;


-- ============================================================
-- 4. MISSING MONTHLY RECORDS
-- ============================================================

-- ------------------------------------------------------------
-- 4.1 Identify customer IDs whose monthly records are missing.
-- ------------------------------------------------------------
/*
  EXPLANATION:
  A missing monthly record means the customer exists in CUSTOMERS but
  has no corresponding row in MONTHLY_STATS. We detect this with a LEFT
  JOIN — every customer is included, but those without a matching
  MONTHLY_STATS row will have NULL in the ms.CUSTOMER_ID column. The
  WHERE ms.CUSTOMER_ID IS NULL filter isolates exactly these customers.
  This is generally more performant than a NOT IN subquery in Oracle,
  especially when the subquery could theoretically return NULLs, which
  would cause NOT IN to return no rows at all.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    c.SIGNUP_DATE,
    t.NAME AS TARIFF_NAME
FROM CUSTOMERS c
JOIN TARIFFS t ON c.TARIFF_ID = t.TARIFF_ID
LEFT JOIN MONTHLY_STATS ms ON c.CUSTOMER_ID = ms.CUSTOMER_ID
WHERE ms.CUSTOMER_ID IS NULL
ORDER BY c.CUSTOMER_ID;

-- ------------------------------------------------------------
-- 4.2 Distribution of missing customers across cities.
-- ------------------------------------------------------------
/*
  EXPLANATION:
  Building on 4.1, we wrap the missing customer logic inside a CTE
  (Common Table Expression) called MISSING_CUSTOMERS for readability and
  reusability. The outer query then groups the result by city to produce
  the distribution. Using a CTE rather than a nested subquery makes the
  intent of the query immediately clear to any reader: first identify the
  missing customers, then aggregate by city. The ORDER BY ensures cities
  with more missing customers appear at the top for quick identification.
*/
WITH MISSING_CUSTOMERS AS (
    SELECT c.CUSTOMER_ID, c.CITY
    FROM CUSTOMERS c
    LEFT JOIN MONTHLY_STATS ms ON c.CUSTOMER_ID = ms.CUSTOMER_ID
    WHERE ms.CUSTOMER_ID IS NULL
)
SELECT
    CITY,
    COUNT(*) AS MISSING_COUNT
FROM MISSING_CUSTOMERS
GROUP BY CITY
ORDER BY MISSING_COUNT DESC;


-- ============================================================
-- 5. USAGE ANALYSIS
-- ============================================================

-- ------------------------------------------------------------
-- 5.1 Customers who have used at least 75% of their data limit.
-- ------------------------------------------------------------
/*
  EXPLANATION:
  We join all three tables to access both the customer's data usage from
  MONTHLY_STATS and their plan's DATA_LIMIT from TARIFFS. The 75% threshold
  is expressed as ms.DATA_USAGE >= t.DATA_LIMIT * 0.75. We explicitly
  exclude tariffs where DATA_LIMIT = 0 because those plans (e.g., Kurumsal
  SMS) have no data cap, making the percentage calculation meaningless —
  dividing by zero would cause an error, and those customers are not
  constrained by data usage at all. The usage percentage is also computed
  and displayed for context.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    t.NAME                                              AS TARIFF_NAME,
    t.DATA_LIMIT                                        AS DATA_LIMIT_MB,
    ms.DATA_USAGE                                       AS DATA_USED_MB,
    ROUND(ms.DATA_USAGE * 100.0 / t.DATA_LIMIT, 2)     AS DATA_USAGE_PCT
FROM CUSTOMERS c
JOIN TARIFFS t        ON c.TARIFF_ID    = t.TARIFF_ID
JOIN MONTHLY_STATS ms ON c.CUSTOMER_ID  = ms.CUSTOMER_ID
WHERE t.DATA_LIMIT > 0
  AND ms.DATA_USAGE >= t.DATA_LIMIT * 0.75
ORDER BY DATA_USAGE_PCT DESC;

-- ------------------------------------------------------------
-- 5.2 Customers who have exhausted ALL package limits
--     (data, minutes, AND SMS all fully used).
-- ------------------------------------------------------------
/*
  EXPLANATION:
  A customer is considered to have exhausted all limits only when their
  usage meets or exceeds all three caps simultaneously: data, minutes,
  and SMS. We use AND to combine all three conditions, meaning any
  customer who still has capacity in even one dimension is excluded.
  As in 5.1, we filter out tariffs with a 0 limit per dimension to avoid
  comparing usage against an unlimited allowance, which would produce
  semantically incorrect results. Each dimension is checked independently
  to handle tariffs that may have limits on some dimensions but not others.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    t.NAME          AS TARIFF_NAME,
    t.DATA_LIMIT,   ms.DATA_USAGE,
    t.MINUTE_LIMIT, ms.MINUTE_USAGE,
    t.SMS_LIMIT,    ms.SMS_USAGE
FROM CUSTOMERS c
JOIN TARIFFS t        ON c.TARIFF_ID   = t.TARIFF_ID
JOIN MONTHLY_STATS ms ON c.CUSTOMER_ID = ms.CUSTOMER_ID
WHERE (t.DATA_LIMIT   = 0 OR ms.DATA_USAGE   >= t.DATA_LIMIT)
  AND (t.MINUTE_LIMIT = 0 OR ms.MINUTE_USAGE >= t.MINUTE_LIMIT)
  AND (t.SMS_LIMIT    = 0 OR ms.SMS_USAGE    >= t.SMS_LIMIT)
ORDER BY c.CUSTOMER_ID;


-- ============================================================
-- 6. PAYMENT ANALYSIS
-- ============================================================

-- ------------------------------------------------------------
-- 6.1 Find the customers who have unpaid fees.
-- ------------------------------------------------------------
/*
  EXPLANATION:
  We filter MONTHLY_STATS for rows where PAYMENT_STATUS = 'UNPAID' and
  join with CUSTOMERS to retrieve personal details. The dataset contains
  three possible payment statuses: PAID, LATE, and UNPAID. We consider
  only 'UNPAID' here as truly unpaid — customers with status 'LATE' have
  technically missed their deadline but their situation may warrant separate
  treatment (see 6.2). This strict filter ensures we surface only customers
  who have not made any payment at all, which is the most actionable group
  from a collections perspective.
*/
SELECT
    c.CUSTOMER_ID,
    c.NAME,
    c.CITY,
    t.NAME              AS TARIFF_NAME,
    t.MONTHLY_FEE,
    ms.PAYMENT_STATUS
FROM CUSTOMERS c
JOIN TARIFFS t        ON c.TARIFF_ID   = t.TARIFF_ID
JOIN MONTHLY_STATS ms ON c.CUSTOMER_ID = ms.CUSTOMER_ID
WHERE ms.PAYMENT_STATUS = 'UNPAID'
ORDER BY t.MONTHLY_FEE DESC, c.CUSTOMER_ID;

-- ------------------------------------------------------------
-- 6.2 Distribution of all payment statuses across tariffs.
-- ------------------------------------------------------------
/*
  EXPLANATION:
  This query performs a cross-tabulation of payment status by tariff,
  which gives a full picture of payment behavior for each plan. We use
  conditional aggregation (SUM with CASE WHEN) to pivot the three status
  values into separate columns, making the output easy to read in a single
  row per tariff. A ROLLUP on the tariff dimension adds a grand total row
  at the bottom. This approach is more readable than a GROUP BY with
  multiple self-joins and produces the same result in a single scan of
  MONTHLY_STATS joined once to CUSTOMERS and TARIFFS.
*/
SELECT
    CASE WHEN GROUPING(t.NAME) = 1 THEN 'ALL TARIFFS' ELSE t.NAME END
                                                    AS TARIFF_NAME,
    COUNT(ms.ID)                                    AS TOTAL_RECORDS,
    SUM(CASE WHEN ms.PAYMENT_STATUS = 'PAID'   THEN 1 ELSE 0 END) AS PAID_COUNT,
    SUM(CASE WHEN ms.PAYMENT_STATUS = 'LATE'   THEN 1 ELSE 0 END) AS LATE_COUNT,
    SUM(CASE WHEN ms.PAYMENT_STATUS = 'UNPAID' THEN 1 ELSE 0 END) AS UNPAID_COUNT,
    ROUND(
        SUM(CASE WHEN ms.PAYMENT_STATUS = 'PAID' THEN 1 ELSE 0 END) * 100.0
        / COUNT(ms.ID),
    2)                                              AS PAID_PCT
FROM CUSTOMERS c
JOIN TARIFFS t        ON c.TARIFF_ID   = t.TARIFF_ID
JOIN MONTHLY_STATS ms ON c.CUSTOMER_ID = ms.CUSTOMER_ID
GROUP BY ROLLUP(t.NAME)
ORDER BY TOTAL_RECORDS DESC;
