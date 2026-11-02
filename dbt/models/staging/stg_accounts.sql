-- models/staging/stg_accounts.sql
-- Cleans ACCOUNTS and denormalises customer name and sector

WITH accounts AS (
    SELECT * FROM {{ source('raw_data', 'accounts') }}
),

customers AS (
    SELECT * FROM {{ source('raw_data', 'customers') }}
)

SELECT
    a.ACCOUNT_ID,
    a.CUSTOMER_ID,
    a.SORT_CODE,
    a.ACCOUNT_NUMBER,
    a.IBAN,
    a.BIC,
    UPPER(TRIM(a.CURRENCY))             AS CURRENCY,
    UPPER(TRIM(a.ACCOUNT_TYPE))         AS ACCOUNT_TYPE,
    UPPER(TRIM(a.STATUS))               AS STATUS,
    a.OPENED_DATE,

    -- Denormalised customer fields
    c.CUSTOMER_NAME,
    c.SECTOR                            AS CUSTOMER_SECTOR

FROM accounts a
LEFT JOIN customers c ON a.CUSTOMER_ID = c.CUSTOMER_ID
