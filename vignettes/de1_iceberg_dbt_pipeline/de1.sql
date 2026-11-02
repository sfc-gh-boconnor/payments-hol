-- =====================================================
-- VIGNETTE DE1: ICEBERG + dbt PIPELINE WITH CORTEX CODE   (~60 min)
-- Persona: Data Engineer
-- Question: "Turn the published Iceberg sources into governed, tested
--            data products - and publish them back to the lake as Iceberg."
-- Prereq:   Core C1 only. (Produces everything core_analytics.sql would.)
--
-- Work in the lab Workspace payments-hol (Projects > Workspaces), which is
-- already in your account. On your own account, create one from
-- https://github.com/sfc-gh-boconnor/payments-hol (Projects > Workspaces >
-- From Git repository).
-- =====================================================

USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;   -- see exactly what an attendee sees
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.ANALYTICS;

-- -----------------------------------------------------
-- DE1.1 Walk the dbt project (Workspace file explorer: dbt/)
--   models/staging/schema.yml  - sources point at BARCLAYS_HOL.RAW_DATA (Iceberg)
--   models/staging/*.sql       - 4 views: cast, clean, denormalise
--   models/marts/*.sql         - mart_payment_kpis, mart_sla_compliance
--   macros/generate_schema_name.sql - land models in ANALYTICS, not ANALYTICS_ANALYTICS
-- dbt reads Iceberg sources exactly like native tables. No code changes.
-- -----------------------------------------------------

-- -----------------------------------------------------
-- DE1.2 Deploy and run as a dbt Project on Snowflake
-- In the Workspace: select dbt/ > Deploy > name BARCLAYS_DBT, then Run > build.
-- Or from SQL / a task (this is how you would schedule it in production):
-- (Facilitator: the project object is created by `snow dbt deploy` or the Workspace.)
-- -----------------------------------------------------
EXECUTE DBT PROJECT BARCLAYS_HOL.ANALYTICS.BARCLAYS_DBT ARGS = 'build';
-- Expect: Done. PASS=27 WARN=0 ERROR=0

-- Schedule it - one task, no external orchestrator
CREATE OR REPLACE TASK TSK_DBT_NIGHTLY_BUILD
    WAREHOUSE = BARCLAYS_WH
    SCHEDULE  = 'USING CRON 0 5 * * * Europe/London'
AS
    EXECUTE DBT PROJECT BARCLAYS_HOL.ANALYTICS.BARCLAYS_DBT ARGS = 'build';
-- Left suspended for the lab. In production: ALTER TASK TSK_DBT_NIGHTLY_BUILD RESUME;

-- -----------------------------------------------------
-- DE1.3 Accelerate with Cortex Code (CoCo panel in the Workspace)
-- Prompt 1:
--   "Create a dbt mart model mart_customer_payments in dbt/models/marts that
--    summarises payment activity per customer: total payments, total volume,
--    success rate and most-used payment scheme. Join stg_payments -> stg_accounts
--    -> stg_customers and follow the patterns in mart_payment_kpis.sql."
-- Prompt 2:
--   "Create mart_rm_performance: one row per relationship manager with rm_id,
--    rm_name, client_count, total volume, average success rate and their client
--    with the lowest success rate. Then run dbt build and fix any failing tests."
-- The tests for both models already exist in models/marts/schema.yml, so
-- `dbt build` proves CoCo's code is correct.
-- -----------------------------------------------------

-- -----------------------------------------------------
-- DE1.4 Validate
-- -----------------------------------------------------
SELECT 'STG_PAYMENTS' AS OBJ, COUNT(*) AS ROWS_ FROM STG_PAYMENTS
UNION ALL SELECT 'MART_PAYMENT_KPIS',   COUNT(*) FROM MART_PAYMENT_KPIS
UNION ALL SELECT 'MART_SLA_COMPLIANCE', COUNT(*) FROM MART_SLA_COMPLIANCE;

SELECT SLA_STATUS, COUNT(*) AS SCHEME_DAYS
FROM MART_SLA_COMPLIANCE GROUP BY SLA_STATUS ORDER BY SCHEME_DAYS DESC;

-- -----------------------------------------------------
-- DE1.5 Publish the data product back to the lake as Iceberg
-- Consumers on other engines (Spark, Trino, etc.) can now read the mart with no copy.
-- Iceberg stores microsecond precision, so timestamps are cast to scale 6.
-- -----------------------------------------------------
CREATE OR REPLACE ICEBERG TABLE DP_SLA_COMPLIANCE
    CATALOG = 'SNOWFLAKE'
    COMMENT = 'Data product: daily SLA compliance per payment scheme (Iceberg)'
AS SELECT * REPLACE (PAYMENT_DAY::TIMESTAMP_NTZ(6) AS PAYMENT_DAY)
   FROM MART_SLA_COMPLIANCE;

SELECT SYSTEM$GET_ICEBERG_TABLE_INFORMATION('BARCLAYS_HOL.ANALYTICS.DP_SLA_COMPLIANCE') AS METADATA_LOCATION;

-- Barclayflake note: in production the Iceberg table would use the bank's
-- EXTERNAL_VOLUME (one volume and one IAM role, shared across accounts)
-- instead of Snowflake-managed storage. The SQL above is otherwise unchanged.

SELECT 'DE1 complete' AS STATUS;
