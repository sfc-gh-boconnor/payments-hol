-- =====================================================
-- VIGNETTE OPS2: ALERT TRIAGE + NEGATIVE SENTIMENT FEED   (~30 min)
-- Persona: Payments Operations analyst / team lead
-- Question: "Which open alerts should my team work first, what should we do,
--            and which unhappy clients are linked to them?"
-- Prereq:   setup/catchup/core_analytics.sql (FEEDBACK_ENRICHED, STG_* views)
-- =====================================================

USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;   -- see exactly what an attendee sees
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.ANALYTICS;

-- -----------------------------------------------------
-- OPS2.1 Live negative-sentiment feed for the CX escalation queue
-- -----------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE DT_NEGATIVE_SENTIMENT_FEED
    TARGET_LAG = '5 minutes'
    WAREHOUSE  = BARCLAYS_WH
AS
SELECT FEEDBACK_ID, FEEDBACK_DATE, CUSTOMER_ID, CUSTOMER_NAME, CUSTOMER_SECTOR,
       RM_NAME, PAYMENT_ID, PAYMENT_TYPE, FEEDBACK_TEXT, SENTIMENT_SCORE, TOPIC_CATEGORY
FROM FEEDBACK_ENRICHED
WHERE SENTIMENT_LABEL = 'NEGATIVE';

-- -----------------------------------------------------
-- OPS2.2 Prioritised triage queue: open alerts, scored for urgency
-- -----------------------------------------------------
CREATE OR REPLACE VIEW V_ALERT_TRIAGE_QUEUE AS
SELECT al.ALERT_ID, al.ALERT_TIME, al.SEVERITY, al.STATUS, al.ASSIGNED_TO,
       al.PAYMENT_TYPE, al.ALERT_DESCRIPTION,
       p.PAYMENT_ID, p.AMOUNT, p.CURRENCY, p.STATUS AS PAYMENT_STATUS,
       e.ERROR_CODE, e.ERROR_DESCRIPTION, e.ERROR_CATEGORY, e.IS_RETRYABLE,
       c.CUSTOMER_NAME, c.RM_NAME,
       COUNT(n.FEEDBACK_ID) AS CLIENT_NEGATIVE_FEEDBACK,
       -- simple, explainable priority score
       DECODE(al.SEVERITY, 'CRITICAL', 40, 'HIGH', 25, 'MEDIUM', 10, 0)
         + IFF(p.AMOUNT >= 1000000, 30, IFF(p.AMOUNT >= 100000, 15, 0))
         + LEAST(COUNT(n.FEEDBACK_ID), 20)
         + IFF(e.ERROR_CATEGORY = 'COMPLIANCE', 10, 0)        AS PRIORITY_SCORE
FROM BARCLAYS_HOL.RAW_DATA.OPERATIONAL_ALERTS al
JOIN STG_PAYMENTS p          ON al.PAYMENT_ID = p.PAYMENT_ID
LEFT JOIN BARCLAYS_HOL.RAW_DATA.ERROR_CODES e ON p.ERROR_CODE = e.ERROR_CODE
LEFT JOIN STG_ACCOUNTS a     ON p.ORIGINATOR_ACCOUNT_ID = a.ACCOUNT_ID
LEFT JOIN STG_CUSTOMERS c    ON a.CUSTOMER_ID = c.CUSTOMER_ID
LEFT JOIN DT_NEGATIVE_SENTIMENT_FEED n ON n.CUSTOMER_ID = c.CUSTOMER_ID
WHERE al.STATUS <> 'RESOLVED'
GROUP BY ALL;

SELECT ALERT_ID, SEVERITY, PAYMENT_TYPE, AMOUNT, ERROR_DESCRIPTION, CUSTOMER_NAME,
       CLIENT_NEGATIVE_FEEDBACK, PRIORITY_SCORE
FROM V_ALERT_TRIAGE_QUEUE
ORDER BY PRIORITY_SCORE DESC
LIMIT 10;

-- -----------------------------------------------------
-- OPS2.3 AI-recommended next action for the top of the queue
-- -----------------------------------------------------
CREATE OR REPLACE TABLE ALERT_RECOMMENDATIONS AS
SELECT ALERT_ID, SEVERITY, PAYMENT_TYPE, CUSTOMER_NAME, RM_NAME, PRIORITY_SCORE,
       AI_COMPLETE('claude-sonnet-4-5',
         'You are a senior payments operations analyst at a UK bank. In at most 3 short bullet points, '
         || 'give the next actions for this alert, including whether to retry the payment and whether to contact the client or their RM. '
         || 'Alert: ' || ALERT_DESCRIPTION
         || ' | Scheme: ' || PAYMENT_TYPE
         || ' | Error: ' || COALESCE(ERROR_DESCRIPTION, 'none') || ' (' || COALESCE(ERROR_CATEGORY, 'n/a')
         || ', retryable=' || COALESCE(IS_RETRYABLE::STRING, 'unknown') || ')'
         || ' | Amount: ' || AMOUNT || ' ' || CURRENCY
         || ' | Client negative feedback items: ' || CLIENT_NEGATIVE_FEEDBACK) AS RECOMMENDED_ACTION
FROM V_ALERT_TRIAGE_QUEUE
ORDER BY PRIORITY_SCORE DESC
LIMIT 10;

SELECT ALERT_ID, SEVERITY, CUSTOMER_NAME, RECOMMENDED_ACTION
FROM ALERT_RECOMMENDATIONS ORDER BY PRIORITY_SCORE DESC;

-- -----------------------------------------------------
-- OPS2.4 Hand it to the business
--  * Add V_ALERT_TRIAGE_QUEUE to SV_CLIENT_360 (ask CoCo to extend DA1's view), or
--  * Open payments-dashboard/ (Streamlit) and ask CoCo:
--    "Add a 'Triage' page to the Streamlit app that shows V_ALERT_TRIAGE_QUEUE
--     ordered by PRIORITY_SCORE with ALERT_RECOMMENDATIONS alongside."
-- -----------------------------------------------------

SELECT 'OPS2 complete' AS STATUS;
