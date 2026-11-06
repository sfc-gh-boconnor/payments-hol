-- =====================================================
-- DE3: Real-time payments - reference SQL
-- The Postgres side is Python (de3_postgres.py); this is the Snowflake SQL around it.
-- Flow: Snowflake Postgres HOL_PAYMENTS_PG -> Data Mirror -> Snowflake-managed Iceberg
--       PAYMENTS_MIRROR.PAYMENTS.PAYMENT_EVENTS (+ $live, $changes) -> interactive warehouse, dynamic table
-- =====================================================
USE ROLE HOL_PARTICIPANT;
USE WAREHOUSE BARCLAYS_WH;

-- 1. The instance (create_postgres runs the CREATE and saves the one-time password in the secret):
--    CREATE POSTGRES INSTANCE HOL_PAYMENTS_PG COMPUTE_FAMILY = 'STANDARD_M' STORAGE_SIZE_GB = 10
--      AUTHENTICATION_AUTHORITY = POSTGRES POSTGRES_VERSION = 18 NETWORK_POLICY = 'HOL_PG_POLICY';
SHOW POSTGRES INSTANCES LIKE 'HOL_PAYMENTS_PG';
DESCRIBE SECRET BARCLAYS_HOL.REALTIME.PG_ADMIN_SECRET;   -- metadata only: the password isn't shown

-- 2. The mirror (start_mirror runs these)
GRANT USAGE ON POSTGRES INSTANCE HOL_PAYMENTS_PG TO APPLICATION SNOWFLAKE;
-- CALL SNOWFLAKE.POSTGRES.CREATE_MIRROR(
--     mirror_name => 'payments_mirror', postgres_instance => 'HOL_PAYMENTS_PG', postgres_database => 'postgres',
--     target_database => 'PAYMENTS_MIRROR', postgres_schemas => ['payments'],
--     refresh_interval => '1 minute', target_table_type => 'ICEBERG');
SELECT * FROM TABLE(SNOWFLAKE.POSTGRES.LIST_MIRRORS());
CALL SNOWFLAKE.POSTGRES.LIST_MIRRORED_TABLES('payments_mirror');
SHOW TABLES IN DATABASE PAYMENTS_MIRROR;   -- PAYMENT_EVENTS (Iceberg) and PAYMENT_EVENTS$CHANGES, owned by the mirror

-- 3. Freshness: volume and failures per minute, and how far each view is behind
SELECT DATE_TRUNC('minute', EVENT_TS) AS MINUTE, COUNT(*) AS EVENTS, COUNT_IF(STATUS = 'FAILED') AS FAILED
FROM PAYMENTS_MIRROR.PAYMENTS.PAYMENT_EVENTS$live
WHERE EVENT_TS >= DATEADD('minute', -15, SYSDATE())
GROUP BY 1
ORDER BY 1;

SELECT 'live' AS VIEW_NAME, DATEDIFF('second', MAX(EVENT_TS), SYSDATE()) AS SECONDS_BEHIND FROM PAYMENTS_MIRROR.PAYMENTS.PAYMENT_EVENTS$live
UNION ALL
SELECT 'base Iceberg table', DATEDIFF('second', MAX(EVENT_TS), SYSDATE()) FROM PAYMENTS_MIRROR.PAYMENTS.PAYMENT_EVENTS;

-- The change feed: I = insert, D = delete (an update is a D plus an I)
SELECT _CHANGE_TYPE, COUNT(*) AS CHANGES FROM PAYMENTS_MIRROR.PAYMENTS.PAYMENT_EVENTS$changes GROUP BY 1;

-- 4. Ops floor on the shared interactive warehouse: zero-copy, straight off the mirrored Iceberg table
USE WAREHOUSE HOL_INTERACTIVE_WH;

SELECT SCHEME, COUNT(*) AS FAILED_PAYMENTS, SUM(AMOUNT) AS FAILED_VALUE
FROM PAYMENTS_MIRROR.PAYMENTS.PAYMENT_EVENTS
WHERE STATUS = 'FAILED' AND EVENT_TS >= DATEADD('minute', -15, SYSDATE())
GROUP BY SCHEME
ORDER BY FAILED_VALUE DESC;

SELECT c.CUSTOMER_NAME, e.SCHEME, COUNT(*) AS FAILED_PAYMENTS, SUM(e.AMOUNT) AS FAILED_VALUE
FROM PAYMENTS_MIRROR.PAYMENTS.PAYMENT_EVENTS e
JOIN BARCLAYS_HOL.RAW_DATA.CUSTOMERS c ON c.CUSTOMER_ID = e.CUSTOMER_ID
WHERE e.STATUS = 'FAILED' AND e.EVENT_TS >= DATEADD('minute', -15, SYSDATE())
GROUP BY 1, 2
ORDER BY FAILED_VALUE DESC
LIMIT 10;

-- Interactive warehouses reject DML and procedures: switch back before creating anything
USE WAREHOUSE BARCLAYS_WH;

-- 5. Incidents: failing clusters in the last 15 minutes, refreshed every minute
CREATE OR REPLACE DYNAMIC TABLE BARCLAYS_HOL.REALTIME.DT_PAYMENT_INCIDENTS
  TARGET_LAG = '1 minute'
  WAREHOUSE = BARCLAYS_WH
  COMMENT = 'DE3: failing payment clusters in the last 15 minutes, refreshed every minute'
AS
SELECT e.CUSTOMER_ID,
       c.CUSTOMER_NAME,
       e.SCHEME,
       e.FAILURE_REASON,
       COUNT(*)         AS FAILED_PAYMENTS,
       SUM(e.AMOUNT)    AS FAILED_VALUE,
       MIN(e.EVENT_TS)  AS FIRST_FAILURE,
       MAX(e.EVENT_TS)  AS LAST_FAILURE
FROM PAYMENTS_MIRROR.PAYMENTS.PAYMENT_EVENTS e
JOIN BARCLAYS_HOL.RAW_DATA.CUSTOMERS c ON c.CUSTOMER_ID = e.CUSTOMER_ID
WHERE e.STATUS = 'FAILED'
  AND e.EVENT_TS >= DATEADD('minute', -15, SYSDATE())
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) >= 5;

SELECT * FROM BARCLAYS_HOL.REALTIME.DT_PAYMENT_INCIDENTS ORDER BY FAILED_PAYMENTS DESC;

-- 6. After the lab: the instance bills while it runs
-- ALTER POSTGRES INSTANCE HOL_PAYMENTS_PG SUSPEND;
-- Facilitator teardown: CALL SNOWFLAKE.POSTGRES.DROP_MIRROR(mirror_name => 'payments_mirror', drop_target_database => TRUE);
--                       DROP POSTGRES INSTANCE HOL_PAYMENTS_PG;
