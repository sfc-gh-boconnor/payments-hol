-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - FACILITATOR SETUP
-- STEP 04: LAB COMPANION APP PREREQUISITES
-- Schema, progress table and grants for the Lab Companion app
-- (React app on Snowflake App Runtime, deployed with `snow app deploy`
-- from lab-companion/ - see README "Facilitator setup").
-- =====================================================

USE ROLE ACCOUNTADMIN;

-- Snowflake App Runtime: the app is owned by HOL_ADMIN so its checks can see
-- everything attendees build (HOL_PARTICIPANT is granted to HOL_ADMIN).
-- Older accounts may lack BIND SERVICE ENDPOINT on PUBLIC; grant to the deployer.
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE HOL_ADMIN;

USE ROLE HOL_ADMIN;
CREATE SCHEMA IF NOT EXISTS BARCLAYS_HOL.LAB
    COMMENT = 'Lab Companion app: application service, check results and progress';

CREATE TABLE IF NOT EXISTS BARCLAYS_HOL.LAB.LAB_PROGRESS (
    USER_NAME   STRING        NOT NULL,
    CHECK_ID    STRING        NOT NULL,
    MODULE_CODE STRING        NOT NULL,
    PASSED      BOOLEAN       NOT NULL,
    DETAIL      STRING,
    CHECKED_AT  TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'Every Check my work result from the Lab Companion app';

-- Attendees never touch LAB directly - the app writes on their behalf
-- (owner's rights) and records who ran each check.
