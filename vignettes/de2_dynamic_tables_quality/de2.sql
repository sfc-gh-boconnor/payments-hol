-- =====================================================
-- VIGNETTE DE2: DYNAMIC TABLES + DATA QUALITY   (~45 min)
-- Persona: Data Engineer
-- Question: "How do I keep an ops-floor SLA monitor fresh without writing
--            orchestration, and prove the data feeding it is trustworthy?"
-- Prereq:   setup/catchup/core_analytics.sql  (or DE1 + DA2)
-- =====================================================

USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;   -- see exactly what an attendee sees
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.ANALYTICS;

-- -----------------------------------------------------
-- DE2.1 Dynamic Tables: declare the result, Snowflake keeps it fresh
-- -----------------------------------------------------

-- Ops-floor SLA breach monitor: never more than 1 minute stale
CREATE OR REPLACE DYNAMIC TABLE DT_LIVE_SLA_BREACHES
    TARGET_LAG = '1 minute'
    WAREHOUSE  = BARCLAYS_WH
AS
SELECT PAYMENT_TYPE,
       SUM(TOTAL_PAYMENTS)  AS TOTAL_PAYMENTS,
       SUM(FAILED_PAYMENTS) AS BREACHED_PAYMENTS,
       ROUND(SUM(FAILED_PAYMENTS)::FLOAT / NULLIF(SUM(TOTAL_PAYMENTS), 0) * 100, 2) AS BREACH_RATE_PCT,
       MIN(PAYMENT_DAY) AS EARLIEST_BREACH,
       MAX(PAYMENT_DAY) AS LATEST_BREACH
FROM MART_SLA_COMPLIANCE
WHERE SLA_STATUS = 'BREACH'
GROUP BY PAYMENT_TYPE;

-- Failed-payment triage feed built straight off the Iceberg source.
-- Dynamic tables can read Iceberg tables directly - no copy into Snowflake storage.
CREATE OR REPLACE DYNAMIC TABLE DT_FAILED_PAYMENT_TRIAGE
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE  = BARCLAYS_WH
AS
SELECT p.PAYMENT_ID, p.PAYMENT_DATE, p.PAYMENT_TYPE, p.AMOUNT, p.CURRENCY,
       p.ERROR_CODE, e.ERROR_DESCRIPTION, e.ERROR_CATEGORY, e.IS_RETRYABLE,
       c.CUSTOMER_NAME, c.SECTOR, r.RM_NAME
FROM BARCLAYS_HOL.RAW_DATA.PAYMENTS p
JOIN BARCLAYS_HOL.RAW_DATA.ERROR_CODES e  ON p.ERROR_CODE = e.ERROR_CODE
JOIN BARCLAYS_HOL.RAW_DATA.ACCOUNTS a     ON p.ORIGINATOR_ACCOUNT_ID = a.ACCOUNT_ID
JOIN BARCLAYS_HOL.RAW_DATA.CUSTOMERS c    ON a.CUSTOMER_ID = c.CUSTOMER_ID
JOIN BARCLAYS_HOL.RAW_DATA.RELATIONSHIP_MANAGERS r ON c.RM_ID = r.RM_ID
WHERE p.STATUS IN ('FAILED', 'RETURNED');

-- Downstream summary chained off the triage feed
CREATE OR REPLACE DYNAMIC TABLE DT_RETRYABLE_SUMMARY
    TARGET_LAG = '5 minutes'
    WAREHOUSE  = BARCLAYS_WH
AS
SELECT PAYMENT_TYPE, ERROR_CATEGORY, IS_RETRYABLE,
       COUNT(*) AS PAYMENTS, ROUND(SUM(AMOUNT), 2) AS VALUE_AT_RISK
FROM DT_FAILED_PAYMENT_TRIAGE
GROUP BY ALL;

SHOW DYNAMIC TABLES IN SCHEMA BARCLAYS_HOL.ANALYTICS;

-- Refresh history and the pipeline graph are also visible in Snowsight:
-- Monitoring > Dynamic Tables > DT_RETRYABLE_SUMMARY > Graph
SELECT NAME, STATE, REFRESH_ACTION, REFRESH_TRIGGER, DATA_TIMESTAMP
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY())
WHERE NAME LIKE 'DT_%'
ORDER BY DATA_TIMESTAMP DESC
LIMIT 10;

-- -----------------------------------------------------
-- DE2.2 Data Metric Functions: quality checks that run on a schedule
-- -----------------------------------------------------

-- Schedule is set per table; changes also trigger a check
ALTER TABLE MART_CUSTOMER_PAYMENTS SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

-- System DMFs
ALTER TABLE MART_CUSTOMER_PAYMENTS ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.NULL_COUNT ON (RM_NAME);
ALTER TABLE MART_CUSTOMER_PAYMENTS ADD DATA METRIC FUNCTION
    SNOWFLAKE.CORE.DUPLICATE_COUNT ON (CUSTOMER_ID);

-- A custom, business-rule DMF: success rate must be a valid percentage
-- (the argument type must match the column type - SUCCESS_RATE_PCT is FLOAT)
CREATE OR REPLACE DATA METRIC FUNCTION INVALID_SUCCESS_RATE_COUNT(
    t TABLE (SUCCESS_RATE_PCT FLOAT))
RETURNS NUMBER
AS
$$
    SELECT COUNT(*) FROM t
    WHERE SUCCESS_RATE_PCT IS NULL OR SUCCESS_RATE_PCT < 0 OR SUCCESS_RATE_PCT > 100
$$;

ALTER TABLE MART_CUSTOMER_PAYMENTS ADD DATA METRIC FUNCTION
    INVALID_SUCCESS_RATE_COUNT ON (SUCCESS_RATE_PCT);

-- Expectations: turn a metric into a pass/fail rule
ALTER TABLE MART_CUSTOMER_PAYMENTS MODIFY DATA METRIC FUNCTION
    SNOWFLAKE.CORE.DUPLICATE_COUNT ON (CUSTOMER_ID)
    ADD EXPECTATION NO_DUPLICATE_CUSTOMERS (VALUE = 0);

-- Which checks are attached?
SELECT METRIC_NAME, REF_ARGUMENTS, SCHEDULE, SCHEDULE_STATUS
FROM TABLE(INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
    REF_ENTITY_NAME   => 'BARCLAYS_HOL.ANALYTICS.MART_CUSTOMER_PAYMENTS',
    REF_ENTITY_DOMAIN => 'TABLE'));

-- Run the checks on demand (scheduled results land in
-- SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS after a few minutes)
SELECT SNOWFLAKE.CORE.NULL_COUNT(SELECT RM_NAME FROM MART_CUSTOMER_PAYMENTS)        AS NULL_RM_NAMES,
       SNOWFLAKE.CORE.DUPLICATE_COUNT(SELECT CUSTOMER_ID FROM MART_CUSTOMER_PAYMENTS) AS DUPLICATE_CUSTOMERS,
       INVALID_SUCCESS_RATE_COUNT(SELECT SUCCESS_RATE_PCT FROM MART_CUSTOMER_PAYMENTS) AS INVALID_RATES;

-- -----------------------------------------------------
-- DE2.3 Cortex Code prompts (try in the CoCo panel)
-- -----------------------------------------------------
--  "Add a dynamic table DT_HIGH_VALUE_FAILURES in BARCLAYS_HOL.ANALYTICS showing
--   failed CHAPS payments over 1m GBP with the customer and RM, refreshing every
--   2 minutes. Then show me its refresh history."
--  "Add a data metric function to MART_PAYMENT_KPIS that counts rows where
--   P95_PROCESSING_TIME_MS is less than AVG_PROCESSING_TIME_MS, and attach it."

SELECT 'DE2 complete' AS STATUS;
