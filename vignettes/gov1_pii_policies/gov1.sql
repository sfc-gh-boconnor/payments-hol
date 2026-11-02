-- =====================================================
-- VIGNETTE GOV1: CLASSIFY, TAG, MASK AND FILTER PII   (~45 min)
-- Persona: Governance / Risk / Data Owner
-- Question: "Prove that account identifiers are protected wherever they flow -
--            dashboards, semantic views and AI agents - and that people only
--            see the clients in their region."
-- Prereq:   setup/catchup/core_analytics.sql (STG_ACCOUNTS, STG_CUSTOMERS)
-- Uses:     HOL_RESTRICTED role (granted to HOL_PARTICIPANT) to test as a consumer
-- =====================================================

USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;   -- see exactly what an attendee sees
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.GOVERNANCE;

-- Reset (makes this script safe to run first time and to re-run)
CREATE TAG IF NOT EXISTS DATA_SENSITIVITY;
CREATE MASKING POLICY IF NOT EXISTS MASK_RESTRICTED_STRING AS (VAL STRING) RETURNS STRING -> VAL;
ALTER TAG DATA_SENSITIVITY UNSET MASKING POLICY MASK_RESTRICTED_STRING;
DROP TABLE IF EXISTS ACCOUNT_REGISTER;

-- -----------------------------------------------------
-- GOV1.1 Let Snowflake find the sensitive data
-- -----------------------------------------------------
CREATE OR REPLACE TABLE ACCOUNT_REGISTER AS
SELECT * FROM BARCLAYS_HOL.ANALYTICS.STG_ACCOUNTS;   -- governed copy we own, for the lab

CALL SYSTEM$CLASSIFY('BARCLAYS_HOL.GOVERNANCE.ACCOUNT_REGISTER', {'auto_tag': true});

SELECT COLUMN_NAME, TAG_NAME, TAG_VALUE
FROM TABLE(BARCLAYS_HOL.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
        'BARCLAYS_HOL.GOVERNANCE.ACCOUNT_REGISTER', 'table'))
ORDER BY COLUMN_NAME;

-- -----------------------------------------------------
-- GOV1.2 The bank's own tag taxonomy
-- -----------------------------------------------------
CREATE OR REPLACE TAG DATA_SENSITIVITY
    ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED'
    COMMENT = 'Barclays-style data sensitivity classification';

ALTER TABLE ACCOUNT_REGISTER MODIFY COLUMN IBAN           SET TAG DATA_SENSITIVITY = 'RESTRICTED';
ALTER TABLE ACCOUNT_REGISTER MODIFY COLUMN ACCOUNT_NUMBER SET TAG DATA_SENSITIVITY = 'RESTRICTED';
ALTER TABLE ACCOUNT_REGISTER MODIFY COLUMN SORT_CODE      SET TAG DATA_SENSITIVITY = 'CONFIDENTIAL';
ALTER TABLE ACCOUNT_REGISTER MODIFY COLUMN BIC            SET TAG DATA_SENSITIVITY = 'INTERNAL';

-- -----------------------------------------------------
-- GOV1.3 Tag-based masking: protect every column carrying the tag, now and in future
-- -----------------------------------------------------
CREATE OR REPLACE MASKING POLICY MASK_RESTRICTED_STRING AS (VAL STRING) RETURNS STRING ->
    CASE
        WHEN IS_ROLE_IN_SESSION('HOL_ADMIN') THEN VAL                              -- data owner
        WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('BARCLAYS_HOL.GOVERNANCE.DATA_SENSITIVITY') = 'CONFIDENTIAL'
             THEN REGEXP_REPLACE(VAL, '[0-9]', '*')                                 -- shape kept, digits hidden
        WHEN VAL IS NULL THEN NULL
        ELSE '****' || RIGHT(VAL, 4)                                               -- last 4 only
    END
    COMMENT = 'Masks RESTRICTED/CONFIDENTIAL strings for everyone except the data owner';

ALTER TAG DATA_SENSITIVITY SET MASKING POLICY MASK_RESTRICTED_STRING;
-- Note: the policy applies to every tagged value; INTERNAL and PUBLIC columns
-- fall through to last-4 here - refine the CASE for your own taxonomy.
ALTER TABLE ACCOUNT_REGISTER MODIFY COLUMN BIC UNSET TAG DATA_SENSITIVITY;

-- -----------------------------------------------------
-- GOV1.4 Row access: users only see clients for their region
-- -----------------------------------------------------
CREATE OR REPLACE TABLE REGION_ENTITLEMENTS (ROLE_NAME STRING, CURRENCY STRING);
INSERT INTO REGION_ENTITLEMENTS VALUES
    ('HOL_RESTRICTED', 'GBP');      -- UK desk: sterling accounts only

CREATE OR REPLACE ROW ACCESS POLICY RAP_ACCOUNT_REGION AS (ACCT_CURRENCY STRING) RETURNS BOOLEAN ->
    IS_ROLE_IN_SESSION('HOL_PARTICIPANT')   -- lab builders see all
    OR EXISTS (SELECT 1 FROM BARCLAYS_HOL.GOVERNANCE.REGION_ENTITLEMENTS e
               WHERE IS_ROLE_IN_SESSION(e.ROLE_NAME) AND e.CURRENCY = ACCT_CURRENCY);

ALTER TABLE ACCOUNT_REGISTER ADD ROW ACCESS POLICY RAP_ACCOUNT_REGION ON (CURRENCY);

-- (USAGE on the GOVERNANCE schema is granted to HOL_RESTRICTED by facilitator setup)
GRANT SELECT ON TABLE ACCOUNT_REGISTER TO ROLE HOL_RESTRICTED;

-- -----------------------------------------------------
-- GOV1.5 Test as each persona
-- -----------------------------------------------------
-- As the builder: all rows, but RESTRICTED values masked (not the data owner)
SELECT ACCOUNT_ID, CUSTOMER_NAME, CURRENCY, SORT_CODE, ACCOUNT_NUMBER, IBAN
FROM ACCOUNT_REGISTER ORDER BY ACCOUNT_ID LIMIT 8;

SELECT 'HOL_PARTICIPANT' AS AS_ROLE, COUNT(*) AS VISIBLE_ACCOUNTS FROM ACCOUNT_REGISTER;

-- As the restricted UK desk: GBP accounts only, masked
USE ROLE HOL_RESTRICTED;
SELECT ACCOUNT_ID, CUSTOMER_NAME, CURRENCY, SORT_CODE, ACCOUNT_NUMBER, IBAN
FROM BARCLAYS_HOL.GOVERNANCE.ACCOUNT_REGISTER ORDER BY ACCOUNT_ID LIMIT 8;
SELECT 'HOL_RESTRICTED' AS AS_ROLE, COUNT(*) AS VISIBLE_ACCOUNTS FROM BARCLAYS_HOL.GOVERNANCE.ACCOUNT_REGISTER;

USE ROLE HOL_PARTICIPANT;

-- -----------------------------------------------------
-- GOV1.6 Policies follow the data into AI
-- Ask CoCo or an agent built over ACCOUNT_REGISTER for "the IBAN for Royal Trust PLC":
-- the agent runs as YOUR role, so it only ever returns the masked value.
-- Bonus CoCo prompt:
--   "Show me every column in BARCLAYS_HOL tagged DATA_SENSITIVITY and the
--    masking policy protecting it."
-- -----------------------------------------------------

-- Barclayflake note: in production, tag + masking policies are owned by a central
-- governance role and applied to the Iceberg source tables themselves, so every
-- downstream view, dbt model, semantic view and agent inherits them automatically.

SELECT 'GOV1 complete' AS STATUS;
