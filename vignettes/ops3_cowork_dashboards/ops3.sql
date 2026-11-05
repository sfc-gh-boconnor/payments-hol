-- =====================================================
-- OPS3: Payments operations in Snowflake CoWork - reference SQL
-- OPS3 is done in the CoWork UI and a Workspace dashboard; this is the SQL behind it.
-- The agent and semantic view are built at provisioning (setup/09_cowork_pack.sql).
-- =====================================================
USE ROLE HOL_PARTICIPANT;
USE WAREHOUSE BARCLAYS_WH;

-- 1. The agent CoWork lists, and its tools (Analyst + code execution)
SHOW AGENTS IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS;
DESCRIBE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.PAYMENTS_OPS_COWORK;

-- 2. The semantic view it answers from
SHOW SEMANTIC METRICS IN BARCLAYS_HOL.COWORK_PACK.SV_PAYMENTS_OPS;

-- 3. The same numbers as the chart step: monthly failed value by scheme, last 12 months
SELECT * FROM SEMANTIC_VIEW(
    BARCLAYS_HOL.COWORK_PACK.SV_PAYMENTS_OPS
    DIMENSIONS payments.payment_month, payments.payment_type
    METRICS payments.failed_value
    WHERE payments.payment_month >= DATEADD('month', -12, DATE_TRUNC('month', CURRENT_DATE()))
)
ORDER BY PAYMENT_MONTH, PAYMENT_TYPE;

-- 4. The Logistics story behind the Deep Research step: feedback that mentions leaving, by sector,
--    and the sector's payment failure rate (which isn't unusual - the issue is service, not failures)
WITH feedback AS (
    SELECT CUSTOMER_SECTOR,
           COUNT_IF(FEEDBACK_MONTH >= DATEADD('month', -4, DATE_TRUNC('month', CURRENT_DATE()))) AS RECENT_FEEDBACK,
           COUNT_IF(FEEDBACK_TEXT ILIKE ANY ('%other banking providers%', '%another bank%', '%tender%')) AS CHURN_MENTIONS
    FROM BARCLAYS_HOL.COWORK_PACK.CLIENT_FEEDBACK
    GROUP BY 1
), payments AS (
    SELECT CUSTOMER_SECTOR, ROUND(COUNT_IF(STATUS = 'FAILED') / COUNT(*) * 100, 1) AS FAILURE_RATE_PCT
    FROM BARCLAYS_HOL.COWORK_PACK.PAYMENT_ACTIVITY
    WHERE PAYMENT_DATE >= DATEADD('month', -4, CURRENT_DATE())
    GROUP BY 1
)
SELECT f.CUSTOMER_SECTOR, f.RECENT_FEEDBACK, f.CHURN_MENTIONS, p.FAILURE_RATE_PCT
FROM feedback f LEFT JOIN payments p USING (CUSTOMER_SECTOR)
ORDER BY f.CHURN_MENTIONS DESC, f.CUSTOMER_SECTOR;

-- 5. The automation step's question: top 5 clients by failed value last week
SELECT CUSTOMER_NAME, RM_NAME, PAYMENT_TYPE AS MAIN_FAILING_SCHEME, FAILED_VALUE
FROM (
    SELECT CUSTOMER_NAME, RM_NAME, PAYMENT_TYPE, SUM(AMOUNT) AS FAILED_VALUE,
           SUM(SUM(AMOUNT)) OVER (PARTITION BY CUSTOMER_NAME) AS CLIENT_FAILED_VALUE,
           ROW_NUMBER() OVER (PARTITION BY CUSTOMER_NAME ORDER BY SUM(AMOUNT) DESC) AS RN
    FROM BARCLAYS_HOL.COWORK_PACK.PAYMENT_ACTIVITY
    WHERE STATUS = 'FAILED'
      AND PAYMENT_DATE >= DATEADD('week', -1, DATE_TRUNC('week', CURRENT_DATE()))
      AND PAYMENT_DATE <  DATE_TRUNC('week', CURRENT_DATE())
    GROUP BY 1, 2, 3
)
WHERE RN = 1
ORDER BY CLIENT_FAILED_VALUE DESC
LIMIT 5;

-- 6. Dashboard tile queries (what Cortex Code should generate for payments_ops)
--    Scorecards
SELECT SUM(AMOUNT) AS PAYMENT_VALUE,
       ROUND(COUNT_IF(STATUS = 'COMPLETED') / NULLIF(COUNT(*), 0) * 100, 1) AS SUCCESS_RATE_PCT,
       SUM(IFF(STATUS = 'FAILED', AMOUNT, 0)) AS FAILED_VALUE
FROM BARCLAYS_HOL.COWORK_PACK.PAYMENT_ACTIVITY
WHERE PAYMENT_DATE >= DATEADD('month', -12, CURRENT_DATE());
--    Top 10 clients by failed value
SELECT CUSTOMER_NAME, CUSTOMER_SECTOR, RM_NAME, SUM(AMOUNT) AS FAILED_VALUE, COUNT(*) AS FAILED_PAYMENTS
FROM BARCLAYS_HOL.COWORK_PACK.PAYMENT_ACTIVITY
WHERE STATUS = 'FAILED' AND PAYMENT_DATE >= DATEADD('month', -12, CURRENT_DATE())
GROUP BY 1, 2, 3
ORDER BY FAILED_VALUE DESC
LIMIT 10;
--    Failed payments by error code
SELECT ERROR_CODE, COUNT(*) AS FAILED_PAYMENTS, SUM(AMOUNT) AS FAILED_VALUE
FROM BARCLAYS_HOL.COWORK_PACK.PAYMENT_ACTIVITY
WHERE STATUS = 'FAILED' AND PAYMENT_DATE >= DATEADD('month', -12, CURRENT_DATE())
GROUP BY 1
ORDER BY FAILED_PAYMENTS DESC;
