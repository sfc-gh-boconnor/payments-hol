-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - EXECUTIVE DEMO
-- STEP 12e (OPTIONAL): CORTEX SEARCH FOR THE DEMO (BARCLAYS_DEMO.EXEC)
--
-- Only where Cortex Search is allowed (the same switch as the lab's 10b):
--   DEMO_NAME_SEARCH      customer identities, for "is this our customer?"
--   DEMO_FINCRIME_SEARCH  fraud case notes, SARs and fraud-queue calls, for "find similar cases"
-- Then upgrades DEMO_NAME_MATCHES to search-based matching and gives
-- DEMO_EXEC_ASSISTANT both services as tools. Without this step the demo
-- still works: name matching falls back to name similarity (12d).
-- =====================================================
USE ROLE HOL_ADMIN;
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_DEMO.EXEC;

CREATE OR REPLACE CORTEX SEARCH SERVICE DEMO_NAME_SEARCH
    ON FULL_NAME
    ATTRIBUTES CITY
    WAREHOUSE = BARCLAYS_WH
    TARGET_LAG = '1 day'
    COMMENT = 'Executive demo: fuzzy search over customer names'
AS
SELECT CUSTOMER_ID, FIRST_NAME || ' ' || LAST_NAME AS FULL_NAME, CITY, TO_VARCHAR(DATE_OF_BIRTH, 'YYYY-MM-DD') AS DOB,
       SEGMENT, IFF(CHURNED, 'yes', 'no') AS LEFT_BANK
FROM BARCLAYS_DEMO.RAW_DATA.RB_CUSTOMERS;

CREATE OR REPLACE CORTEX SEARCH SERVICE DEMO_FINCRIME_SEARCH
    ON BODY
    ATTRIBUTES DOC_TYPE, FRAUD_TYPE
    WAREHOUSE = BARCLAYS_WH
    TARGET_LAG = '1 day'
    COMMENT = 'Executive demo: search over fraud case notes, SARs and fraud calls'
AS
SELECT CASE_ID AS DOC_ID, 'FRAUD_CASE' AS DOC_TYPE, FRAUD_TYPE, CUSTOMER_ID, CASE_ID || ' · ' || FRAUD_TYPE AS TITLE, INVESTIGATOR_NOTES AS BODY
FROM BARCLAYS_DEMO.RAW_DATA.RB_FRAUD_CASES
UNION ALL
SELECT SAR_ID, 'SAR', NULL, CUSTOMER_ID, SAR_ID || ' · ' || PATTERN, NARRATIVE FROM BARCLAYS_DEMO.RAW_DATA.RB_SAR_NARRATIVES
UNION ALL
SELECT CALL_ID, 'FRAUD_CALL', TOPIC, CUSTOMER_ID, CALL_ID || ' · fraud line call', TRANSCRIPT
FROM BARCLAYS_DEMO.RAW_DATA.RB_CALL_TRANSCRIPTS WHERE QUEUE = 'FRAUD';

-- Search-based name matching: 10 candidates per outside record, then date of birth, town and name decide
CREATE OR REPLACE TABLE BARCLAYS_DEMO.INSIGHTS.DEMO_NAME_MATCHES AS
WITH cand AS (
    SELECT m.MENTION_ID, r.CUSTOMER_ID, r.FULL_NAME, r.CITY,
           (r.DOB::DATE = TRY_TO_DATE(m.DOB_AS_WRITTEN, 'DD/MM/YYYY') OR r.DOB::DATE = TRY_TO_DATE(m.DOB_AS_WRITTEN, 'MM/DD/YYYY')) AS DOB_MATCH,
           UPPER(r.CITY) = UPPER(m.TOWN) AS TOWN_MATCH,
           JAROWINKLER_SIMILARITY(UPPER(r.FULL_NAME), UPPER(REGEXP_REPLACE(m.NAME_AS_WRITTEN, '^([^,]+), (.+)$', '\\2 \\1'))) AS NAME_SIM
    FROM BARCLAYS_DEMO.RAW_DATA.RB_NAME_MENTIONS m,
    LATERAL CORTEX_SEARCH_RETRIEVE(service_name => 'BARCLAYS_DEMO.EXEC.DEMO_NAME_SEARCH', query => m.NAME_AS_WRITTEN, limit => 10) r),
best AS (
    SELECT *, 50 * COALESCE(DOB_MATCH::INT, 0) + 20 * COALESCE(TOWN_MATCH::INT, 0) + 0.3 * NAME_SIM AS SCORE
    FROM cand QUALIFY ROW_NUMBER() OVER (PARTITION BY MENTION_ID ORDER BY SCORE DESC) = 1)
SELECT m.MENTION_ID, m.SOURCE, m.SOURCE_DESCRIPTION, m.NAME_AS_WRITTEN, m.DOB_AS_WRITTEN, m.TOWN,
       b.CUSTOMER_ID AS MATCHED_CUSTOMER_ID, b.FULL_NAME AS MATCHED_NAME, b.CITY AS MATCHED_CITY,
       b.DOB_MATCH, b.TOWN_MATCH, b.NAME_SIM, b.SCORE,
       CASE WHEN b.SCORE >= 75 THEN 'MATCH' WHEN b.SCORE >= 45 THEN 'REVIEW' ELSE 'NO_MATCH' END AS DECISION,
       'CORTEX_SEARCH' AS METHOD
FROM BARCLAYS_DEMO.RAW_DATA.RB_NAME_MENTIONS m LEFT JOIN best b USING (MENTION_ID);

-- The assistant, now with search tools as well
CREATE OR REPLACE AGENT BARCLAYS_DEMO.EXEC.DEMO_EXEC_ASSISTANT
  COMMENT = 'Executive demo assistant over retail, corporate and financial crime data, with search. Demo only, not part of the lab.'
  PROFILE = '{"display_name": "Bank Executive Assistant", "color": "blue"}'
  FROM SPECIFICATION
  $$
  orchestration:
    budget:
      seconds: 60
      tokens: 16000
  models:
    orchestration: auto
  instructions:
    response: >
      You are an assistant for senior leaders at a UK bank. Answer in two or three short sentences first, then a small
      table if it helps (10 rows or fewer). Use GBP with commas, percentages to 1 decimal place. Say which data you used.
      If the data can't answer the question, say so instead of guessing. All data is synthetic demo data.
    orchestration: >
      Use RetailAnalyst for retail customers, profitability by city or branch, attrition risk and branch closures.
      Use CorporateAnalyst for corporate payments, volumes, SLA, clients, relationship managers and alerts.
      Use FincrimeAnalyst for counts and totals of fraud cases, losses, decisions, mule accounts and SARs.
      Use CaseSearch to find fraud cases, SARs or fraud calls similar to a description, and quote the case IDs.
      Use CustomerSearch to find customers by a name that may be misspelt, abbreviated or a nickname; show the
      candidates with their city and date of birth, and never say a match is certain on the name alone.
    sample_questions:
      - question: "Which cities make the most profit per customer?"
      - question: "Which branch closure would cut off the most profitable customers?"
      - question: "Find cases where an elderly customer was told to move money to a safe account"
      - question: "Is Liz Moor one of our customers?"
      - question: "Which mule accounts received money from the most victims?"
  tools:
    - tool_spec: {type: "cortex_analyst_text_to_sql", name: "RetailAnalyst", description: "Retail customers, monthly profit, revenue and cost to serve, attrition risk, cities and the branch network including closure impact."}
    - tool_spec: {type: "cortex_analyst_text_to_sql", name: "CorporateAnalyst", description: "Corporate payments by scheme, channel, region, client, sector and relationship manager, SLA and operational alerts."}
    - tool_spec: {type: "cortex_analyst_text_to_sql", name: "FincrimeAnalyst", description: "Fraud cases, losses and reimbursement decisions, mule accounts and Suspicious Activity Reports."}
    - tool_spec: {type: "cortex_search", name: "CaseSearch", description: "Fraud case investigator notes, Suspicious Activity Report narratives and fraud-line call transcripts."}
    - tool_spec: {type: "cortex_search", name: "CustomerSearch", description: "Retail customers by name (fuzzy), with city and date of birth."}
    - tool_spec: {type: "data_to_chart", name: "data_to_chart", description: "Charts from query results"}
  tool_resources:
    RetailAnalyst:    {semantic_view: "BARCLAYS_DEMO.EXEC.DEMO_SV_RETAIL",    execution_environment: {type: "warehouse", warehouse: "BARCLAYS_WH"}}
    CorporateAnalyst: {semantic_view: "BARCLAYS_DEMO.EXEC.DEMO_SV_CORPORATE", execution_environment: {type: "warehouse", warehouse: "BARCLAYS_WH"}}
    FincrimeAnalyst:  {semantic_view: "BARCLAYS_DEMO.EXEC.DEMO_SV_FINCRIME",  execution_environment: {type: "warehouse", warehouse: "BARCLAYS_WH"}}
    CaseSearch:       {search_service: "BARCLAYS_DEMO.EXEC.DEMO_FINCRIME_SEARCH", id_column: "DOC_ID", title_column: "TITLE", max_results: 5}
    CustomerSearch:   {search_service: "BARCLAYS_DEMO.EXEC.DEMO_NAME_SEARCH",     id_column: "CUSTOMER_ID", title_column: "FULL_NAME", max_results: 8}
  $$;

SELECT DECISION, COUNT(*) N FROM BARCLAYS_DEMO.INSIGHTS.DEMO_NAME_MATCHES GROUP BY 1 ORDER BY 1;
