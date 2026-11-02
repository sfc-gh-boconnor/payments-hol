-- models/marts/mart_payment_kpis.sql
-- Daily payment KPIs by scheme, region, customer sector, and RM
-- Joins through the full entity chain: payments → accounts → customers (includes RM)

WITH payments AS (
    SELECT * FROM {{ ref('stg_payments') }}
),

accounts AS (
    SELECT * FROM {{ ref('stg_accounts') }}
),

customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
)

SELECT
    p.PAYMENT_DAY,
    p.PAYMENT_TYPE,
    p.REGION,
    p.CHANNEL,
    c.SECTOR            AS CUSTOMER_SECTOR,
    c.RM_NAME,
    c.RM_TEAM,

    -- Volume
    COUNT(*)                                                            AS TOTAL_PAYMENTS,
    SUM(p.AMOUNT)                                                       AS TOTAL_VOLUME_GBP,
    ROUND(AVG(p.AMOUNT), 2)                                             AS AVG_PAYMENT_AMOUNT,

    -- Outcomes
    COUNT(CASE WHEN p.IS_SUCCESSFUL THEN 1 END)                         AS SUCCESSFUL_PAYMENTS,
    COUNT(CASE WHEN p.IS_FAILED     THEN 1 END)                         AS FAILED_PAYMENTS,

    -- Success rate
    ROUND(
        COUNT(CASE WHEN p.IS_SUCCESSFUL THEN 1 END)::FLOAT / NULLIF(COUNT(*), 0) * 100,
        2
    )                                                                   AS SUCCESS_RATE_PCT,

    -- Processing time
    ROUND(AVG(p.PROCESSING_TIME_MS), 0)                                 AS AVG_PROCESSING_TIME_MS,
    ROUND(
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY p.PROCESSING_TIME_MS),
        0
    )                                                                   AS P95_PROCESSING_TIME_MS

FROM payments p
LEFT JOIN accounts a ON p.ORIGINATOR_ACCOUNT_ID = a.ACCOUNT_ID
LEFT JOIN customers c ON a.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY p.PAYMENT_DAY, p.PAYMENT_TYPE, p.REGION, p.CHANNEL,
         c.SECTOR, c.RM_NAME, c.RM_TEAM
