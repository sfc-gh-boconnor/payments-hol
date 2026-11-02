-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - GIT REPOSITORY
-- Connects the account to this lab's public GitHub repository so dbt and
-- attendee Workspaces can run straight from it. Run as ACCOUNTADMIN after
-- 00_admin_provision.sql (the attendee grants need HOL_PARTICIPANT).
-- provision_account.sh runs it; INSTALL.sql creates the same repo inline
-- first (it installs from it), then runs this file for the grants.
--
-- The repo lives in its own database so teardown can remove it separately.
-- =====================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS BARCLAYS_HOL_SETUP
    COMMENT = 'Barclays HOL - Git repository the lab is installed from';

CREATE API INTEGRATION IF NOT EXISTS BARCLAYS_HOL_GITHUB
    API_PROVIDER = GIT_HTTPS_API
    API_ALLOWED_PREFIXES = ('https://github.com/')
    ENABLED = TRUE
    COMMENT = 'Barclays HOL - read the public lab repository';

-- Change the URL here (and in INSTALL.sql) if the lab is published elsewhere
CREATE GIT REPOSITORY IF NOT EXISTS BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO
    API_INTEGRATION = BARCLAYS_HOL_GITHUB
    ORIGIN = 'https://github.com/sfc-gh-boconnor/payments-hol.git'
    COMMENT = 'Barclays Payments HOL v2 source';

ALTER GIT REPOSITORY BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO FETCH;

-- Attendees open a Workspace from this repo, and own the dbt project built from it
GRANT USAGE ON INTEGRATION BARCLAYS_HOL_GITHUB TO ROLE HOL_PARTICIPANT;
GRANT USAGE ON DATABASE BARCLAYS_HOL_SETUP TO ROLE HOL_PARTICIPANT;
GRANT USAGE ON SCHEMA BARCLAYS_HOL_SETUP.PUBLIC TO ROLE HOL_PARTICIPANT;
GRANT READ ON GIT REPOSITORY BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO TO ROLE HOL_PARTICIPANT;
