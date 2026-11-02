-- models/staging/stg_feedback.sql
-- Cleans and type-casts the raw CUSTOMER_FEEDBACK table

WITH source AS (
    SELECT * FROM {{ source('raw_data', 'customer_feedback') }}
)

SELECT
    FEEDBACK_ID,
    FEEDBACK_DATE::TIMESTAMP            AS FEEDBACK_DATE,
    DATE_TRUNC('DAY', FEEDBACK_DATE)    AS FEEDBACK_DAY,
    CUSTOMER_ID,
    PAYMENT_ID,
    UPPER(TRIM(FEEDBACK_CHANNEL))       AS FEEDBACK_CHANNEL,
    TRIM(FEEDBACK_TEXT)                  AS FEEDBACK_TEXT,
    UPPER(TRIM(PAYMENT_TYPE))           AS PAYMENT_TYPE,
    RATING::NUMBER(1)                   AS RATING,

    -- Derived
    LENGTH(TRIM(FEEDBACK_TEXT))         AS FEEDBACK_LENGTH,
    CASE
        WHEN RATING >= 4 THEN 'SATISFIED'
        WHEN RATING = 3  THEN 'NEUTRAL'
        ELSE 'DISSATISFIED'
    END                                 AS SATISFACTION_TIER

FROM source
WHERE FEEDBACK_TEXT IS NOT NULL
  AND LENGTH(TRIM(FEEDBACK_TEXT)) > 0
