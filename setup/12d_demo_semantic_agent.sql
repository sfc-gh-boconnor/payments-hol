-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - EXECUTIVE DEMO
-- STEP 12d: SEMANTIC VIEWS, NAME MATCHES AND THE ASSISTANT (BARCLAYS_DEMO.EXEC)
--
--   DEMO_SV_RETAIL      customers, profit, attrition risk, branches
--   DEMO_SV_CORPORATE   corporate payments, SLA, clients, alerts, feedback
--   DEMO_SV_FINCRIME    fraud cases, SARs, mule accounts, alerts
--   DEMO_NAME_MATCHES   outside records matched to customers (name similarity here;
--                       12e replaces it with Cortex Search matching where allowed)
--   DEMO_EXEC_ASSISTANT agent over the three semantic views (12e adds search tools)
-- Lives only in BARCLAYS_DEMO: not in SNOWFLAKE_INTELLIGENCE, so it never shows
-- in attendees' agent list or touches lab checks.
-- =====================================================
USE ROLE HOL_ADMIN;
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_DEMO.INSIGHTS;

-- ---------- Clean views the semantic views sit on ----------
CREATE OR REPLACE VIEW DEMO_V_RETAIL_CUSTOMERS AS
SELECT c.CUSTOMER_ID, c.CITY, c.SEGMENT, c.AGE, c.IMD_DECILE, c.HOUSING_TENURE, c.EMPLOYMENT_STATUS, c.INCOME_BAND,
       c.CREDIT_BAND, c.AFFORDABILITY_BAND, c.DIGITAL_ACTIVE, c.VULNERABLE_FLAG, c.CHURNED, c.CHURN_REASON,
       c.HOME_BRANCH_ID, b.BRANCH_NAME AS HOME_BRANCH, ROUND(c.HOME_BRANCH_DRIVE_S / 60, 1) AS HOME_BRANCH_DRIVE_MIN,
       s.CHURN_PROBABILITY, COALESCE(s.RISK_BAND, 'LEFT') AS RISK_BAND
FROM BARCLAYS_DEMO.RAW_DATA.RB_CUSTOMERS c
LEFT JOIN BARCLAYS_DEMO.RETAIL.BRANCHES b ON b.BRANCH_ID = c.HOME_BRANCH_ID
LEFT JOIN DEMO_ATTRITION_SCORES s ON s.CUSTOMER_ID = c.CUSTOMER_ID;

CREATE OR REPLACE VIEW DEMO_V_RETAIL_MONTHLY AS
SELECT CUSTOMER_ID, MONTH, REVENUE_GBP, COST_TO_SERVE_GBP, PROFIT_GBP, CURRENT_BALANCE_GBP, SAVINGS_BALANCE_GBP,
       CREDIT_CARD_BALANCE_GBP, CARD_SPEND_GBP, PRODUCTS_HELD, APP_LOGINS, BRANCH_VISITS
FROM BARCLAYS_DEMO.RAW_DATA.RB_MONTHLY_SNAPSHOT;

CREATE OR REPLACE VIEW DEMO_V_BRANCHES AS
SELECT b.BRANCH_ID, b.BRANCH_NAME, b.CITY, b.FORMAT, b.ANNUAL_COST_GBP, b.STAFF, b.HOME_CUSTOMERS, b.CUSTOMER_PROFIT_12M_GBP, b.VISITS,
       i.CUSTOMERS_OVER_20_MIN AS CUSTOMERS_CUT_OFF_IF_CLOSED, i.PROFIT_AT_RISK_GBP AS PROFIT_AT_RISK_IF_CLOSED_GBP
FROM DEMO_BRANCHES b LEFT JOIN DEMO_BRANCH_CLOSURE_IMPACT i USING (BRANCH_ID);

CREATE OR REPLACE VIEW DEMO_V_CORPORATE_PAYMENTS AS
SELECT p.PAYMENT_ID, p.PAYMENT_DATE::DATE AS PAYMENT_DAY, p.PAYMENT_TYPE, p.CHANNEL, p.REGION, p.STATUS, p.CURRENCY,
       ROUND(p.AMOUNT * COALESCE(p.FX_RATE, 1), 2) AS AMOUNT_GBP, p.PROCESSING_TIME_MS, p.ERROR_CODE,
       c.CUSTOMER_NAME AS CLIENT_NAME, c.SECTOR, rm.RM_NAME, rm.TEAM AS RM_TEAM,
       IFF(p.PROCESSING_TIME_MS <= sla.MAX_PROCESSING_TIME_MS, 1, 0) AS WITHIN_SLA
FROM BARCLAYS_DEMO.RAW_DATA.PAYMENTS p
JOIN BARCLAYS_DEMO.RAW_DATA.ACCOUNTS a ON a.ACCOUNT_ID = p.ORIGINATOR_ACCOUNT_ID
JOIN BARCLAYS_DEMO.RAW_DATA.CUSTOMERS c ON c.CUSTOMER_ID = a.CUSTOMER_ID
LEFT JOIN BARCLAYS_DEMO.RAW_DATA.RELATIONSHIP_MANAGERS rm ON rm.RM_ID = c.RM_ID
LEFT JOIN BARCLAYS_DEMO.RAW_DATA.SLA_DEFINITIONS sla ON sla.PAYMENT_TYPE = p.PAYMENT_TYPE;

CREATE OR REPLACE VIEW DEMO_V_CORPORATE_ALERTS AS
SELECT ALERT_ID, ALERT_TIME::DATE AS ALERT_DAY, SEVERITY, PAYMENT_TYPE, STATUS, ASSIGNED_TO, RESOLUTION_TIME_MIN, ALERT_DESCRIPTION
FROM BARCLAYS_DEMO.RAW_DATA.OPERATIONAL_ALERTS;

CREATE OR REPLACE VIEW DEMO_V_FRAUD_CASES AS
SELECT f.CASE_ID, f.CUSTOMER_ID, f.FRAUD_TYPE, f.REPORTED_TS::DATE AS REPORTED_DAY, f.LOSS_GBP, f.DECISION, f.STATUS,
       c.CITY, c.AGE, c.VULNERABLE_FLAG,
       (SELECT MIN(b.MULE_ACCOUNT) FROM DEMO_BENEFICIARY_ACCOUNTS b WHERE b.CUSTOMER_ID = f.CUSTOMER_ID) AS MULE_ACCOUNT
FROM BARCLAYS_DEMO.RAW_DATA.RB_FRAUD_CASES f
JOIN BARCLAYS_DEMO.RAW_DATA.RB_CUSTOMERS c ON c.CUSTOMER_ID = f.CUSTOMER_ID;

CREATE OR REPLACE VIEW DEMO_V_MULE_ACCOUNTS AS
SELECT MULE_ACCOUNT, RECEIVING_BANK, COUNT(DISTINCT CUSTOMER_ID) AS VICTIMS, COUNT(*) AS PAYMENTS_IN,
       ROUND(SUM(AMOUNT_GBP), 2) AS RECEIVED_GBP, MIN(TXN_TS)::DATE AS FIRST_SEEN, MAX(TXN_TS)::DATE AS LAST_SEEN
FROM DEMO_BENEFICIARY_ACCOUNTS GROUP BY 1, 2;

CREATE OR REPLACE VIEW DEMO_V_SARS AS
SELECT SAR_ID, CUSTOMER_ID, FILED_TS::DATE AS FILED_DAY, PATTERN, ACTION FROM BARCLAYS_DEMO.RAW_DATA.RB_SAR_NARRATIVES;

-- ---------- Semantic views ----------
USE SCHEMA BARCLAYS_DEMO.EXEC;

CREATE OR REPLACE SEMANTIC VIEW DEMO_SV_RETAIL
  TABLES (
    customers AS BARCLAYS_DEMO.INSIGHTS.DEMO_V_RETAIL_CUSTOMERS PRIMARY KEY (CUSTOMER_ID)
      WITH SYNONYMS = ('retail customers', 'clients') COMMENT = 'One row per retail banking customer, with attrition risk',
    monthly AS BARCLAYS_DEMO.INSIGHTS.DEMO_V_RETAIL_MONTHLY PRIMARY KEY (CUSTOMER_ID, MONTH)
      WITH SYNONYMS = ('profitability', 'monthly snapshot') COMMENT = 'Revenue, cost to serve, profit and balances per customer per month',
    branches AS BARCLAYS_DEMO.INSIGHTS.DEMO_V_BRANCHES PRIMARY KEY (BRANCH_ID)
      WITH SYNONYMS = ('branch network') COMMENT = 'Branches, their customers, profit and the impact if one closed'
  )
  RELATIONSHIPS (
    monthly_customer AS monthly (CUSTOMER_ID) REFERENCES customers,
    customer_branch AS customers (HOME_BRANCH_ID) REFERENCES branches
  )
  FACTS (
    monthly.revenue AS REVENUE_GBP, monthly.cost AS COST_TO_SERVE_GBP, monthly.profit AS PROFIT_GBP,
    monthly.savings_balance AS SAVINGS_BALANCE_GBP, monthly.current_balance AS CURRENT_BALANCE_GBP,
    customers.churn_probability AS CHURN_PROBABILITY, customers.drive_min AS HOME_BRANCH_DRIVE_MIN,
    branches.branch_cost AS ANNUAL_COST_GBP, branches.branch_profit AS CUSTOMER_PROFIT_12M_GBP,
    branches.cut_off_if_closed AS CUSTOMERS_CUT_OFF_IF_CLOSED, branches.profit_at_risk AS PROFIT_AT_RISK_IF_CLOSED_GBP
  )
  DIMENSIONS (
    customers.city AS CITY WITH SYNONYMS = ('region', 'town', 'area'),
    customers.segment AS SEGMENT, customers.age AS AGE, customers.imd_decile AS IMD_DECILE WITH SYNONYMS = ('deprivation'),
    customers.income_band AS INCOME_BAND, customers.affordability_band AS AFFORDABILITY_BAND,
    customers.digital_active AS DIGITAL_ACTIVE, customers.churned AS CHURNED WITH SYNONYMS = ('left', 'closed account'),
    customers.churn_reason AS CHURN_REASON, customers.risk_band AS RISK_BAND WITH SYNONYMS = ('attrition risk'),
    customers.home_branch AS HOME_BRANCH,
    monthly.month AS MONTH,
    branches.branch_name AS BRANCH_NAME, branches.branch_city AS CITY, branches.format AS FORMAT
  )
  METRICS (
    monthly.total_profit AS SUM(monthly.profit) WITH SYNONYMS = ('profit') COMMENT = 'Total profit in GBP',
    monthly.total_revenue AS SUM(monthly.revenue) COMMENT = 'Total revenue in GBP',
    monthly.total_cost AS SUM(monthly.cost) COMMENT = 'Total cost to serve in GBP',
    customers.customer_count AS COUNT(customers.customer_id) COMMENT = 'Number of customers',
    customers.attrition_rate AS AVG(IFF(customers.churned, 1, 0)) COMMENT = 'Share of customers who left (0 to 1)',
    customers.avg_churn_probability AS AVG(customers.churn_probability) COMMENT = 'Average predicted chance of leaving in the next 3 months'
  )
  COMMENT = 'Executive demo: retail banking customers, profitability, attrition risk and the branch network';

CREATE OR REPLACE SEMANTIC VIEW DEMO_SV_CORPORATE
  TABLES (
    payments AS BARCLAYS_DEMO.INSIGHTS.DEMO_V_CORPORATE_PAYMENTS PRIMARY KEY (PAYMENT_ID)
      WITH SYNONYMS = ('corporate payments', 'transactions') COMMENT = 'One row per corporate payment',
    alerts AS BARCLAYS_DEMO.INSIGHTS.DEMO_V_CORPORATE_ALERTS PRIMARY KEY (ALERT_ID)
      WITH SYNONYMS = ('operational alerts', 'incidents') COMMENT = 'Payment operations alerts'
  )
  FACTS (
    payments.amount AS AMOUNT_GBP, payments.processing_ms AS PROCESSING_TIME_MS, payments.within_sla AS WITHIN_SLA,
    alerts.resolution_min AS RESOLUTION_TIME_MIN
  )
  DIMENSIONS (
    payments.payment_day AS PAYMENT_DAY, payments.payment_type AS PAYMENT_TYPE WITH SYNONYMS = ('scheme', 'rail'),
    payments.channel AS CHANNEL, payments.region AS REGION, payments.status AS STATUS,
    payments.client_name AS CLIENT_NAME WITH SYNONYMS = ('client', 'customer'), payments.sector AS SECTOR,
    payments.rm_name AS RM_NAME WITH SYNONYMS = ('relationship manager'), payments.rm_team AS RM_TEAM,
    alerts.alert_day AS ALERT_DAY, alerts.severity AS SEVERITY, alerts.alert_payment_type AS PAYMENT_TYPE, alerts.alert_status AS STATUS
  )
  METRICS (
    payments.payment_count AS COUNT(payments.payment_id) COMMENT = 'Number of payments',
    payments.volume_gbp AS SUM(payments.amount) WITH SYNONYMS = ('volume') COMMENT = 'Payment volume in GBP',
    payments.success_rate AS AVG(IFF(payments.status = 'COMPLETED', 1, 0)) COMMENT = 'Share of payments completed (0 to 1)',
    payments.sla_rate AS AVG(payments.within_sla) COMMENT = 'Share of payments processed within SLA (0 to 1)',
    alerts.alert_count AS COUNT(alerts.alert_id) COMMENT = 'Number of alerts',
    alerts.avg_resolution_min AS AVG(alerts.resolution_min) COMMENT = 'Average minutes to resolve an alert'
  )
  COMMENT = 'Executive demo: corporate payments, SLA, clients and operational alerts';

CREATE OR REPLACE SEMANTIC VIEW DEMO_SV_FINCRIME
  TABLES (
    cases AS BARCLAYS_DEMO.INSIGHTS.DEMO_V_FRAUD_CASES PRIMARY KEY (CASE_ID)
      WITH SYNONYMS = ('fraud cases', 'scams', 'investigations') COMMENT = 'One row per fraud investigation',
    mules AS BARCLAYS_DEMO.INSIGHTS.DEMO_V_MULE_ACCOUNTS PRIMARY KEY (MULE_ACCOUNT)
      WITH SYNONYMS = ('mule accounts', 'beneficiaries') COMMENT = 'Accounts that received scam payments (synthetic, demo only)',
    sars AS BARCLAYS_DEMO.INSIGHTS.DEMO_V_SARS PRIMARY KEY (SAR_ID)
      WITH SYNONYMS = ('suspicious activity reports') COMMENT = 'Suspicious Activity Reports filed'
  )
  RELATIONSHIPS (case_mule AS cases (MULE_ACCOUNT) REFERENCES mules)
  FACTS (cases.loss AS LOSS_GBP, mules.victims AS VICTIMS, mules.received AS RECEIVED_GBP)
  DIMENSIONS (
    cases.fraud_type AS FRAUD_TYPE WITH SYNONYMS = ('scam type'), cases.decision AS DECISION, cases.case_status AS STATUS,
    cases.reported_day AS REPORTED_DAY, cases.city AS CITY, cases.age AS AGE, cases.vulnerable AS VULNERABLE_FLAG,
    mules.mule_account AS MULE_ACCOUNT, mules.receiving_bank AS RECEIVING_BANK,
    sars.filed_day AS FILED_DAY, sars.pattern AS PATTERN, sars.sar_action AS ACTION
  )
  METRICS (
    cases.case_count AS COUNT(cases.case_id) COMMENT = 'Number of fraud cases',
    cases.total_loss AS SUM(cases.loss) WITH SYNONYMS = ('fraud losses') COMMENT = 'Total fraud loss in GBP',
    cases.reimbursed_rate AS AVG(IFF(cases.decision LIKE 'REIMBURSED%' OR cases.decision LIKE 'REFUNDED%', 1, 0)) COMMENT = 'Share of cases reimbursed or refunded (0 to 1)',
    mules.mule_count AS COUNT(mules.mule_account) COMMENT = 'Number of mule accounts',
    sars.sar_count AS COUNT(sars.sar_id) COMMENT = 'Number of SARs filed'
  )
  COMMENT = 'Executive demo: fraud cases, mule accounts and SARs';

-- ---------- Outside records matched to customers (no search needed) ----------
-- Block on the first 3 letters of the surname, then score: date of birth, town, name similarity.
CREATE OR REPLACE TABLE BARCLAYS_DEMO.INSIGHTS.DEMO_NAME_MATCHES AS
WITH m AS (
    SELECT n.*, UPPER(REGEXP_REPLACE(n.NAME_AS_WRITTEN, '^([^,]+), (.+)$', '\\2 \\1')) AS Q
    FROM BARCLAYS_DEMO.RAW_DATA.RB_NAME_MENTIONS n),
cand AS (
    SELECT m.MENTION_ID, c.CUSTOMER_ID, c.FIRST_NAME || ' ' || c.LAST_NAME AS CUSTOMER_NAME, c.CITY,
           (c.DATE_OF_BIRTH = TRY_TO_DATE(m.DOB_AS_WRITTEN, 'DD/MM/YYYY') OR c.DATE_OF_BIRTH = TRY_TO_DATE(m.DOB_AS_WRITTEN, 'MM/DD/YYYY')) AS DOB_MATCH,
           UPPER(c.CITY) = UPPER(m.TOWN) AS TOWN_MATCH,
           JAROWINKLER_SIMILARITY(UPPER(c.FIRST_NAME || ' ' || c.LAST_NAME), m.Q) AS NAME_SIM
    FROM m JOIN BARCLAYS_DEMO.RAW_DATA.RB_CUSTOMERS c ON LEFT(UPPER(c.LAST_NAME), 3) = LEFT(SPLIT_PART(m.Q, ' ', -1), 3)),
best AS (
    SELECT *, 50 * COALESCE(DOB_MATCH::INT, 0) + 20 * COALESCE(TOWN_MATCH::INT, 0) + 0.3 * NAME_SIM AS SCORE
    FROM cand QUALIFY ROW_NUMBER() OVER (PARTITION BY MENTION_ID ORDER BY SCORE DESC) = 1)
SELECT m.MENTION_ID, m.SOURCE, m.SOURCE_DESCRIPTION, m.NAME_AS_WRITTEN, m.DOB_AS_WRITTEN, m.TOWN,
       b.CUSTOMER_ID AS MATCHED_CUSTOMER_ID, b.CUSTOMER_NAME AS MATCHED_NAME, b.CITY AS MATCHED_CITY,
       b.DOB_MATCH, b.TOWN_MATCH, b.NAME_SIM, b.SCORE,
       CASE WHEN b.SCORE >= 75 THEN 'MATCH' WHEN b.SCORE >= 45 THEN 'REVIEW' ELSE 'NO_MATCH' END AS DECISION,
       'NAME_SIMILARITY' AS METHOD
FROM m LEFT JOIN best b USING (MENTION_ID);

-- ---------- The assistant ----------
CREATE OR REPLACE AGENT BARCLAYS_DEMO.EXEC.DEMO_EXEC_ASSISTANT
  COMMENT = 'Executive demo assistant over retail, corporate and financial crime data. Demo only, not part of the lab.'
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
      Use FincrimeAnalyst for fraud cases, losses, reimbursement decisions, mule accounts and SARs.
    sample_questions:
      - question: "Which cities make the most profit per customer?"
      - question: "Which branch closure would cut off the most profitable customers?"
      - question: "How many high-risk customers are on legacy savings rates?"
      - question: "Which mule accounts received money from the most victims?"
      - question: "What is our corporate payment success rate by scheme?"
  tools:
    - tool_spec: {type: "cortex_analyst_text_to_sql", name: "RetailAnalyst", description: "Retail customers, monthly profit, revenue and cost to serve, attrition risk, cities and the branch network including closure impact."}
    - tool_spec: {type: "cortex_analyst_text_to_sql", name: "CorporateAnalyst", description: "Corporate payments by scheme, channel, region, client, sector and relationship manager, SLA and operational alerts."}
    - tool_spec: {type: "cortex_analyst_text_to_sql", name: "FincrimeAnalyst", description: "Fraud cases, losses and reimbursement decisions, mule accounts and Suspicious Activity Reports."}
    - tool_spec: {type: "data_to_chart", name: "data_to_chart", description: "Charts from query results"}
  tool_resources:
    RetailAnalyst:    {semantic_view: "BARCLAYS_DEMO.EXEC.DEMO_SV_RETAIL",    execution_environment: {type: "warehouse", warehouse: "BARCLAYS_WH"}}
    CorporateAnalyst: {semantic_view: "BARCLAYS_DEMO.EXEC.DEMO_SV_CORPORATE", execution_environment: {type: "warehouse", warehouse: "BARCLAYS_WH"}}
    FincrimeAnalyst:  {semantic_view: "BARCLAYS_DEMO.EXEC.DEMO_SV_FINCRIME",  execution_environment: {type: "warehouse", warehouse: "BARCLAYS_WH"}}
  $$;

GRANT SELECT ON ALL VIEWS IN SCHEMA BARCLAYS_DEMO.INSIGHTS TO ROLE HOL_PARTICIPANT;
SHOW SEMANTIC VIEWS IN SCHEMA BARCLAYS_DEMO.EXEC;
SELECT DECISION, COUNT(*) N FROM BARCLAYS_DEMO.INSIGHTS.DEMO_NAME_MATCHES GROUP BY 1 ORDER BY 1;
