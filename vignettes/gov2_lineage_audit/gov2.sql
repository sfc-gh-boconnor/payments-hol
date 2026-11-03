-- =====================================================
-- VIGNETTE GOV2: LINEAGE, AUDIT AND TRUST   (~30 min)
-- Persona: Governance / Risk / Audit
-- Question: "If a source Iceberg table changes, what breaks? And who - human
--            or AI agent - has been reading client data?"
-- Prereq:   C1 only. Uses the ready-made audit pack in BARCLAYS_HOL.AUDIT_PACK
--           (setup/06_audit_pack.sql); ask PAYMENTS_AUDIT_AGENT a few questions first.
-- Note:     ACCOUNT_USAGE views have up to ~3 hours latency. Run the
--           immediate checks first; revisit the history queries at the end of the day.
-- =====================================================

USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;   -- see exactly what an attendee sees
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.AUDIT_PACK;

-- -----------------------------------------------------
-- GOV2.1 Impact analysis: what depends on the PAYMENTS Iceberg table? (immediate)
-- Snowsight: Catalog > BARCLAYS_HOL > RAW_DATA > PAYMENTS > Lineage tab
-- -----------------------------------------------------
SELECT DISTANCE, TARGET_OBJECT_DOMAIN, TARGET_OBJECT_DATABASE || '.' || TARGET_OBJECT_SCHEMA || '.' || TARGET_OBJECT_NAME AS DOWNSTREAM_OBJECT
FROM TABLE(SNOWFLAKE.CORE.GET_LINEAGE('BARCLAYS_HOL.RAW_DATA.PAYMENTS', 'TABLE', 'DOWNSTREAM', 3))
ORDER BY DISTANCE, DOWNSTREAM_OBJECT;

-- And upstream: where do the agent's answers come from?
SELECT DISTANCE, SOURCE_OBJECT_DOMAIN, SOURCE_OBJECT_DATABASE || '.' || SOURCE_OBJECT_SCHEMA || '.' || SOURCE_OBJECT_NAME AS UPSTREAM_OBJECT
FROM TABLE(SNOWFLAKE.CORE.GET_LINEAGE('BARCLAYS_HOL.AUDIT_PACK.PAYMENTS_AUDIT_AGENT', 'CORTEX_AGENT', 'UPSTREAM', 3))
ORDER BY DISTANCE, UPSTREAM_OBJECT;
-- A row shown as ***.***.*** is an object in the lineage that your role has no
-- privileges on (here the platform team's SEED schema). Lineage never leaks
-- the existence of objects you are not entitled to see.

-- Object dependencies (views, dynamic tables, semantic views) - immediate
SELECT REFERENCING_OBJECT_NAME, REFERENCING_OBJECT_DOMAIN, REFERENCED_OBJECT_NAME
FROM SNOWFLAKE.ACCOUNT_USAGE.OBJECT_DEPENDENCIES
WHERE REFERENCED_DATABASE = 'BARCLAYS_HOL'
ORDER BY REFERENCED_OBJECT_NAME
LIMIT 50;

-- Make sure there is a restricted-column read to find
SELECT * FROM BARCLAYS_HOL.AUDIT_PACK.CLIENT_ACCOUNTS LIMIT 5;

-- -----------------------------------------------------
-- GOV2.2 Who accessed restricted columns? (ACCOUNT_USAGE latency applies)
-- -----------------------------------------------------
SELECT ah.QUERY_START_TIME, ah.USER_NAME,
       obj.value:objectName::STRING     AS OBJECT_NAME,
       col.value:columnName::STRING     AS COLUMN_NAME
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY ah,
     LATERAL FLATTEN(ah.BASE_OBJECTS_ACCESSED) obj,
     LATERAL FLATTEN(obj.value:columns) col
WHERE obj.value:objectName::STRING ILIKE 'BARCLAYS_HOL.%'
  AND col.value:columnName::STRING IN ('IBAN', 'ACCOUNT_NUMBER', 'SORT_CODE')
  AND ah.QUERY_START_TIME >= DATEADD('day', -1, CURRENT_TIMESTAMP())
ORDER BY ah.QUERY_START_TIME DESC
LIMIT 20;

-- -----------------------------------------------------
-- GOV2.3 What are our agents doing? Every agent call is observable
-- Snowsight: AI & ML > Agents > PAYMENTS_AUDIT_AGENT > Monitoring
-- -----------------------------------------------------
SELECT QUERY_TYPE, USER_NAME, ROLE_NAME, START_TIME, TOTAL_ELAPSED_TIME / 1000 AS SECONDS,
       LEFT(QUERY_TEXT, 120) AS QUERY_PREVIEW
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE DATABASE_NAME = 'BARCLAYS_HOL'
  AND QUERY_TEXT ILIKE '%SEMANTIC_VIEW%'
  AND START_TIME >= DATEADD('day', -1, CURRENT_TIMESTAMP())
ORDER BY START_TIME DESC
LIMIT 20;

-- -----------------------------------------------------
-- GOV2.4 Document the data product so humans and AI find the right thing
-- -----------------------------------------------------
COMMENT ON TABLE PAYMENT_SLA_DAILY IS
  'Daily SLA compliance per payment scheme. Owner: Payments Operations. Grain: day x scheme. Source: Iceberg RAW_DATA.PAYMENTS and RAW_DATA.SLA_DEFINITIONS.';
COMMENT ON COLUMN PAYMENT_SLA_DAILY.SLA_STATUS IS
  'COMPLIANT = met success-rate and P95 targets; AT RISK = within 5% of success target; BREACH = otherwise';

-- Ask CoCo:
--   "If I drop column PROCESSING_TIME_MS from BARCLAYS_HOL.RAW_DATA.PAYMENTS,
--    which downstream objects and agents break? Use lineage to check."
--   "Produce a one-page data product card for PAYMENT_SLA_DAILY: owner, grain,
--    lineage, quality checks, sensitivity tags and consumers."

-- Barclayflake note: Trust Center and Horizon Catalog surface the same lineage,
-- classification and access history centrally for the CDO / data office.

SELECT 'GOV2 complete' AS STATUS;
