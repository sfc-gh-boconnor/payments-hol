-- =====================================================
-- BARCLAYS HANDS-ON LAB
-- STEP 3 VALIDATION: Verify dbt output matches spec
-- Run this AFTER Cortex Code completes dbt run + dbt test
-- =====================================================

USE WAREHOUSE BARCLAYS_WH;
USE DATABASE BARCLAYS_HOL;

-- =====================================================
-- 3a: BASE MODEL VALIDATION
-- These models are pre-written and walked through in the lab
-- =====================================================

-- 1. Check all base tables exist in ANALYTICS
WITH expected_tables AS (
    SELECT column1 AS TABLE_NAME FROM VALUES
        ('STG_PAYMENTS'),
        ('STG_FEEDBACK'),
        ('STG_CUSTOMERS'),
        ('STG_ACCOUNTS'),
        ('MART_PAYMENT_KPIS'),
        ('MART_SLA_COMPLIANCE')
),
actual_tables AS (
    SELECT TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'ANALYTICS'
)
SELECT
    e.TABLE_NAME,
    IFF(a.TABLE_NAME IS NOT NULL, 'PASS', 'FAIL - TABLE MISSING') AS STATUS
FROM expected_tables e
LEFT JOIN actual_tables a ON e.TABLE_NAME = a.TABLE_NAME;

-- 2. Check key columns exist per base model
WITH expected_columns AS (
    SELECT column1 AS TABLE_NAME, column2 AS COLUMN_NAME FROM VALUES
        -- stg_payments (updated for new schema)
        ('STG_PAYMENTS', 'PAYMENT_ID'),
        ('STG_PAYMENTS', 'PAYMENT_DATE'),
        ('STG_PAYMENTS', 'ORIGINATOR_ACCOUNT_ID'),
        ('STG_PAYMENTS', 'BENEFICIARY_ACCOUNT_ID'),
        ('STG_PAYMENTS', 'PAYMENT_TYPE'),
        ('STG_PAYMENTS', 'CHANNEL'),
        ('STG_PAYMENTS', 'CURRENCY'),
        ('STG_PAYMENTS', 'AMOUNT'),
        ('STG_PAYMENTS', 'FX_RATE'),
        ('STG_PAYMENTS', 'STATUS'),
        ('STG_PAYMENTS', 'PROCESSING_TIME_MS'),
        ('STG_PAYMENTS', 'ERROR_CODE'),
        ('STG_PAYMENTS', 'REGION'),
        ('STG_PAYMENTS', 'SETTLEMENT_DATE'),
        ('STG_PAYMENTS', 'IS_SUCCESSFUL'),
        ('STG_PAYMENTS', 'IS_FAILED'),
        -- stg_feedback
        ('STG_FEEDBACK', 'FEEDBACK_ID'),
        ('STG_FEEDBACK', 'CUSTOMER_ID'),
        ('STG_FEEDBACK', 'PAYMENT_ID'),
        ('STG_FEEDBACK', 'FEEDBACK_TEXT'),
        ('STG_FEEDBACK', 'SATISFACTION_TIER'),
        -- stg_customers
        ('STG_CUSTOMERS', 'CUSTOMER_ID'),
        ('STG_CUSTOMERS', 'CUSTOMER_NAME'),
        ('STG_CUSTOMERS', 'SECTOR'),
        ('STG_CUSTOMERS', 'RM_ID'),
        ('STG_CUSTOMERS', 'RM_NAME'),
        ('STG_CUSTOMERS', 'RM_TEAM'),
        -- stg_accounts
        ('STG_ACCOUNTS', 'ACCOUNT_ID'),
        ('STG_ACCOUNTS', 'CUSTOMER_ID'),
        ('STG_ACCOUNTS', 'CURRENCY'),
        ('STG_ACCOUNTS', 'ACCOUNT_TYPE'),
        ('STG_ACCOUNTS', 'CUSTOMER_NAME'),
        ('STG_ACCOUNTS', 'CUSTOMER_SECTOR'),
        -- mart_payment_kpis
        ('MART_PAYMENT_KPIS', 'PAYMENT_DAY'),
        ('MART_PAYMENT_KPIS', 'PAYMENT_TYPE'),
        ('MART_PAYMENT_KPIS', 'REGION'),
        ('MART_PAYMENT_KPIS', 'CHANNEL'),
        ('MART_PAYMENT_KPIS', 'CUSTOMER_SECTOR'),
        ('MART_PAYMENT_KPIS', 'RM_NAME'),
        ('MART_PAYMENT_KPIS', 'RM_TEAM'),
        ('MART_PAYMENT_KPIS', 'TOTAL_PAYMENTS'),
        ('MART_PAYMENT_KPIS', 'TOTAL_VOLUME_GBP'),
        ('MART_PAYMENT_KPIS', 'SUCCESS_RATE_PCT'),
        ('MART_PAYMENT_KPIS', 'AVG_PROCESSING_TIME_MS'),
        ('MART_PAYMENT_KPIS', 'P95_PROCESSING_TIME_MS'),
        -- mart_sla_compliance
        ('MART_SLA_COMPLIANCE', 'PAYMENT_DAY'),
        ('MART_SLA_COMPLIANCE', 'PAYMENT_TYPE'),
        ('MART_SLA_COMPLIANCE', 'SLA_NAME'),
        ('MART_SLA_COMPLIANCE', 'SLA_STATUS')
),
actual_columns AS (
    SELECT TABLE_NAME, COLUMN_NAME
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'ANALYTICS'
)
SELECT
    e.TABLE_NAME,
    e.COLUMN_NAME,
    IFF(a.COLUMN_NAME IS NOT NULL, 'PASS', 'FAIL - COLUMN MISSING') AS STATUS
FROM expected_columns e
LEFT JOIN actual_columns a ON e.TABLE_NAME = a.TABLE_NAME AND e.COLUMN_NAME = a.COLUMN_NAME
ORDER BY e.TABLE_NAME, e.COLUMN_NAME;

-- 3. Check data integrity (rows exist and values are sensible)
SELECT 'STG_PAYMENTS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT,
       IFF(COUNT(*) >= 50000, 'PASS', 'FAIL - ROW COUNT LOW') AS STATUS
FROM ANALYTICS.STG_PAYMENTS
UNION ALL
SELECT 'STG_FEEDBACK', COUNT(*),
       IFF(COUNT(*) >= 1900, 'PASS', 'FAIL - ROW COUNT LOW')
FROM ANALYTICS.STG_FEEDBACK
UNION ALL
SELECT 'STG_CUSTOMERS', COUNT(*),
       IFF(COUNT(*) >= 30, 'PASS', 'FAIL - ROW COUNT LOW')
FROM ANALYTICS.STG_CUSTOMERS
UNION ALL
SELECT 'STG_ACCOUNTS', COUNT(*),
       IFF(COUNT(*) >= 36, 'PASS', 'FAIL - ROW COUNT LOW')
FROM ANALYTICS.STG_ACCOUNTS
UNION ALL
SELECT 'MART_PAYMENT_KPIS', COUNT(*),
       IFF(COUNT(*) > 100, 'PASS', 'FAIL - ROW COUNT LOW')
FROM ANALYTICS.MART_PAYMENT_KPIS
UNION ALL
SELECT 'MART_SLA_COMPLIANCE', COUNT(*),
       IFF(COUNT(*) > 10, 'PASS', 'FAIL - ROW COUNT LOW')
FROM ANALYTICS.MART_SLA_COMPLIANCE;

-- 4. Check SLA_STATUS contains only expected values
SELECT
    SLA_STATUS,
    COUNT(*) AS COUNT,
    IFF(SLA_STATUS IN ('COMPLIANT', 'AT RISK', 'BREACH'), 'PASS', 'FAIL - UNEXPECTED VALUE') AS STATUS
FROM ANALYTICS.MART_SLA_COMPLIANCE
GROUP BY SLA_STATUS;

-- 5. Base model verdict
SELECT
    IFF(
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES
         WHERE TABLE_SCHEMA='ANALYTICS'
         AND TABLE_NAME IN ('STG_PAYMENTS','STG_FEEDBACK','STG_CUSTOMERS','STG_ACCOUNTS',
                            'MART_PAYMENT_KPIS','MART_SLA_COMPLIANCE')) = 6
        AND (SELECT COUNT(*) FROM ANALYTICS.MART_SLA_COMPLIANCE
             WHERE SLA_STATUS IN ('COMPLIANT','AT RISK','BREACH')) > 0
        AND (SELECT COUNT(*) FROM ANALYTICS.MART_PAYMENT_KPIS
             WHERE SUCCESS_RATE_PCT BETWEEN 0 AND 100) > 0
        AND (SELECT COUNT(*) FROM ANALYTICS.STG_CUSTOMERS
             WHERE RM_NAME IS NOT NULL) > 0,
        '✅ BASE MODELS PASSED — proceed to Step 3b (Cortex Code)',
        '❌ VALIDATION FAILED — ask Cortex Code to fix the issues shown above'
    ) AS BASE_VERDICT;

-- =====================================================
-- 3b: CORTEX CODE MODEL VALIDATION
-- Run AFTER participants prompt CoCo to build the two new marts
-- =====================================================

-- 6. Check CoCo-built tables exist
WITH coco_tables AS (
    SELECT column1 AS TABLE_NAME FROM VALUES
        ('MART_CUSTOMER_PAYMENTS'),
        ('MART_RM_PERFORMANCE')
),
actual_tables AS (
    SELECT TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA = 'ANALYTICS'
)
SELECT
    e.TABLE_NAME,
    IFF(a.TABLE_NAME IS NOT NULL, 'PASS', 'FAIL - TABLE MISSING (has CoCo built it yet?)') AS STATUS
FROM coco_tables e
LEFT JOIN actual_tables a ON e.TABLE_NAME = a.TABLE_NAME;

-- 7. Spot-check CoCo models have sensible data
SELECT 'MART_CUSTOMER_PAYMENTS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT,
       IFF(COUNT(*) > 0, 'PASS', 'FAIL - NO DATA') AS STATUS
FROM ANALYTICS.MART_CUSTOMER_PAYMENTS
UNION ALL
SELECT 'MART_RM_PERFORMANCE', COUNT(*),
       IFF(COUNT(*) > 0, 'PASS', 'FAIL - NO DATA')
FROM ANALYTICS.MART_RM_PERFORMANCE;

-- 8. Final verdict (all models)
SELECT
    IFF(
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES
         WHERE TABLE_SCHEMA='ANALYTICS'
         AND TABLE_NAME IN ('STG_PAYMENTS','STG_FEEDBACK','STG_CUSTOMERS','STG_ACCOUNTS',
                            'MART_PAYMENT_KPIS','MART_SLA_COMPLIANCE',
                            'MART_CUSTOMER_PAYMENTS','MART_RM_PERFORMANCE')) = 8,
        '✅ ALL MODELS PASSED — proceed to Step 4',
        '❌ SOME MODELS MISSING — check output above'
    ) AS FINAL_VERDICT;
