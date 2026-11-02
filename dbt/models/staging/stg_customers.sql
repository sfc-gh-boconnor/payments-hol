-- models/staging/stg_customers.sql
-- Cleans CUSTOMERS and denormalises relationship manager details

WITH customers AS (
    SELECT * FROM {{ source('raw_data', 'customers') }}
),

rms AS (
    SELECT * FROM {{ source('raw_data', 'relationship_managers') }}
)

SELECT
    c.CUSTOMER_ID,
    UPPER(TRIM(c.CUSTOMER_NAME))        AS CUSTOMER_NAME,
    UPPER(TRIM(c.SECTOR))               AS SECTOR,
    c.COUNTRY,
    c.ONBOARDING_DATE,
    UPPER(TRIM(c.KYC_STATUS))           AS KYC_STATUS,
    c.RM_ID,

    -- Denormalised RM fields
    r.RM_NAME,
    r.TEAM                              AS RM_TEAM,
    r.REGION                            AS RM_REGION

FROM customers c
LEFT JOIN rms r ON c.RM_ID = r.RM_ID
