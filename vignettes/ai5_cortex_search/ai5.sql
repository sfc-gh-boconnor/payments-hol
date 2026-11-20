-- =====================================================
-- AI5 (OPTIONAL): CORTEX SEARCH OVER CALL TRANSCRIPTS AND CASE NOTES - reference SQL
-- Cortex Search is not yet approved at Barclays: this module shows what it would unlock.
-- Needs setup/10b_search_lab.sql. Run as HOL_PARTICIPANT.
-- =====================================================
USE SECONDARY ROLES NONE;
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.SEARCH_LAB;

-- 1. A search service over every call transcript, with filterable attributes
CREATE OR REPLACE CORTEX SEARCH SERVICE RB_CALL_SEARCH
    ON TRANSCRIPT
    ATTRIBUTES QUEUE, TOPIC, CHURNED
    WAREHOUSE = BARCLAYS_WH
    TARGET_LAG = '1 day'
    COMMENT = 'AI5: semantic search over retail call transcripts'
AS
SELECT t.CALL_ID, t.CUSTOMER_ID, t.CALL_START_TS, t.QUEUE, t.TOPIC, IFF(c.CHURNED, 'yes', 'no') AS CHURNED, t.TRANSCRIPT
FROM BARCLAYS_HOL.RAW_DATA.RB_CALL_TRANSCRIPTS t
JOIN BARCLAYS_HOL.RAW_DATA.RB_CUSTOMERS c ON c.CUSTOMER_ID = t.CUSTOMER_ID;

-- 2. Ask it in plain English, with and without a filter
SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW('BARCLAYS_HOL.SEARCH_LAB.RB_CALL_SEARCH',
    '{"query": "customer upset that their local branch is closing and they cannot use the app", "columns": ["CALL_ID", "CUSTOMER_ID", "QUEUE", "CHURNED"], "limit": 5}'))['results'] AS RESULTS;

SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW('BARCLAYS_HOL.SEARCH_LAB.RB_CALL_SEARCH',
    '{"query": "caller told to move money to a safe account", "columns": ["CALL_ID", "CUSTOMER_ID", "TOPIC"], "filter": {"@eq": {"QUEUE": "FRAUD"}}, "limit": 5}'))['results'] AS RESULTS;

-- 3. A second service over the financial crime narratives (case notes and SARs together)
CREATE OR REPLACE CORTEX SEARCH SERVICE RB_FINCRIME_SEARCH
    ON BODY
    ATTRIBUTES DOC_TYPE, FRAUD_TYPE
    WAREHOUSE = BARCLAYS_WH
    TARGET_LAG = '1 day'
    COMMENT = 'AI5: semantic search over fraud case notes and SAR narratives'
AS
SELECT CASE_ID AS DOC_ID, 'FRAUD_CASE' AS DOC_TYPE, FRAUD_TYPE, CUSTOMER_ID, INVESTIGATOR_NOTES AS BODY FROM BARCLAYS_HOL.RAW_DATA.RB_FRAUD_CASES
UNION ALL
SELECT SAR_ID, 'SAR', NULL, CUSTOMER_ID, NARRATIVE FROM BARCLAYS_HOL.RAW_DATA.RB_SAR_NARRATIVES;

SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW('BARCLAYS_HOL.SEARCH_LAB.RB_FINCRIME_SEARCH',
    '{"query": "money mule receiving funds and moving them on within minutes", "columns": ["DOC_ID", "DOC_TYPE", "CUSTOMER_ID"], "limit": 5}'))['results'] AS RESULTS;

SHOW CORTEX SEARCH SERVICES IN SCHEMA BARCLAYS_HOL.SEARCH_LAB;
