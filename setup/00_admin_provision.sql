-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - FACILITATOR SETUP
-- STEP 00: ROLES, DATABASE, WAREHOUSE, MARKETPLACE
--
-- Mirrors the Barclays enterprise data platform pattern:
--   * Source data is published centrally as Snowflake-managed Iceberg tables
--   * Participants have READ-ONLY access to RAW_DATA (they cannot load files)
--   * Participants build data products in ANALYTICS / AGENTS
--
-- Run once per lab account as ACCOUNTADMIN, then run:
--   01_seed_synthetic_data.sql   (as HOL_ADMIN)
--   02_publish_iceberg.sql       (as HOL_ADMIN)
-- =====================================================

USE ROLE ACCOUNTADMIN;

-- -----------------------------------------------------
-- 0.1 Roles
--   HOL_ADMIN       : platform team - owns RAW_DATA and SEED
--   HOL_PARTICIPANT : lab attendee  - reads RAW_DATA, builds in ANALYTICS
--   HOL_RESTRICTED  : used in GOV1 to demonstrate masking (no PII access)
-- -----------------------------------------------------
CREATE ROLE IF NOT EXISTS HOL_ADMIN       COMMENT = 'Barclays HOL - platform/data owner role';
CREATE ROLE IF NOT EXISTS HOL_PARTICIPANT COMMENT = 'Barclays HOL - attendee role (read raw, build analytics)';
CREATE ROLE IF NOT EXISTS HOL_RESTRICTED  COMMENT = 'Barclays HOL - restricted consumer role for governance demos';

GRANT ROLE HOL_RESTRICTED  TO ROLE HOL_PARTICIPANT;
GRANT ROLE HOL_PARTICIPANT TO ROLE HOL_ADMIN;
GRANT ROLE HOL_ADMIN       TO ROLE SYSADMIN;

-- -----------------------------------------------------
-- 0.2 Warehouse
-- -----------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS BARCLAYS_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for Barclays HOL';
GRANT USAGE, OPERATE ON WAREHOUSE BARCLAYS_WH TO ROLE HOL_PARTICIPANT;
GRANT USAGE ON WAREHOUSE BARCLAYS_WH TO ROLE HOL_RESTRICTED;
GRANT ALL ON WAREHOUSE BARCLAYS_WH TO ROLE HOL_ADMIN;

-- Give the installing user the admin role (attendees: 03_add_participants.sql).
-- A scripting block rather than a session variable, so this file also runs via
-- EXECUTE IMMEDIATE FROM (INSTALL.sql), which does not allow SET. Scripting
-- needs a warehouse, and service users (DataOps) have no default one.
USE WAREHOUSE BARCLAYS_WH;
EXECUTE IMMEDIATE $$
BEGIN
    EXECUTE IMMEDIATE 'GRANT ROLE HOL_ADMIN TO USER "' || REPLACE(CURRENT_USER(), '"', '""') || '"';
END;
$$;

-- -----------------------------------------------------
-- 0.3 Database and schemas
-- -----------------------------------------------------
CREATE DATABASE IF NOT EXISTS BARCLAYS_HOL
    COMMENT = 'Barclays Payments Data Product - Hands-on Lab v2 (synthetic data)';
GRANT OWNERSHIP ON DATABASE BARCLAYS_HOL TO ROLE HOL_ADMIN COPY CURRENT GRANTS;
-- Accounts can be reused (or hold an earlier version of the lab): take over any
-- schemas that already exist so the IF NOT EXISTS creates below are owned by HOL_ADMIN
GRANT OWNERSHIP ON ALL SCHEMAS IN DATABASE BARCLAYS_HOL TO ROLE HOL_ADMIN COPY CURRENT GRANTS;

USE ROLE HOL_ADMIN;
CREATE SCHEMA IF NOT EXISTS BARCLAYS_HOL.SEED      COMMENT = 'Platform team only: synthetic generator output (native tables)';
CREATE SCHEMA IF NOT EXISTS BARCLAYS_HOL.RAW_DATA  COMMENT = 'Published source data - Snowflake-managed Iceberg tables (read-only to attendees)';
CREATE SCHEMA IF NOT EXISTS BARCLAYS_HOL.ANALYTICS COMMENT = 'Attendee-built data products: dbt models, AI enrichment, dynamic tables, semantic views';
CREATE SCHEMA IF NOT EXISTS BARCLAYS_HOL.AGENTS    COMMENT = 'Attendee-built Cortex Agents, tools and MCP servers';
CREATE SCHEMA IF NOT EXISTS BARCLAYS_HOL.GOVERNANCE COMMENT = 'Tags, masking and row access policies';

GRANT USAGE ON DATABASE BARCLAYS_HOL TO ROLE HOL_PARTICIPANT;
GRANT USAGE ON DATABASE BARCLAYS_HOL TO ROLE HOL_RESTRICTED;

-- Read-only raw layer
GRANT USAGE ON SCHEMA BARCLAYS_HOL.RAW_DATA TO ROLE HOL_PARTICIPANT;
GRANT SELECT ON ALL ICEBERG TABLES    IN SCHEMA BARCLAYS_HOL.RAW_DATA TO ROLE HOL_PARTICIPANT;
GRANT SELECT ON FUTURE ICEBERG TABLES IN SCHEMA BARCLAYS_HOL.RAW_DATA TO ROLE HOL_PARTICIPANT;

-- Build layers
GRANT ALL ON SCHEMA BARCLAYS_HOL.ANALYTICS  TO ROLE HOL_PARTICIPANT;
GRANT ALL ON SCHEMA BARCLAYS_HOL.AGENTS     TO ROLE HOL_PARTICIPANT;
GRANT ALL ON SCHEMA BARCLAYS_HOL.GOVERNANCE TO ROLE HOL_PARTICIPANT;
GRANT USAGE ON SCHEMA BARCLAYS_HOL.ANALYTICS TO ROLE HOL_RESTRICTED;
GRANT USAGE ON SCHEMA BARCLAYS_HOL.GOVERNANCE TO ROLE HOL_RESTRICTED;   -- GOV1 consumer test
GRANT SELECT ON FUTURE TABLES IN SCHEMA BARCLAYS_HOL.ANALYTICS TO ROLE HOL_RESTRICTED;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA BARCLAYS_HOL.ANALYTICS TO ROLE HOL_RESTRICTED;

-- -----------------------------------------------------
-- 0.4 Account-level privileges used in vignettes
-- -----------------------------------------------------
USE ROLE ACCOUNTADMIN;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER       TO ROLE HOL_PARTICIPANT;
GRANT DATABASE ROLE SNOWFLAKE.GOVERNANCE_VIEWER TO ROLE HOL_PARTICIPANT;   -- GOV2 lineage/access history
GRANT DATABASE ROLE SNOWFLAKE.OBJECT_VIEWER     TO ROLE HOL_PARTICIPANT;   -- GOV2 object dependencies
GRANT DATABASE ROLE SNOWFLAKE.DATA_METRIC_USER  TO ROLE HOL_PARTICIPANT;   -- DE2 data metric functions
GRANT EXECUTE DATA METRIC FUNCTION ON ACCOUNT   TO ROLE HOL_PARTICIPANT;
GRANT APPLY MASKING POLICY    ON ACCOUNT TO ROLE HOL_PARTICIPANT;          -- GOV1
GRANT APPLY ROW ACCESS POLICY ON ACCOUNT TO ROLE HOL_PARTICIPANT;
GRANT APPLY TAG               ON ACCOUNT TO ROLE HOL_PARTICIPANT;
GRANT CREATE DATABASE ON ACCOUNT TO ROLE HOL_ADMIN;

-- Snowflake Intelligence: make attendee agents discoverable
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS;
GRANT USAGE ON DATABASE SNOWFLAKE_INTELLIGENCE TO ROLE HOL_PARTICIPANT;
GRANT USAGE, CREATE AGENT ON SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS TO ROLE HOL_PARTICIPANT;

-- -----------------------------------------------------
-- 0.5 Marketplace: Cortex Knowledge Extension (AI3)
-- Barclays has not approved Cortex Search over internal (PII) data.
-- A Knowledge Extension is a provider-hosted, pre-built search service:
-- no Barclays data is vectorised. Snowflake Documentation is used here;
-- swap for a finance publisher (e.g. Investopedia) if it has been
-- requested and approved in Snowsight for the lab account.
-- -----------------------------------------------------
CALL SYSTEM$ACCEPT_LEGAL_TERMS('DATA_EXCHANGE_LISTING', 'GZSTZ67BY9OQ4');
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_DOCS_CKE FROM LISTING 'GZSTZ67BY9OQ4';
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_DOCS_CKE TO ROLE HOL_PARTICIPANT;

SELECT 'Setup 00 complete - now run 01_seed_synthetic_data.sql as HOL_ADMIN' AS STATUS;
