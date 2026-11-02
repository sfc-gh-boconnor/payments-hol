-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - TEARDOWN (facilitator)
-- Removes everything the lab created. Run as ACCOUNTADMIN.
-- First remove the Lab Companion app (from the repo root):
--   (cd lab-companion && snow app teardown --force --connection <conn> --role HOL_ADMIN)
-- =====================================================

USE ROLE ACCOUNTADMIN;

-- Agents published to Snowflake Intelligence
DROP AGENT IF EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS.CORPORATE_PAYMENTS_360;
DROP AGENT IF EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS.PAYMENTS_PLATFORM_COPILOT;

-- Policies must be detached before the objects they protect can be dropped cleanly
ALTER TAG IF EXISTS BARCLAYS_HOL.GOVERNANCE.DATA_SENSITIVITY UNSET MASKING POLICY BARCLAYS_HOL.GOVERNANCE.MASK_RESTRICTED_STRING;
DROP TABLE IF EXISTS BARCLAYS_HOL.GOVERNANCE.ACCOUNT_REGISTER;

-- Lab database (Iceberg tables on Snowflake-managed storage are dropped with it)
DROP APPLICATION SERVICE IF EXISTS BARCLAYS_HOL.LAB.LAB_COMPANION;
DROP DATABASE IF EXISTS BARCLAYS_HOL;

-- Marketplace knowledge extension (re-install with setup/00 if needed)
DROP DATABASE IF EXISTS SNOWFLAKE_DOCS_CKE;

DROP WAREHOUSE IF EXISTS BARCLAYS_WH;

DROP ROLE IF EXISTS HOL_RESTRICTED;
DROP ROLE IF EXISTS HOL_PARTICIPANT;
DROP ROLE IF EXISTS HOL_ADMIN;

-- SNOWFLAKE_INTELLIGENCE database is shared account infrastructure - left in place.

SELECT 'Teardown complete' AS STATUS;
