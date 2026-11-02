-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - SHARED CORE
-- C1: EXPLORE THE PUBLISHED ICEBERG DATA PRODUCT  (~25 min, all personas)
--
-- Business context: you are part of Payments Operations for Corporate
-- Banking. The platform team has published nine source tables to the
-- enterprise data platform as Iceberg tables. You can read them but you
-- cannot load or change them - exactly like Barclayflake.
-- =====================================================

USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;   -- see exactly what an attendee sees
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.RAW_DATA;

-- C1.1 What has been published to us?
SHOW ICEBERG TABLES IN SCHEMA BARCLAYS_HOL.RAW_DATA;
-- Note the catalog (SNOWFLAKE) and that storage is Snowflake-managed.
-- At Barclays the same tables sit on the bank's own object storage
-- via an external volume; the SQL you write is identical.

-- C1.2 Iceberg tables keep open metadata - this is what lets other engines
-- (Spark, Trino, etc.) read the same data with no copy.
SELECT SYSTEM$GET_ICEBERG_TABLE_INFORMATION('BARCLAYS_HOL.RAW_DATA.PAYMENTS') AS ICEBERG_METADATA;

-- C1.3 Prove the guard-rails: attendees cannot load or modify source data.
-- Expect: "Insufficient privileges". This is intentional.
-- INSERT INTO PAYMENTS (PAYMENT_ID) VALUES ('TEST');

-- C1.4 Get to know the data model (see docs/data_sources.md for the ERD)
SELECT 'PAYMENTS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM PAYMENTS
UNION ALL SELECT 'CUSTOMER_FEEDBACK',     COUNT(*) FROM CUSTOMER_FEEDBACK
UNION ALL SELECT 'OPERATIONAL_ALERTS',    COUNT(*) FROM OPERATIONAL_ALERTS
UNION ALL SELECT 'CUSTOMERS',             COUNT(*) FROM CUSTOMERS
UNION ALL SELECT 'ACCOUNTS',              COUNT(*) FROM ACCOUNTS
UNION ALL SELECT 'RELATIONSHIP_MANAGERS', COUNT(*) FROM RELATIONSHIP_MANAGERS
ORDER BY ROW_COUNT DESC;

-- C1.5 Payments mix by scheme - the six UK/international rails
SELECT PAYMENT_TYPE,
       COUNT(*)                                        AS PAYMENTS,
       ROUND(SUM(AMOUNT) / 1e6, 1)                     AS VOLUME_M,
       ROUND(COUNT_IF(STATUS = 'COMPLETED') / COUNT(*) * 100, 2) AS SUCCESS_RATE_PCT
FROM PAYMENTS
GROUP BY PAYMENT_TYPE
ORDER BY PAYMENTS DESC;

-- C1.6 A corporate client 360 in one query: customer -> RM -> accounts -> payments -> feedback
SELECT c.CUSTOMER_NAME, c.SECTOR, r.RM_NAME, r.TEAM,
       COUNT(DISTINCT a.ACCOUNT_ID)                    AS ACCOUNTS,
       COUNT(DISTINCT p.PAYMENT_ID)                    AS PAYMENTS,
       COUNT(DISTINCT IFF(p.STATUS = 'FAILED', p.PAYMENT_ID, NULL)) AS FAILED,
       COUNT(DISTINCT f.FEEDBACK_ID)                   AS FEEDBACK_ITEMS
FROM CUSTOMERS c
JOIN RELATIONSHIP_MANAGERS r ON c.RM_ID = r.RM_ID
JOIN ACCOUNTS a              ON a.CUSTOMER_ID = c.CUSTOMER_ID
LEFT JOIN PAYMENTS p         ON p.ORIGINATOR_ACCOUNT_ID = a.ACCOUNT_ID
LEFT JOIN CUSTOMER_FEEDBACK f ON f.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY ALL
ORDER BY FAILED DESC
LIMIT 10;

-- C1.7 Iceberg time travel works too: what did PAYMENTS look like an hour ago?
-- (Uncomment once the tables are at least a few minutes old.)
-- SELECT COUNT(*) FROM PAYMENTS AT (OFFSET => -60*5);

-- C1.8 Ask Cortex Code (CoCo panel in your Workspace):
--   "Describe the tables in BARCLAYS_HOL.RAW_DATA and how they join together."
--   "Which customers have the highest payment failure rate? Write the SQL and run it."

SELECT 'Core C1 complete - pick your pathway in pathways/' AS STATUS;
