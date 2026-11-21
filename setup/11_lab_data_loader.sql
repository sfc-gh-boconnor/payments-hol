-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - FACILITATOR SETUP
-- STEP 11: LOAD THE LAB DATA INSIDE SNOWFLAKE
--
-- One procedure loads every lab data set from the lab's Git repository, so
-- provisioning needs one CALL instead of a CLI upload and script per data set:
--
--   CALL BARCLAYS_HOL.LAB.LOAD_LAB_DATA('ALL');      -- everything (DataOps, INSTALL.sql)
--   CALL BARCLAYS_HOL.LAB.LOAD_LAB_DATA('RETAIL');   -- retail banking + text and evidence
--   CALL BARCLAYS_HOL.LAB.LOAD_LAB_DATA('TEXT');     -- text and evidence only (AI4, AI5, DS)
--
-- The second argument switches the optional Cortex Search lab (AI5, setup 10b):
-- TRUE or FALSE, or NULL (default) to keep it only where SEARCH_LAB already exists.
--
-- The data is generated and validated by the lab author (setup/tools/) and
-- committed to the repo; nothing here generates data or calls AI.
-- Each step is logged to LAB.DATA_LOAD_LOG, which the Lab Companion's
-- "Refresh lab data" button reads for its progress bar.
--
-- Caller's rights: the data scripts set their own role and schema (USE), which
-- owner's-rights procedures can't run. Callers need HOL_ADMIN.
-- Run as ACCOUNTADMIN after git_repo.sql (needs the HOL_REPO Git repository).
-- =====================================================

USE ROLE ACCOUNTADMIN;
-- HOL_ADMIN fetches and reads the lab repository inside the procedure
GRANT USAGE ON DATABASE BARCLAYS_HOL_SETUP TO ROLE HOL_ADMIN;
GRANT USAGE ON SCHEMA BARCLAYS_HOL_SETUP.PUBLIC TO ROLE HOL_ADMIN;
GRANT READ, WRITE ON GIT REPOSITORY BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO TO ROLE HOL_ADMIN;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE HOL_ADMIN;

USE ROLE HOL_ADMIN;
USE WAREHOUSE BARCLAYS_WH;
CREATE SCHEMA IF NOT EXISTS BARCLAYS_HOL.LAB;

CREATE TABLE IF NOT EXISTS BARCLAYS_HOL.LAB.DATA_LOAD_LOG (
    RUN_ID        VARCHAR,
    SCOPE         VARCHAR,
    STEP_NO       INTEGER,
    STEP_TOTAL    INTEGER,
    STEP_NAME     VARCHAR,
    STATUS        VARCHAR,      -- RUNNING, DONE, FAILED
    STARTED_AT    TIMESTAMP_LTZ,
    FINISHED_AT   TIMESTAMP_LTZ,
    ERROR_MESSAGE VARCHAR
) COMMENT = 'Lab data loads (LOAD_LAB_DATA): one row per step, read by the Lab Companion progress bar';
GRANT SELECT ON TABLE BARCLAYS_HOL.LAB.DATA_LOAD_LOG TO ROLE HOL_PARTICIPANT;

CREATE OR REPLACE PROCEDURE BARCLAYS_HOL.LAB.LOAD_LAB_DATA(SCOPE VARCHAR DEFAULT 'ALL', INCLUDE_SEARCH BOOLEAN DEFAULT NULL)
RETURNS VARCHAR
LANGUAGE SQL
COMMENT = 'Load the lab data sets from the lab Git repository (ALL, RETAIL or TEXT), logging each step to LAB.DATA_LOAD_LOG'
EXECUTE AS CALLER
AS
$$
DECLARE
    run_id     VARCHAR DEFAULT UUID_STRING();
    repo       VARCHAR DEFAULT '@BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO/branches/main/';
    scope_u    VARCHAR DEFAULT UPPER(COALESCE(SCOPE, 'ALL'));
    search     BOOLEAN DEFAULT INCLUDE_SEARCH;
    all_steps  ARRAY;
    steps      ARRAY DEFAULT ARRAY_CONSTRUCT();
    step_total INTEGER;
    step_no    INTEGER DEFAULT 0;
    step_name  VARCHAR;
    step_sql   VARCHAR;
    t0         TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP();
BEGIN
    IF (scope_u NOT IN ('ALL', 'RETAIL', 'TEXT')) THEN
        RETURN 'Unknown scope ' || scope_u || ': use ALL, RETAIL or TEXT';
    END IF;
    IF (search IS NULL) THEN
        SELECT COUNT(*) > 0 INTO :search FROM BARCLAYS_HOL.INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = 'SEARCH_LAB';
    END IF;

    CREATE SCHEMA IF NOT EXISTS BARCLAYS_HOL.RETAIL;
    CREATE STAGE IF NOT EXISTS BARCLAYS_HOL.RETAIL.ORS_SEED;
    CREATE STAGE IF NOT EXISTS BARCLAYS_HOL.RETAIL.RB_SEED;
    CREATE STAGE IF NOT EXISTS BARCLAYS_HOL.RETAIL.FINCRIME_EVIDENCE DIRECTORY = (ENABLE = TRUE) ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

    -- [name, scopes, one SQL statement]; scripts run with EXECUTE IMMEDIATE FROM the repo
    all_steps := ARRAY_CONSTRUCT(
        ARRAY_CONSTRUCT('Fetch the lab repository',       'ALL,RETAIL,TEXT', 'ALTER GIT REPOSITORY BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO FETCH'),
        ARRAY_CONSTRUCT('Corporate payments source data', 'ALL',             'EXECUTE IMMEDIATE FROM ' || repo || 'setup/01_seed_synthetic_data.sql'),
        ARRAY_CONSTRUCT('Publish sources as Iceberg',     'ALL',             'EXECUTE IMMEDIATE FROM ' || repo || 'setup/02_publish_iceberg.sql'),
        ARRAY_CONSTRUCT('Copy branch travel times',       'ALL',             'COPY FILES INTO @BARCLAYS_HOL.RETAIL.ORS_SEED FROM ' || repo || 'data/retail/'),
        ARRAY_CONSTRUCT('Retail branch network (DA3)',    'ALL',             'EXECUTE IMMEDIATE FROM ' || repo || 'setup/07_retail_geo_seed.sql'),
        ARRAY_CONSTRUCT('Copy retail banking data',       'ALL,RETAIL',      'COPY FILES INTO @BARCLAYS_HOL.RETAIL.RB_SEED FROM ' || repo || 'data/retail_bank/ PATTERN = ''.*[.]csv[.]gz'''),
        ARRAY_CONSTRUCT('Retail banking tables',          'ALL,RETAIL',      'EXECUTE IMMEDIATE FROM ' || repo || 'setup/08_retail_bank_seed.sql'),
        ARRAY_CONSTRUCT('Copy calls, emails and cases',   'ALL,RETAIL,TEXT', 'COPY FILES INTO @BARCLAYS_HOL.RETAIL.RB_SEED/text/ FROM ' || repo || 'data/retail_text/ PATTERN = ''.*rb_[a-z_]+[.]csv[.]gz'''),
        ARRAY_CONSTRUCT('Copy fraud evidence files',      'ALL,RETAIL,TEXT', 'COPY FILES INTO @BARCLAYS_HOL.RETAIL.FINCRIME_EVIDENCE FROM ' || repo || 'data/retail_text/evidence/'),
        ARRAY_CONSTRUCT('Text tables and ML schema',      'ALL,RETAIL,TEXT', 'EXECUTE IMMEDIATE FROM ' || repo || 'setup/10_retail_text_seed.sql'),
        ARRAY_CONSTRUCT('Cortex Search lab (AI5)',        'SEARCH',          'EXECUTE IMMEDIATE FROM ' || repo || 'setup/10b_search_lab.sql'));
    FOR i IN 0 TO ARRAY_SIZE(all_steps) - 1 DO
        IF (ARRAY_CONTAINS(scope_u::VARIANT, SPLIT(all_steps[i][1]::VARCHAR, ','))
            OR (all_steps[i][1]::VARCHAR = 'SEARCH' AND search)) THEN
            steps := ARRAY_APPEND(steps, all_steps[i]);
        END IF;
    END FOR;
    step_total := ARRAY_SIZE(steps);

    -- every step is listed up front, so the progress bar knows the total
    FOR i IN 1 TO step_total DO
        step_name := steps[i - 1][0]::VARCHAR;
        INSERT INTO BARCLAYS_HOL.LAB.DATA_LOAD_LOG (RUN_ID, SCOPE, STEP_NO, STEP_TOTAL, STEP_NAME, STATUS)
        VALUES (:run_id, :scope_u, :i, :step_total, :step_name, 'PENDING');
    END FOR;

    FOR i IN 1 TO step_total DO
        step_no := i;
        step_sql := steps[i - 1][2]::VARCHAR;
        UPDATE BARCLAYS_HOL.LAB.DATA_LOAD_LOG SET STATUS = 'RUNNING', STARTED_AT = CURRENT_TIMESTAMP()
         WHERE RUN_ID = :run_id AND STEP_NO = :step_no;
        EXECUTE IMMEDIATE :step_sql;
        UPDATE BARCLAYS_HOL.LAB.DATA_LOAD_LOG SET STATUS = 'DONE', FINISHED_AT = CURRENT_TIMESTAMP()
         WHERE RUN_ID = :run_id AND STEP_NO = :step_no;
    END FOR;
    ALTER STAGE BARCLAYS_HOL.RETAIL.FINCRIME_EVIDENCE REFRESH;
    RETURN 'Loaded ' || scope_u || ' lab data: ' || step_total || ' steps in '
        || DATEDIFF('second', t0, CURRENT_TIMESTAMP()) || ' s (run ' || run_id || ')';
EXCEPTION
    WHEN OTHER THEN
        LET err VARCHAR := SQLERRM;
        UPDATE BARCLAYS_HOL.LAB.DATA_LOAD_LOG SET STATUS = 'FAILED', FINISHED_AT = CURRENT_TIMESTAMP(), ERROR_MESSAGE = :err
         WHERE RUN_ID = :run_id AND STEP_NO = :step_no;
        RAISE;
END;
$$;

-- The Lab Companion starts a load with EXECUTE TASK, so the button returns at once
-- and the page polls DATA_LOAD_LOG. Not scheduled: they only run when started.
CREATE OR REPLACE TASK BARCLAYS_HOL.LAB.LOAD_LAB_DATA_TEXT
    WAREHOUSE = BARCLAYS_WH
    COMMENT = 'Lab Companion: reset the text and evidence data (AI4, AI5, DS)'
AS CALL BARCLAYS_HOL.LAB.LOAD_LAB_DATA('TEXT');

CREATE OR REPLACE TASK BARCLAYS_HOL.LAB.LOAD_LAB_DATA_ALL
    WAREHOUSE = BARCLAYS_WH
    COMMENT = 'Lab Companion: reload all lab data'
AS CALL BARCLAYS_HOL.LAB.LOAD_LAB_DATA('ALL');
