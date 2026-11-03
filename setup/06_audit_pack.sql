-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - FACILITATOR SETUP
-- STEP 06: GOVERNANCE AUDIT PACK (used by GOV2)
--
-- A small, self-contained set of objects built straight on the Iceberg
-- sources, so GOV2 (lineage, audit and trust) works on any pathway without
-- DE1, DA1 or OPS1. Everything lives in its own schema, AUDIT_PACK, and uses
-- names no other module builds, so attendees can still do those modules
-- afterwards.
--   PAYMENT_SLA_DAILY     daily SLA data product per scheme (GOV2 documents it)
--   CLIENT_ACCOUNTS       client accounts with the restricted IBAN,
--                         ACCOUNT_NUMBER and SORT_CODE columns (access audit)
--   SV_PAYMENTS_AUDIT     semantic view over both
--   PAYMENTS_AUDIT_AGENT  agent attendees question, then audit
-- Built as HOL_PARTICIPANT, so attendees own it and can comment on it.
-- =====================================================

USE ROLE HOL_ADMIN;
CREATE SCHEMA IF NOT EXISTS BARCLAYS_HOL.AUDIT_PACK
  COMMENT = 'Ready-made objects for GOV2 lineage, audit and trust';
GRANT OWNERSHIP ON SCHEMA BARCLAYS_HOL.AUDIT_PACK TO ROLE HOL_PARTICIPANT COPY CURRENT GRANTS;

USE ROLE HOL_PARTICIPANT;
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.AUDIT_PACK;

CREATE OR REPLACE TABLE PAYMENT_SLA_DAILY AS
WITH daily AS (
    SELECT DATE_TRUNC('day', PAYMENT_DATE)::DATE AS PAYMENT_DAY,
           PAYMENT_TYPE,
           COUNT(*) AS TOTAL_PAYMENTS,
           COUNT_IF(STATUS = 'FAILED') AS FAILED_PAYMENTS,
           ROUND(COUNT_IF(STATUS = 'COMPLETED') / NULLIF(COUNT(*), 0) * 100, 2) AS SUCCESS_RATE_PCT,
           APPROX_PERCENTILE(PROCESSING_TIME_MS, 0.95) AS P95_PROCESSING_TIME_MS,
           ROUND(SUM(AMOUNT), 2) AS TOTAL_VOLUME_GBP
    FROM BARCLAYS_HOL.RAW_DATA.PAYMENTS
    GROUP BY 1, 2
)
SELECT d.PAYMENT_DAY, d.PAYMENT_TYPE, s.SLA_NAME,
       s.TARGET_SUCCESS_RATE    AS SLA_TARGET_PCT,
       s.MAX_PROCESSING_TIME_MS AS SLA_THRESHOLD_MS,
       d.SUCCESS_RATE_PCT, d.P95_PROCESSING_TIME_MS, d.TOTAL_PAYMENTS, d.FAILED_PAYMENTS, d.TOTAL_VOLUME_GBP,
       CASE WHEN d.SUCCESS_RATE_PCT >= s.TARGET_SUCCESS_RATE
              AND d.P95_PROCESSING_TIME_MS <= s.MAX_PROCESSING_TIME_MS THEN 'COMPLIANT'
            WHEN d.SUCCESS_RATE_PCT >= s.TARGET_SUCCESS_RATE * 0.95 THEN 'AT RISK'
            ELSE 'BREACH' END AS SLA_STATUS
FROM daily d
JOIN BARCLAYS_HOL.RAW_DATA.SLA_DEFINITIONS s ON d.PAYMENT_TYPE = s.PAYMENT_TYPE;

CREATE OR REPLACE VIEW CLIENT_ACCOUNTS AS
SELECT a.ACCOUNT_ID, a.CUSTOMER_ID, c.CUSTOMER_NAME, c.SECTOR AS CUSTOMER_SECTOR,
       rm.RM_NAME, a.SORT_CODE, a.ACCOUNT_NUMBER, a.IBAN, a.CURRENCY, a.ACCOUNT_TYPE, a.STATUS
FROM BARCLAYS_HOL.RAW_DATA.ACCOUNTS a
JOIN BARCLAYS_HOL.RAW_DATA.CUSTOMERS c ON a.CUSTOMER_ID = c.CUSTOMER_ID
LEFT JOIN BARCLAYS_HOL.RAW_DATA.RELATIONSHIP_MANAGERS rm ON c.RM_ID = rm.RM_ID;

CREATE OR REPLACE SEMANTIC VIEW SV_PAYMENTS_AUDIT
  TABLES (
    sla AS BARCLAYS_HOL.AUDIT_PACK.PAYMENT_SLA_DAILY
      PRIMARY KEY (PAYMENT_DAY, PAYMENT_TYPE)
      WITH SYNONYMS = ('sla', 'payment schemes', 'service levels')
      COMMENT = 'Daily payments and SLA compliance per payment scheme',
    accounts AS BARCLAYS_HOL.AUDIT_PACK.CLIENT_ACCOUNTS
      PRIMARY KEY (ACCOUNT_ID)
      WITH SYNONYMS = ('clients', 'client accounts')
      COMMENT = 'Client accounts with relationship manager'
  )
  FACTS (
    sla.total_payments AS TOTAL_PAYMENTS COMMENT = 'Number of payments',
    sla.failed_payments AS FAILED_PAYMENTS COMMENT = 'Payments with FAILED status',
    sla.total_volume_gbp AS TOTAL_VOLUME_GBP WITH SYNONYMS = ('volume') COMMENT = 'Payment volume in GBP',
    sla.success_rate_pct AS SUCCESS_RATE_PCT COMMENT = 'Daily success rate (%)'
  )
  DIMENSIONS (
    sla.payment_day AS PAYMENT_DAY COMMENT = 'Payment date',
    sla.payment_type AS PAYMENT_TYPE WITH SYNONYMS = ('scheme') COMMENT = 'Payment scheme',
    sla.sla_status AS SLA_STATUS COMMENT = 'COMPLIANT, AT RISK or BREACH',
    accounts.customer_name AS CUSTOMER_NAME WITH SYNONYMS = ('client') COMMENT = 'Client name',
    accounts.customer_sector AS CUSTOMER_SECTOR COMMENT = 'Client sector',
    accounts.rm_name AS RM_NAME WITH SYNONYMS = ('relationship manager') COMMENT = 'Relationship manager',
    accounts.account_type AS ACCOUNT_TYPE COMMENT = 'Account type'
  )
  METRICS (
    sla.payment_volume AS SUM(sla.total_volume_gbp) COMMENT = 'Total payment volume in GBP',
    sla.success_rate AS ROUND((SUM(sla.total_payments) - SUM(sla.failed_payments)) / NULLIF(SUM(sla.total_payments), 0) * 100, 1)
      COMMENT = 'Weighted success rate (%), excluding failed payments',
    sla.breach_days AS COUNT_IF(sla.sla_status = 'BREACH') COMMENT = 'Scheme-days in SLA breach',
    accounts.account_count AS COUNT(accounts.account_id) COMMENT = 'Number of client accounts'
  )
  COMMENT = 'GOV2 audit pack: payments SLA and client accounts';

CREATE OR REPLACE AGENT PAYMENTS_AUDIT_AGENT
  COMMENT = 'GOV2 audit pack agent: answers payments SLA and client account questions so its usage can be audited'
  PROFILE = '{"display_name": "Payments Audit Agent", "color": "green"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  instructions:
    response: "Answer briefly. Keep tables to 10 rows or fewer."
    orchestration: "Use the Analyst tool for questions about payment schemes, SLA compliance, clients, accounts and relationship managers."
    sample_questions:
      - question: "Which payment scheme had the most SLA breach days?"
      - question: "What is the success rate by payment scheme?"
      - question: "How many client accounts does each relationship manager look after?"
  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "Analyst"
        description: "Daily payments and SLA compliance per scheme, and client accounts by sector and relationship manager."
  tool_resources:
    Analyst:
      semantic_view: "BARCLAYS_HOL.AUDIT_PACK.SV_PAYMENTS_AUDIT"
      execution_environment:
        type: "warehouse"
        warehouse: "BARCLAYS_WH"
  $$;

SHOW OBJECTS IN SCHEMA BARCLAYS_HOL.AUDIT_PACK;
