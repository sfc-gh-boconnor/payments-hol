-- models/marts/mart_sla_compliance.sql
-- Daily SLA compliance per payment scheme
-- Aggregates KPIs back to scheme+day level before joining SLA thresholds

WITH kpis AS (
    SELECT * FROM {{ ref('mart_payment_kpis') }}
),

daily_scheme AS (
    SELECT
        PAYMENT_DAY,
        PAYMENT_TYPE,
        SUM(TOTAL_PAYMENTS)       AS TOTAL_PAYMENTS,
        SUM(SUCCESSFUL_PAYMENTS)  AS SUCCESSFUL_PAYMENTS,
        SUM(FAILED_PAYMENTS)      AS FAILED_PAYMENTS,
        ROUND(
            SUM(SUCCESSFUL_PAYMENTS)::FLOAT / NULLIF(SUM(TOTAL_PAYMENTS), 0) * 100, 2
        )                         AS SUCCESS_RATE_PCT,
        ROUND(
            SUM(AVG_PROCESSING_TIME_MS * TOTAL_PAYMENTS)::FLOAT / NULLIF(SUM(TOTAL_PAYMENTS), 0), 0
        )                         AS AVG_PROCESSING_TIME_MS,
        MAX(P95_PROCESSING_TIME_MS) AS P95_PROCESSING_TIME_MS
    FROM kpis
    GROUP BY PAYMENT_DAY, PAYMENT_TYPE
),

sla_defs AS (
    SELECT * FROM {{ source('raw_data', 'sla_definitions') }}
)

SELECT
    d.PAYMENT_DAY,
    d.PAYMENT_TYPE,
    s.SLA_NAME,

    -- Targets
    s.TARGET_SUCCESS_RATE   AS SLA_TARGET_PCT,
    s.MAX_PROCESSING_TIME_MS AS SLA_THRESHOLD_MS,

    -- Actuals
    d.SUCCESS_RATE_PCT      AS ACTUAL_SUCCESS_RATE,
    d.P95_PROCESSING_TIME_MS AS ACTUAL_P95_MS,
    d.TOTAL_PAYMENTS,
    d.FAILED_PAYMENTS,

    -- Compliance verdict
    CASE
        WHEN d.SUCCESS_RATE_PCT   >= s.TARGET_SUCCESS_RATE
         AND d.P95_PROCESSING_TIME_MS <= s.MAX_PROCESSING_TIME_MS THEN 'COMPLIANT'
        WHEN d.SUCCESS_RATE_PCT   >= s.TARGET_SUCCESS_RATE * 0.95  THEN 'AT RISK'
        ELSE 'BREACH'
    END                     AS SLA_STATUS,

    -- Gap metrics
    ROUND(d.SUCCESS_RATE_PCT    - s.TARGET_SUCCESS_RATE,     2) AS RATE_GAP_PCT,
    d.P95_PROCESSING_TIME_MS    - s.MAX_PROCESSING_TIME_MS      AS TIME_GAP_MS

FROM daily_scheme d
JOIN sla_defs s ON d.PAYMENT_TYPE = s.PAYMENT_TYPE
