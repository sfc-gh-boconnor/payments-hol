-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - ONE-SCRIPT INSTALL FOR ANY ACCOUNT
--
-- For accounts NOT pre-provisioned by DataOps. Paste this whole file into a
-- Snowsight SQL worksheet, choose a role of ACCOUNTADMIN and press Run All.
-- Takes about 10 minutes. Then install the Lab Companion (last section).
--
-- Everything runs from the lab's GitHub repository, so the SQL is exactly
-- what was tested. No laptop or CLI is needed for this part.
-- =====================================================

USE ROLE ACCOUNTADMIN;

-- -----------------------------------------------------
-- 1. Connect the account to the lab repository
-- -----------------------------------------------------
CREATE DATABASE IF NOT EXISTS BARCLAYS_HOL_SETUP
    COMMENT = 'Barclays HOL - Git repository the lab is installed from';

CREATE API INTEGRATION IF NOT EXISTS BARCLAYS_HOL_GITHUB
    API_PROVIDER = GIT_HTTPS_API
    API_ALLOWED_PREFIXES = ('https://github.com/')
    ENABLED = TRUE
    COMMENT = 'Barclays HOL - read the public lab repository';

CREATE GIT REPOSITORY IF NOT EXISTS BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO
    API_INTEGRATION = BARCLAYS_HOL_GITHUB
    ORIGIN = 'https://github.com/sfc-gh-boconnor/payments-hol.git'
    COMMENT = 'Barclays Payments HOL v2 source';

ALTER GIT REPOSITORY BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO FETCH;

-- -----------------------------------------------------
-- 2. Roles, warehouse, database, synthetic data, Iceberg sources
-- -----------------------------------------------------
EXECUTE IMMEDIATE FROM @BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO/branches/main/setup/00_admin_provision.sql;
EXECUTE IMMEDIATE FROM @BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO/branches/main/setup/01_seed_synthetic_data.sql;
EXECUTE IMMEDIATE FROM @BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO/branches/main/setup/02_publish_iceberg.sql;
EXECUTE IMMEDIATE FROM @BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO/branches/main/setup/git_repo.sql;  -- attendee access to the repo

-- -----------------------------------------------------
-- 3. Lab Companion prerequisites and wake procedures
-- -----------------------------------------------------
EXECUTE IMMEDIATE FROM @BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO/branches/main/setup/06_audit_pack.sql;   -- GOV2 audit pack
EXECUTE IMMEDIATE FROM @BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO/branches/main/setup/04_lab_companion.sql;
EXECUTE IMMEDIATE FROM @BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO/branches/main/setup/05_wake_schedule.sql;

-- -----------------------------------------------------
-- 4. dbt project (attendees run it in DE1)
-- -----------------------------------------------------
USE ROLE HOL_PARTICIPANT;
USE WAREHOUSE BARCLAYS_WH;
CREATE DBT PROJECT IF NOT EXISTS BARCLAYS_HOL.ANALYTICS.BARCLAYS_DBT
    FROM '@BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO/branches/main/dbt'
    COMMENT = 'Barclays Payments HOL dbt project';

-- -----------------------------------------------------
-- 5. Optional: reference build for the Payments Ops pathway or demos
--    (pre-builds analytics, semantic views and agents). Uncomment to run.
-- -----------------------------------------------------
-- USE ROLE ACCOUNTADMIN;
-- EXECUTE IMMEDIATE FROM @BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO/branches/main/setup/catchup/core_analytics.sql;
-- EXECUTE IMMEDIATE FROM @BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO/branches/main/setup/catchup/semantic_view_and_agent.sql;
-- EXECUTE IMMEDIATE FROM @BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO/branches/main/vignettes/da1_semantic_view_analyst/da1.sql;
-- EXECUTE IMMEDIATE FROM @BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO/branches/main/vignettes/ops1_payments_360_agent/ops1.sql;

-- -----------------------------------------------------
-- 6. Next: install the Lab Companion
-- The Lab Companion is the lab guide: pathways, instructions and live
-- Check my work against what each attendee has built. It is a React app on
-- Snowflake App Runtime, which is built with the Snowflake CLI, so this
-- last step runs from a laptop (Snowflake CLI 3.26+, ACCOUNTADMIN connection):
--
--   git clone https://github.com/sfc-gh-boconnor/payments-hol.git
--   cd payments-hol
--   ./setup/install_lab_companion.sh <snow-connection-name>
--
-- Or in Cortex Code: open the cloned repo and ask
--   "Run setup/install_lab_companion.sh on my connection"
-- The script prints the Lab Companion URL to share with attendees.
-- -----------------------------------------------------
USE ROLE ACCOUNTADMIN;
SELECT 'Lab data and objects installed. Next: run setup/install_lab_companion.sh to install the Lab Companion (see section 6).' AS STATUS;
