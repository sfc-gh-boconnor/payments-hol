-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - FACILITATOR SETUP
-- STEP 09: COWORK PACK (used by OPS3)
--
-- A ready-made payments agent for Snowflake CoWork, built on the Iceberg sources so
-- OPS3 doesn't depend on any other module:
--   BARCLAYS_HOL.COWORK_PACK.PAYMENT_ACTIVITY   one row per payment, with client, sector and RM
--   BARCLAYS_HOL.COWORK_PACK.CLIENT_FEEDBACK    client feedback with sector (DA2's Logistics story)
--   BARCLAYS_HOL.COWORK_PACK.SV_PAYMENTS_OPS    semantic view over both
--   SNOWFLAKE_INTELLIGENCE.AGENTS.PAYMENTS_OPS_COWORK  agent with Analyst + code execution
--     (code execution is what CoWork's document generation needs)
-- Objects are owned by HOL_PARTICIPANT, so attendees can tune the agent.
-- =====================================================

USE ROLE HOL_ADMIN;
USE WAREHOUSE BARCLAYS_WH;
CREATE SCHEMA IF NOT EXISTS BARCLAYS_HOL.COWORK_PACK COMMENT = 'OPS3: ready-made payments agent for Snowflake CoWork';
GRANT OWNERSHIP ON SCHEMA BARCLAYS_HOL.COWORK_PACK TO ROLE HOL_PARTICIPANT COPY CURRENT GRANTS;

USE ROLE HOL_PARTICIPANT;
USE SCHEMA BARCLAYS_HOL.COWORK_PACK;

CREATE OR REPLACE VIEW PAYMENT_ACTIVITY
  COMMENT = 'OPS3: one row per payment with the originating client, sector and relationship manager'
AS
SELECT p.PAYMENT_ID, p.PAYMENT_DATE, DATE_TRUNC('month', p.PAYMENT_DATE)::DATE AS PAYMENT_MONTH,
       p.PAYMENT_TYPE, p.CHANNEL, p.CURRENCY, p.AMOUNT, p.STATUS, p.ERROR_CODE, p.REGION,
       p.PROCESSING_TIME_MS, c.CUSTOMER_ID, c.CUSTOMER_NAME, c.SECTOR AS CUSTOMER_SECTOR, rm.RM_NAME
FROM BARCLAYS_HOL.RAW_DATA.PAYMENTS p
JOIN BARCLAYS_HOL.RAW_DATA.ACCOUNTS a ON a.ACCOUNT_ID = p.ORIGINATOR_ACCOUNT_ID
JOIN BARCLAYS_HOL.RAW_DATA.CUSTOMERS c ON c.CUSTOMER_ID = a.CUSTOMER_ID
LEFT JOIN BARCLAYS_HOL.RAW_DATA.RELATIONSHIP_MANAGERS rm ON rm.RM_ID = c.RM_ID;

CREATE OR REPLACE VIEW CLIENT_FEEDBACK
  COMMENT = 'OPS3: client feedback with sector and month'
AS
SELECT f.FEEDBACK_ID, f.FEEDBACK_DATE, DATE_TRUNC('month', f.FEEDBACK_DATE)::DATE AS FEEDBACK_MONTH,
       f.FEEDBACK_CHANNEL, f.FEEDBACK_TEXT, f.PAYMENT_TYPE, f.RATING,
       c.CUSTOMER_ID, c.CUSTOMER_NAME, c.SECTOR AS CUSTOMER_SECTOR
FROM BARCLAYS_HOL.RAW_DATA.CUSTOMER_FEEDBACK f
JOIN BARCLAYS_HOL.RAW_DATA.CUSTOMERS c ON c.CUSTOMER_ID = f.CUSTOMER_ID;

CREATE OR REPLACE SEMANTIC VIEW SV_PAYMENTS_OPS
  TABLES (
    payments AS BARCLAYS_HOL.COWORK_PACK.PAYMENT_ACTIVITY
      PRIMARY KEY (PAYMENT_ID)
      WITH SYNONYMS = ('payments', 'transactions')
      COMMENT = 'One row per payment, with the originating client',
    feedback AS BARCLAYS_HOL.COWORK_PACK.CLIENT_FEEDBACK
      PRIMARY KEY (FEEDBACK_ID)
      WITH SYNONYMS = ('feedback', 'complaints', 'client comments')
      COMMENT = 'Client feedback with a 1 to 5 rating'
  )
  FACTS (
    payments.amount AS AMOUNT COMMENT = 'Payment amount in GBP',
    payments.processing_time_ms AS PROCESSING_TIME_MS COMMENT = 'Processing time in milliseconds',
    feedback.rating AS RATING COMMENT = 'Feedback rating, 1 (poor) to 5 (excellent)'
  )
  DIMENSIONS (
    payments.payment_date AS PAYMENT_DATE COMMENT = 'Payment date and time',
    payments.payment_month AS PAYMENT_MONTH COMMENT = 'Month of the payment',
    payments.payment_type AS PAYMENT_TYPE WITH SYNONYMS = ('scheme', 'payment scheme') COMMENT = 'SWIFT, BACS, CHAPS, FASTER_PAYMENTS, SEPA or WIRE_TRANSFER',
    payments.channel AS CHANNEL COMMENT = 'Channel the payment came through',
    payments.status AS STATUS COMMENT = 'COMPLETED, FAILED, PENDING or RETURNED',
    payments.error_code AS ERROR_CODE WITH SYNONYMS = ('failure reason') COMMENT = 'Error code for failed payments',
    payments.region AS REGION COMMENT = 'Region',
    payments.customer_name AS CUSTOMER_NAME WITH SYNONYMS = ('client') COMMENT = 'Originating client',
    payments.customer_sector AS CUSTOMER_SECTOR WITH SYNONYMS = ('sector', 'industry') COMMENT = 'Client sector',
    payments.rm_name AS RM_NAME WITH SYNONYMS = ('relationship manager', 'RM') COMMENT = 'Relationship manager',
    feedback.feedback_month AS FEEDBACK_MONTH COMMENT = 'Month of the feedback',
    feedback.feedback_text AS FEEDBACK_TEXT COMMENT = 'What the client said',
    feedback.feedback_client AS CUSTOMER_NAME COMMENT = 'Client who gave the feedback',
    feedback.feedback_sector AS CUSTOMER_SECTOR COMMENT = 'Sector of the client who gave the feedback'
  )
  METRICS (
    payments.payment_value AS SUM(payments.amount) WITH SYNONYMS = ('volume', 'payment volume') COMMENT = 'Total payment value in GBP',
    payments.payment_count AS COUNT(payments.payment_id) COMMENT = 'Number of payments',
    payments.failed_value AS SUM(IFF(payments.status = 'FAILED', payments.amount, 0)) COMMENT = 'Value of failed payments in GBP',
    payments.failed_count AS COUNT_IF(payments.status = 'FAILED') COMMENT = 'Number of failed payments',
    payments.success_rate AS ROUND(COUNT_IF(payments.status = 'COMPLETED') / NULLIF(COUNT(payments.payment_id), 0) * 100, 1)
      COMMENT = 'Share of payments that completed (%)',
    feedback.average_rating AS ROUND(AVG(feedback.rating), 2) COMMENT = 'Average feedback rating (1 to 5)',
    feedback.feedback_count AS COUNT(feedback.feedback_id) COMMENT = 'Number of feedback comments'
  )
  COMMENT = 'OPS3 CoWork pack: payments, failures and client feedback';

-- CoWork lists agents in SNOWFLAKE_INTELLIGENCE.AGENTS (setup 00 grants CREATE AGENT there)
CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.PAYMENTS_OPS_COWORK
  COMMENT = 'OPS3: payments operations agent for Snowflake CoWork (charts, Deep Research, automations, documents)'
  PROFILE = '{"display_name": "Payments Ops CoWork", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  instructions:
    response: "You support Barclays payments operations and relationship managers. Amounts are GBP. Show trends and comparisons as charts and lookups as tables (10 rows or fewer). Always say which period the answer covers. When asked for a document, keep it to the facts in the data and add clear recommended actions."
    orchestration: "Use the Analyst tool for questions about payments, failures, schemes, clients, sectors, relationship managers and client feedback. Use code execution only to build documents or charts from results you already have."
    sample_questions:
      - question: "Show monthly failed payment value by scheme for the last 12 months"
      - question: "Which sectors have the lowest average feedback rating over the last four months?"
      - question: "Which 5 clients had the most failed payment value this month, and who is their relationship manager?"
  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "Analyst"
        description: "Payments, failures, schemes, clients, sectors, relationship managers and client feedback"
    - tool_spec:
        type: "code_execution"
        name: "code_execution"
  tool_resources:
    Analyst:
      semantic_view: "BARCLAYS_HOL.COWORK_PACK.SV_PAYMENTS_OPS"
      execution_environment:
        type: "warehouse"
        warehouse: "BARCLAYS_WH"
    code_execution: {}
  $$;

-- Verify
SELECT 'PAYMENT_ACTIVITY' AS OBJECT_NAME, COUNT(*) AS ROW_COUNT FROM PAYMENT_ACTIVITY
UNION ALL SELECT 'CLIENT_FEEDBACK', COUNT(*) FROM CLIENT_FEEDBACK;
