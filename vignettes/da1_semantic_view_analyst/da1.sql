-- =====================================================
-- VIGNETTE DA1: BUILD A SEMANTIC VIEW + ASK CORTEX ANALYST   (~60 min)
-- Persona: Data Analyst
-- Question: "Give RMs and ops a single, trusted definition of a corporate
--            client's payments health that anyone can query in plain English."
-- Prereq:   setup/catchup/core_analytics.sql  (STG_* views, FEEDBACK_ENRICHED)
-- Builds:   V_CLIENT_PAYMENT_SUMMARY, V_CLIENT_ALERTS, SV_CLIENT_360
-- (SV_PAYMENTS from the original lab is in setup/catchup/semantic_view_and_agent.sql
--  - open it and compare as a worked example.)
-- =====================================================

USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;   -- see exactly what an attendee sees
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.ANALYTICS;

-- -----------------------------------------------------
-- DA1.1 Stable interface views (semantic views should sit on contracts, not raw)
-- -----------------------------------------------------
CREATE OR REPLACE VIEW V_CLIENT_PAYMENT_SUMMARY
    COMMENT = 'One row per corporate client: payment volumes, success and latency'
AS
SELECT c.CUSTOMER_ID,
       COUNT(*)                                                     AS TOTAL_PAYMENTS,
       COUNT_IF(p.IS_SUCCESSFUL)                                    AS SUCCESSFUL_PAYMENTS,
       COUNT_IF(p.IS_FAILED)                                        AS FAILED_PAYMENTS,
       SUM(p.AMOUNT)                                                AS TOTAL_VOLUME_GBP,
       SUM(IFF(p.IS_FAILED, p.AMOUNT, 0))                           AS FAILED_VOLUME_GBP,
       ROUND(AVG(p.PROCESSING_TIME_MS), 0)                          AS AVG_PROCESSING_TIME_MS,
       MAX(p.PAYMENT_DATE)                                          AS LAST_PAYMENT_DATE
FROM STG_PAYMENTS p
JOIN STG_ACCOUNTS  a ON p.ORIGINATOR_ACCOUNT_ID = a.ACCOUNT_ID
JOIN STG_CUSTOMERS c ON a.CUSTOMER_ID = c.CUSTOMER_ID
GROUP BY c.CUSTOMER_ID;

CREATE OR REPLACE VIEW V_CLIENT_ALERTS
    COMMENT = 'Operational alerts attributed to the originating corporate client'
AS
SELECT al.ALERT_ID, a.CUSTOMER_ID, al.ALERT_TIME::TIMESTAMP AS ALERT_TIME,
       al.SEVERITY, al.PAYMENT_TYPE, al.STATUS AS ALERT_STATUS,
       al.ASSIGNED_TO, al.RESOLUTION_TIME_MIN, al.ALERT_DESCRIPTION
FROM BARCLAYS_HOL.RAW_DATA.OPERATIONAL_ALERTS al
JOIN BARCLAYS_HOL.RAW_DATA.PAYMENTS p ON al.PAYMENT_ID = p.PAYMENT_ID
JOIN BARCLAYS_HOL.RAW_DATA.ACCOUNTS a ON p.ORIGINATOR_ACCOUNT_ID = a.ACCOUNT_ID;

-- -----------------------------------------------------
-- DA1.2 The semantic view: business names, relationships, metrics, synonyms
-- Tip: you can also build this in Snowsight (AI & ML > Cortex Analyst > Create)
-- or ask CoCo: "Create a semantic view over STG_CUSTOMERS, V_CLIENT_PAYMENT_SUMMARY,
-- FEEDBACK_ENRICHED and V_CLIENT_ALERTS joined on CUSTOMER_ID."
-- -----------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW SV_CLIENT_360

  TABLES (
    clients AS BARCLAYS_HOL.ANALYTICS.STG_CUSTOMERS
      PRIMARY KEY (CUSTOMER_ID)
      WITH SYNONYMS = ('customers', 'corporate clients', 'accounts')
      COMMENT = 'Corporate banking clients with KYC status and assigned relationship manager',
    payments AS BARCLAYS_HOL.ANALYTICS.V_CLIENT_PAYMENT_SUMMARY
      PRIMARY KEY (CUSTOMER_ID)
      COMMENT = 'Payment activity summary per client',
    feedback AS BARCLAYS_HOL.ANALYTICS.FEEDBACK_ENRICHED
      PRIMARY KEY (FEEDBACK_ID)
      WITH SYNONYMS = ('complaints', 'customer feedback', 'sentiment')
      COMMENT = 'Client feedback with AI sentiment and topic',
    alerts AS BARCLAYS_HOL.ANALYTICS.V_CLIENT_ALERTS
      PRIMARY KEY (ALERT_ID)
      WITH SYNONYMS = ('incidents', 'operational alerts')
      COMMENT = 'Operational payment alerts per client'
  )

  RELATIONSHIPS (
    payments_to_clients AS payments (CUSTOMER_ID) REFERENCES clients,
    feedback_to_clients AS feedback (CUSTOMER_ID) REFERENCES clients,
    alerts_to_clients   AS alerts   (CUSTOMER_ID) REFERENCES clients
  )

  FACTS (
    payments.total_payments      AS TOTAL_PAYMENTS,
    payments.successful_payments AS SUCCESSFUL_PAYMENTS,
    payments.failed_payments     AS FAILED_PAYMENTS,
    payments.total_volume_gbp    AS TOTAL_VOLUME_GBP,
    payments.failed_volume_gbp   AS FAILED_VOLUME_GBP,
    feedback.sentiment_score     AS SENTIMENT_SCORE,
    feedback.rating              AS RATING,
    alerts.resolution_time_min   AS RESOLUTION_TIME_MIN
  )

  DIMENSIONS (
    clients.customer_name AS CUSTOMER_NAME
      WITH SYNONYMS = ('client', 'client name', 'company')
      COMMENT = 'Registered legal entity name (upper case)',
    clients.sector        AS SECTOR WITH SYNONYMS = ('industry'),
    clients.country       AS COUNTRY COMMENT = 'ISO alpha-3 country code',
    clients.kyc_status    AS KYC_STATUS COMMENT = 'APPROVED, PENDING_REVIEW, EXPIRED',
    clients.rm_name       AS RM_NAME WITH SYNONYMS = ('relationship manager', 'RM', 'banker'),
    clients.rm_team       AS RM_TEAM COMMENT = 'Corporate, Institutional or SME banking team',
    feedback.sentiment_label AS SENTIMENT_LABEL COMMENT = 'POSITIVE, NEUTRAL, NEGATIVE',
    feedback.topic_category  AS TOPIC_CATEGORY,
    feedback.feedback_payment_type AS PAYMENT_TYPE COMMENT = 'Payment scheme the feedback refers to',
    feedback.feedback_date   AS FEEDBACK_DATE,
    alerts.severity       AS SEVERITY COMMENT = 'LOW, MEDIUM, HIGH, CRITICAL',
    alerts.alert_status   AS ALERT_STATUS COMMENT = 'OPEN, ACKNOWLEDGED, INVESTIGATING, RESOLVED',
    alerts.alert_time     AS ALERT_TIME
  )

  METRICS (
    payments.payment_count     AS SUM(payments.total_payments) WITH SYNONYMS = ('number of payments'),
    payments.payment_volume    AS SUM(payments.total_volume_gbp) WITH SYNONYMS = ('volume', 'value'),
    payments.failed_volume     AS SUM(payments.failed_volume_gbp) WITH SYNONYMS = ('value at risk'),
    payments.success_rate_pct  AS ROUND(SUM(payments.successful_payments) / NULLIF(SUM(payments.total_payments), 0) * 100, 2)
      COMMENT = 'Weighted payment success rate %',
    feedback.avg_sentiment     AS ROUND(AVG(feedback.sentiment_score), 3),
    feedback.negative_feedback_count AS COUNT_IF(feedback.sentiment_label = 'NEGATIVE'),
    alerts.open_alert_count    AS COUNT_IF(alerts.alert_status <> 'RESOLVED') WITH SYNONYMS = ('open incidents'),
    alerts.critical_alert_count AS COUNT_IF(alerts.severity = 'CRITICAL'),
    alerts.avg_resolution_min  AS ROUND(AVG(alerts.resolution_time_min), 0)
  )

  COMMENT = 'Corporate Client 360 for Payments Operations: payments health, feedback sentiment and operational alerts per client'

  AI_SQL_GENERATION 'Client names are stored in upper case; match them case-insensitively with ILIKE. Round percentages to 1 decimal place.'

  AI_VERIFIED_QUERIES (
    worst_clients AS (
      QUESTION 'Which 5 clients have the lowest payment success rate?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT c.CUSTOMER_NAME, ROUND(SUM(p.SUCCESSFUL_PAYMENTS) / NULLIF(SUM(p.TOTAL_PAYMENTS), 0) * 100, 2) AS success_rate_pct
           FROM BARCLAYS_HOL.ANALYTICS.V_CLIENT_PAYMENT_SUMMARY p
           JOIN BARCLAYS_HOL.ANALYTICS.STG_CUSTOMERS c ON p.CUSTOMER_ID = c.CUSTOMER_ID
           GROUP BY c.CUSTOMER_NAME ORDER BY success_rate_pct ASC LIMIT 5'
    ),
    rm_open_alerts AS (
      QUESTION 'How many open alerts does each relationship manager have across their clients?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT c.RM_NAME, COUNT_IF(a.ALERT_STATUS <> ''RESOLVED'') AS open_alerts
           FROM BARCLAYS_HOL.ANALYTICS.V_CLIENT_ALERTS a
           JOIN BARCLAYS_HOL.ANALYTICS.STG_CUSTOMERS c ON a.CUSTOMER_ID = c.CUSTOMER_ID
           GROUP BY c.RM_NAME ORDER BY open_alerts DESC'
    )
  );

SHOW SEMANTIC METRICS IN SV_CLIENT_360;

-- -----------------------------------------------------
-- DA1.3 Query the semantic view with SQL (no joins to remember)
-- -----------------------------------------------------
SELECT * FROM SEMANTIC_VIEW(
    SV_CLIENT_360
    DIMENSIONS clients.rm_name
    METRICS payments.payment_volume, payments.success_rate_pct, alerts.open_alert_count
) ORDER BY open_alert_count DESC;

-- -----------------------------------------------------
-- DA1.4 Ask in plain English (Cortex Analyst)
-- Snowsight: AI & ML > Cortex Analyst > SV_CLIENT_360, or in Snowflake CoWork after OPS1.
-- Try:
--   "Which clients in Manufacturing have open critical alerts?"
--   "Compare success rate and average sentiment for each RM team"
--   "Which client has the most failed payment value and what are they complaining about?"
-- Check the generated SQL each time - that is the point of a trusted semantic layer.
-- -----------------------------------------------------

SELECT 'DA1 complete' AS STATUS;
