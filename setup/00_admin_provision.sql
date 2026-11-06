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
-- DE2 Pipeline Builder: runs task graphs; notebook/Python tasks need code bundles
GRANT EXECUTE TASK                 ON ACCOUNT   TO ROLE HOL_PARTICIPANT;
GRANT CREATE CODE BUNDLE ON SCHEMA BARCLAYS_HOL.ANALYTICS TO ROLE HOL_PARTICIPANT;
-- DA3 map app: Streamlit container runtime (Carto basemaps without External Offerings Terms)
GRANT USAGE ON COMPUTE POOL SYSTEM_COMPUTE_POOL_CPU TO ROLE HOL_PARTICIPANT;
-- Container runtime installs streamlit/pydeck from PyPI, so it needs external access
CREATE NETWORK RULE IF NOT EXISTS BARCLAYS_HOL.ANALYTICS.PYPI_NETWORK_RULE MODE = EGRESS TYPE = HOST_PORT
  VALUE_LIST = ('pypi.org', 'pypi.python.org', 'pythonhosted.org', 'files.pythonhosted.org');
CREATE EXTERNAL ACCESS INTEGRATION IF NOT EXISTS PYPI_ACCESS_INTEGRATION
  ALLOWED_NETWORK_RULES = (BARCLAYS_HOL.ANALYTICS.PYPI_NETWORK_RULE) ENABLED = TRUE;
GRANT USAGE ON INTEGRATION PYPI_ACCESS_INTEGRATION TO ROLE HOL_PARTICIPANT;
GRANT APPLY MASKING POLICY    ON ACCOUNT TO ROLE HOL_PARTICIPANT;          -- GOV1
GRANT APPLY ROW ACCESS POLICY ON ACCOUNT TO ROLE HOL_PARTICIPANT;
GRANT APPLY TAG               ON ACCOUNT TO ROLE HOL_PARTICIPANT;
GRANT CREATE DATABASE ON ACCOUNT TO ROLE HOL_ADMIN;

-- GOV3 AI governance: the app (HOL_ADMIN) reads every user's gateway traces for checks
GRANT MONITOR ON AI GATEWAY SNOWFLAKE TO ROLE HOL_ADMIN;

-- DE3 real-time analytics: attendees stream into REALTIME and serve it from one shared
-- interactive warehouse. It's created suspended; once resumed it bills for at least
-- 24 hours (AUTO_SUSPEND minimum 86400), so the facilitator suspends it after the lab.
CREATE SCHEMA IF NOT EXISTS BARCLAYS_HOL.REALTIME COMMENT = 'DE3: incident detection on payments mirrored from Snowflake Postgres';
GRANT OWNERSHIP ON SCHEMA BARCLAYS_HOL.REALTIME TO ROLE HOL_ADMIN COPY CURRENT GRANTS;
GRANT ALL ON SCHEMA BARCLAYS_HOL.REALTIME TO ROLE HOL_PARTICIPANT;

-- Attendee schemas: whatever role a session runs as, what attendees build is owned by
-- HOL_PARTICIPANT. Event logins also hold ACCOUNTADMIN, so a Workspace or notebook session
-- can create objects as ACCOUNTADMIN that HOL_PARTICIPANT then can't use ("already exists,
-- but current role has no privileges on it"). Also hands over anything already created
-- under another role, so rerunning this script repairs an account. (Streamlit apps have
-- no future grant; DA3 creates its app as HOL_PARTICIPANT.)
EXECUTE IMMEDIATE $$
DECLARE
  schemas ARRAY DEFAULT ['ANALYTICS', 'AGENTS', 'GOVERNANCE', 'REALTIME'];
  kinds ARRAY DEFAULT ['TABLES', 'DYNAMIC TABLES', 'VIEWS', 'SEMANTIC VIEWS', 'FUNCTIONS', 'PROCEDURES',
                       'TASKS', 'STAGES', 'NOTEBOOKS', 'AGENTS', 'MCP SERVERS', 'CORTEX SEARCH SERVICES'];
  existing ARRAY DEFAULT ['TABLES', 'DYNAMIC TABLES', 'VIEWS'];
  s STRING;
  k STRING;
BEGIN
  FOR i IN 0 TO ARRAY_SIZE(:schemas) - 1 DO
    s := 'BARCLAYS_HOL.' || :schemas[i];
    FOR j IN 0 TO ARRAY_SIZE(:kinds) - 1 DO
      k := :kinds[j];
      BEGIN
        EXECUTE IMMEDIATE 'GRANT OWNERSHIP ON FUTURE ' || :k || ' IN SCHEMA ' || :s || ' TO ROLE HOL_PARTICIPANT';
      EXCEPTION
        -- a rerun: the future grant is already there
        WHEN STATEMENT_ERROR THEN
          IF (NOT CONTAINS(SQLERRM, 'already exists')) THEN
            RAISE;
          END IF;
      END;
    END FOR;
    FOR j IN 0 TO ARRAY_SIZE(:existing) - 1 DO
      k := :existing[j];
      EXECUTE IMMEDIATE 'GRANT OWNERSHIP ON ALL ' || :k || ' IN SCHEMA ' || :s || ' TO ROLE HOL_PARTICIPANT COPY CURRENT GRANTS';
    END FOR;
  END FOR;
  RETURN 'attendee schema ownership set';
END;
$$;
CREATE INTERACTIVE WAREHOUSE IF NOT EXISTS HOL_INTERACTIVE_WH
  WAREHOUSE_SIZE = XSMALL INITIALLY_SUSPENDED = TRUE AUTO_RESUME = TRUE
  COMMENT = 'DE3 shared interactive warehouse: suspend after the lab (24 h minimum once resumed)';
GRANT USAGE ON WAREHOUSE HOL_INTERACTIVE_WH TO ROLE HOL_PARTICIPANT;
-- CREATE WAREHOUSE makes it current; scripts and procedures can't run on an interactive warehouse
USE WAREHOUSE BARCLAYS_WH;

-- GOV3/DE3 notebooks call the account's own public endpoint (AI gateway) and Snowflake Postgres
-- (DE3, any instance host on 5432), and install packages from PyPI, so they need external access to all three
EXECUTE IMMEDIATE $$
DECLARE
  account_host STRING DEFAULT (SELECT LOWER(CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME()) || '.snowflakecomputing.com');
BEGIN
  EXECUTE IMMEDIATE 'CREATE OR REPLACE NETWORK RULE BARCLAYS_HOL.ANALYTICS.HOL_NOTEBOOK_EGRESS_RULE MODE = EGRESS TYPE = HOST_PORT VALUE_LIST = ('''
    || :account_host || ''', ''' || REPLACE(:account_host, '_', '-') || ''', ''pypi.org'', ''pypi.python.org'', ''pythonhosted.org'', ''files.pythonhosted.org'', ''*.postgres.snowflake.app:5432'')';
END;
$$;
CREATE EXTERNAL ACCESS INTEGRATION IF NOT EXISTS HOL_NOTEBOOK_ACCESS_INTEGRATION
  ALLOWED_NETWORK_RULES = (BARCLAYS_HOL.ANALYTICS.HOL_NOTEBOOK_EGRESS_RULE) ENABLED = TRUE
  COMMENT = 'GOV3/DE3 notebooks: this account''s endpoint (AI gateway), Snowflake Postgres and PyPI';
GRANT USAGE ON INTEGRATION HOL_NOTEBOOK_ACCESS_INTEGRATION TO ROLE HOL_PARTICIPANT;

-- DE3 streaming source: each attendee creates Snowflake Postgres instance HOL_PAYMENTS_PG and
-- mirrors it into Snowflake-managed Iceberg (Snowpipe Streaming can't sign in from a notebook).
-- Mirroring needs STANDARD (not BURSTABLE) compute; the instance bills while it runs.
GRANT CREATE POSTGRES INSTANCE ON ACCOUNT TO ROLE HOL_PARTICIPANT;
GRANT APPLICATION ROLE SNOWFLAKE.POSTGRES_MIRROR_ADMIN TO ROLE HOL_PARTICIPANT;
-- Inbound to Postgres from notebooks and laptops (lab only: open to any IPv4 address)
CREATE NETWORK RULE IF NOT EXISTS BARCLAYS_HOL.REALTIME.HOL_PG_INGRESS_RULE
  TYPE = IPV4 MODE = POSTGRES_INGRESS VALUE_LIST = ('0.0.0.0/0')
  COMMENT = 'DE3: who may connect to the lab Postgres instance';
CREATE NETWORK POLICY IF NOT EXISTS HOL_PG_POLICY
  ALLOWED_NETWORK_RULE_LIST = ('BARCLAYS_HOL.REALTIME.HOL_PG_INGRESS_RULE')
  COMMENT = 'DE3: attach to HOL_PAYMENTS_PG';
GRANT USAGE ON NETWORK POLICY HOL_PG_POLICY TO ROLE HOL_PARTICIPANT;
-- The admin password appears once, in the CREATE output; the attendee's helper saves it here
-- (IF NOT EXISTS: a rerun must never wipe a saved password). The Lab Companion reveals it.
CREATE SECRET IF NOT EXISTS BARCLAYS_HOL.REALTIME.PG_ADMIN_SECRET
  TYPE = PASSWORD USERNAME = 'not-set' PASSWORD = 'not-set'
  COMMENT = 'DE3: HOL_PAYMENTS_PG snowflake_admin credentials, saved when the instance is created';
GRANT OWNERSHIP ON SECRET BARCLAYS_HOL.REALTIME.PG_ADMIN_SECRET TO ROLE HOL_PARTICIPANT COPY CURRENT GRANTS;
CREATE EXTERNAL ACCESS INTEGRATION IF NOT EXISTS HOL_PG_SECRET_INTEGRATION
  ALLOWED_NETWORK_RULES = (BARCLAYS_HOL.ANALYTICS.HOL_NOTEBOOK_EGRESS_RULE)
  ALLOWED_AUTHENTICATION_SECRETS = (BARCLAYS_HOL.REALTIME.PG_ADMIN_SECRET)
  ENABLED = TRUE
  COMMENT = 'DE3: lets the Lab Companion read PG_ADMIN_SECRET (reveal button)';
GRANT USAGE ON INTEGRATION HOL_PG_SECRET_INTEGRATION TO ROLE HOL_ADMIN;
USE ROLE HOL_ADMIN;
-- Owner's rights, owned by HOL_ADMIN (the app's role): attendees can't call it from SQL
CREATE OR REPLACE PROCEDURE BARCLAYS_HOL.LAB.PG_CONNECTION_INFO()
  RETURNS VARIANT LANGUAGE PYTHON RUNTIME_VERSION = '3.11' PACKAGES = ('snowflake-snowpark-python')
  HANDLER = 'run' EXTERNAL_ACCESS_INTEGRATIONS = (HOL_PG_SECRET_INTEGRATION)
  SECRETS = ('pg' = BARCLAYS_HOL.REALTIME.PG_ADMIN_SECRET)
  COMMENT = 'DE3: host, port, database, user and password for HOL_PAYMENTS_PG (Lab Companion reveal)'
  EXECUTE AS OWNER
AS $$
import _snowflake

def run(session):
    rows = session.sql("SHOW POSTGRES INSTANCES LIKE 'HOL_PAYMENTS_PG'").collect()
    if not rows:
        return {"ready": False, "message": "HOL_PAYMENTS_PG doesn't exist yet: run the create cell in the DE3 notebook."}
    row = rows[0].as_dict()
    cred = _snowflake.get_username_password("pg")
    if cred.password == "not-set":
        return {"ready": False, "state": row.get("state"),
                "message": "The password wasn't saved. Run the reset cell in the DE3 notebook."}
    return {"ready": row.get("state") == "READY", "state": row.get("state"), "host": row.get("host"),
            "port": 5432, "database": "postgres", "user": cred.username, "password": cred.password}
$$;
USE ROLE ACCOUNTADMIN;

-- Snowflake CoWork (formerly Snowflake Intelligence) lists agents in SNOWFLAKE_INTELLIGENCE.AGENTS
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
