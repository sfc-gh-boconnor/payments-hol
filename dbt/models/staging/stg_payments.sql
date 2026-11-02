-- models/staging/stg_payments.sql
-- Cleans and type-casts the raw PAYMENTS table

WITH source AS (
    SELECT * FROM {{ source('raw_data', 'payments') }}
)

SELECT
    PAYMENT_ID,
    PAYMENT_DATE::TIMESTAMP                             AS PAYMENT_DATE,
    DATE_TRUNC('DAY', PAYMENT_DATE::TIMESTAMP)          AS PAYMENT_DAY,
    ORIGINATOR_ACCOUNT_ID,
    BENEFICIARY_ACCOUNT_ID,
    UPPER(TRIM(PAYMENT_TYPE))                           AS PAYMENT_TYPE,
    UPPER(TRIM(CHANNEL))                                AS CHANNEL,
    UPPER(TRIM(CURRENCY))                               AS CURRENCY,
    AMOUNT::NUMBER(15,2)                                AS AMOUNT,
    FX_RATE,
    UPPER(TRIM(STATUS))                                 AS STATUS,
    PROCESSING_TIME_MS::NUMBER                          AS PROCESSING_TIME_MS,
    ERROR_CODE,
    UPPER(TRIM(REGION))                                 AS REGION,
    SETTLEMENT_DATE,

    -- Derived flags
    CASE WHEN STATUS = 'COMPLETED' THEN TRUE ELSE FALSE END  AS IS_SUCCESSFUL,
    CASE WHEN STATUS = 'FAILED'    THEN TRUE ELSE FALSE END  AS IS_FAILED,
    CASE WHEN ERROR_CODE IS NOT NULL THEN TRUE ELSE FALSE END AS HAS_ERROR

FROM source
