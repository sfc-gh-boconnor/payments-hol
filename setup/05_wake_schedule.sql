-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - FACILITATOR SETUP
-- STEP 05: WAKE THE LAB COMPANION BEFORE THE LAB STARTS
--
-- Lab accounts are provisioned days in advance and the Lab Companion app
-- (and warehouse) may be suspended by then. This creates:
--   WAKE_LAB()                      resume app + warehouse, disable auto-suspend
--   SLEEP_LAB()                     re-enable auto-suspend after the lab
--   SCHEDULE_LAB(start, end, lead)  serverless tasks that call them on time
-- Facilitator manual override on the day:  CALL BARCLAYS_HOL.LAB.WAKE_LAB();
--
-- Run as ACCOUNTADMIN after 04_lab_companion.sql and the app deploy.
-- This file only creates the procedures. Schedule the lab with SCHEDULE_LAB
-- (example at the bottom), or let provision_account.sh do it from LAB_START /
-- LAB_END or the DataOps EVENT_START_DATETIME / EVENT_END_DATETIME
-- (see dataops-integration/).
-- =====================================================

USE ROLE ACCOUNTADMIN;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE HOL_ADMIN;
GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE HOL_ADMIN;

USE ROLE HOL_ADMIN;
USE SCHEMA BARCLAYS_HOL.LAB;

CREATE OR REPLACE PROCEDURE WAKE_LAB()
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Resume the Lab Companion app and lab warehouse, and keep the app awake for the lab'
EXECUTE AS OWNER
AS
$$
BEGIN
    ALTER APPLICATION SERVICE IF EXISTS BARCLAYS_HOL.LAB.LAB_COMPANION RESUME;
    ALTER APPLICATION SERVICE IF EXISTS BARCLAYS_HOL.LAB.LAB_COMPANION SET AUTO_SUSPEND_SECS = 0;
    ALTER WAREHOUSE IF EXISTS BARCLAYS_WH RESUME IF SUSPENDED;
    RETURN 'Lab awake at ' || CURRENT_TIMESTAMP()::STRING;
END;
$$;

CREATE OR REPLACE PROCEDURE SLEEP_LAB(IDLE_SECS NUMBER DEFAULT 1800)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Re-enable auto-suspend on the Lab Companion app after the lab'
EXECUTE AS OWNER
AS
$$
BEGIN
    ALTER APPLICATION SERVICE IF EXISTS BARCLAYS_HOL.LAB.LAB_COMPANION SET AUTO_SUSPEND_SECS = :IDLE_SECS;
    -- The cron has day + month, so it would fire again next year: suspend both tasks
    ALTER TASK IF EXISTS BARCLAYS_HOL.LAB.LAB_WAKE_TASK SUSPEND;
    ALTER TASK IF EXISTS BARCLAYS_HOL.LAB.LAB_SLEEP_TASK SUSPEND;
    RETURN 'Auto-suspend set to ' || :IDLE_SECS || 's at ' || CURRENT_TIMESTAMP()::STRING;
END;
$$;

-- Creates two one-shot serverless tasks from the event times.
-- Cron is computed in UTC, so any input time zone works.
CREATE OR REPLACE PROCEDURE SCHEDULE_LAB(LAB_START TIMESTAMP_TZ, LAB_END TIMESTAMP_TZ, LEAD_MINUTES NUMBER DEFAULT 30)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Schedule WAKE_LAB before the lab and SLEEP_LAB after it'
EXECUTE AS OWNER
AS
$$
DECLARE
    wake_at TIMESTAMP_NTZ;
    sleep_at TIMESTAMP_NTZ;
    wake_cron STRING;
    sleep_cron STRING;
BEGIN
    wake_at  := CONVERT_TIMEZONE('UTC', DATEADD('minute', -1 * :LEAD_MINUTES, :LAB_START))::TIMESTAMP_NTZ;
    sleep_at := CONVERT_TIMEZONE('UTC', DATEADD('minute', 30, :LAB_END))::TIMESTAMP_NTZ;
    wake_cron  := 'USING CRON ' || MINUTE(wake_at)  || ' ' || HOUR(wake_at)  || ' ' || DAY(wake_at)  || ' ' || MONTH(wake_at)  || ' * UTC';
    sleep_cron := 'USING CRON ' || MINUTE(sleep_at) || ' ' || HOUR(sleep_at) || ' ' || DAY(sleep_at) || ' ' || MONTH(sleep_at) || ' * UTC';

    EXECUTE IMMEDIATE 'CREATE OR REPLACE TASK BARCLAYS_HOL.LAB.LAB_WAKE_TASK
        SCHEDULE = ''' || wake_cron || '''
        USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = ''XSMALL''
        COMMENT = ''Wakes the Lab Companion ' || :LEAD_MINUTES || ' min before the lab''
        AS CALL BARCLAYS_HOL.LAB.WAKE_LAB()';
    EXECUTE IMMEDIATE 'CREATE OR REPLACE TASK BARCLAYS_HOL.LAB.LAB_SLEEP_TASK
        SCHEDULE = ''' || sleep_cron || '''
        USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = ''XSMALL''
        COMMENT = ''Re-enables auto-suspend 30 min after the lab''
        AS CALL BARCLAYS_HOL.LAB.SLEEP_LAB()';
    ALTER TASK BARCLAYS_HOL.LAB.LAB_WAKE_TASK RESUME;
    ALTER TASK BARCLAYS_HOL.LAB.LAB_SLEEP_TASK RESUME;

    RETURN 'Wake ' || wake_at::STRING || ' UTC (' || wake_cron || '), sleep ' || sleep_at::STRING || ' UTC';
END;
$$;

-- -----------------------------------------------------
-- Schedule this account's lab manually (provision_account.sh does this for you
-- when LAB_START / LAB_END or the DataOps event times are set):
--   CALL BARCLAYS_HOL.LAB.SCHEDULE_LAB('2026-12-01 09:30:00 +00:00'::TIMESTAMP_TZ,
--                                      '2026-12-01 13:30:00 +00:00'::TIMESTAMP_TZ, 30);
--   SHOW TASKS LIKE 'LAB_%' IN SCHEMA BARCLAYS_HOL.LAB;
-- -----------------------------------------------------
