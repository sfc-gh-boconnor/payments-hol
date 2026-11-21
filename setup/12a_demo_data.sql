-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - EXECUTIVE DEMO
-- STEP 12a: THE DEMO'S OWN DATA (BARCLAYS_DEMO)
--
-- The executive demo (Lab Companion > Executive demo) runs on its own database,
-- so it never touches, depends on or satisfies lab content:
--   * RAW_DATA and RETAIL are zero-copy clones of the lab's data schemas.
--     Attendees can only read those, so a clone taken at any time holds only
--     the loaded lab data, never attendee work.
--   * Internal stages don't clone: the evidence files are copied.
--   * Grants are reset: attendees can read BARCLAYS_DEMO, never write to it.
--   * Everything built on top (12b-12d) is prefixed DEMO_ and lives only here.
-- Run by LOAD_LAB_DATA('DEMO') after the lab data is loaded. Runs as HOL_ADMIN.
-- =====================================================
USE ROLE HOL_ADMIN;
USE WAREHOUSE BARCLAYS_WH;

CREATE OR REPLACE DATABASE BARCLAYS_DEMO
    COMMENT = 'Executive demo for the Lab Companion tour: a self-contained copy of the lab data plus DEMO_ objects. Not part of the lab.';
DROP SCHEMA IF EXISTS BARCLAYS_DEMO.PUBLIC;

-- The lab data, frozen as it is now (zero-copy: no extra storage until it changes)
CREATE SCHEMA BARCLAYS_DEMO.RAW_DATA CLONE BARCLAYS_HOL.RAW_DATA;
CREATE SCHEMA BARCLAYS_DEMO.RETAIL   CLONE BARCLAYS_HOL.RETAIL;

-- The demo's own schemas
CREATE SCHEMA BARCLAYS_DEMO.INSIGHTS COMMENT = 'Executive demo: precomputed results the tour stops read (DEMO_ tables)';
CREATE SCHEMA BARCLAYS_DEMO.EXEC     COMMENT = 'Executive demo: semantic views, search services and the DEMO_EXEC_ASSISTANT agent';

-- Evidence files: stages don't clone, so copy them
CREATE STAGE BARCLAYS_DEMO.RETAIL.DEMO_EVIDENCE DIRECTORY = (ENABLE = TRUE) ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Executive demo: copy of the financial crime evidence files';
COPY FILES INTO @BARCLAYS_DEMO.RETAIL.DEMO_EVIDENCE FROM @BARCLAYS_HOL.RETAIL.FINCRIME_EVIDENCE;
ALTER STAGE BARCLAYS_DEMO.RETAIL.DEMO_EVIDENCE REFRESH;

-- Cloned schemas keep their grants: reset them, then attendees get read-only
REVOKE ALL PRIVILEGES ON SCHEMA BARCLAYS_DEMO.RAW_DATA FROM ROLE HOL_PARTICIPANT;
REVOKE ALL PRIVILEGES ON SCHEMA BARCLAYS_DEMO.RETAIL   FROM ROLE HOL_PARTICIPANT;
REVOKE ALL PRIVILEGES ON ALL TABLES         IN SCHEMA BARCLAYS_DEMO.RETAIL   FROM ROLE HOL_PARTICIPANT;
REVOKE ALL PRIVILEGES ON ALL ICEBERG TABLES IN SCHEMA BARCLAYS_DEMO.RAW_DATA FROM ROLE HOL_PARTICIPANT;
GRANT USAGE ON DATABASE BARCLAYS_DEMO TO ROLE HOL_PARTICIPANT;
GRANT USAGE ON ALL SCHEMAS IN DATABASE BARCLAYS_DEMO TO ROLE HOL_PARTICIPANT;
GRANT SELECT ON ALL TABLES         IN DATABASE BARCLAYS_DEMO TO ROLE HOL_PARTICIPANT;
GRANT SELECT ON ALL ICEBERG TABLES IN DATABASE BARCLAYS_DEMO TO ROLE HOL_PARTICIPANT;
GRANT SELECT ON FUTURE TABLES IN SCHEMA BARCLAYS_DEMO.INSIGHTS TO ROLE HOL_PARTICIPANT;
GRANT SELECT ON FUTURE VIEWS  IN SCHEMA BARCLAYS_DEMO.INSIGHTS TO ROLE HOL_PARTICIPANT;

SELECT 'RAW_DATA tables' AS WHAT, COUNT(*) AS N FROM BARCLAYS_DEMO.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'RAW_DATA'
UNION ALL SELECT 'RETAIL tables', COUNT(*) FROM BARCLAYS_DEMO.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'RETAIL'
UNION ALL SELECT 'Evidence files', COUNT(*) FROM DIRECTORY(@BARCLAYS_DEMO.RETAIL.DEMO_EVIDENCE);
