-- =====================================================
-- AI4: AI SQL ON CALL TRANSCRIPTS, COMPLAINTS AND FINANCIAL CRIME EVIDENCE - reference SQL
-- Approved AI SQL functions only (AI_SENTIMENT, AI_CLASSIFY, AI_EXTRACT, AI_AGG, AI_COMPLETE).
-- Run as HOL_PARTICIPANT. Samples keep the AI credits small; drop the LIMITs to do the lot.
-- =====================================================
USE SECONDARY ROLES NONE;
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.ANALYTICS;

-- 1. Enrich call transcripts once: sentiment, reason and vulnerability cues
CREATE OR REPLACE TABLE RB_CALL_INSIGHTS AS
SELECT t.CALL_ID, t.CUSTOMER_ID, t.CALL_START_TS, t.QUEUE, t.TOPIC,
       AI_SENTIMENT(t.TRANSCRIPT):categories[0]:sentiment::VARCHAR AS SENTIMENT,
       AI_CLASSIFY(t.TRANSCRIPT, ['savings rates', 'branch access', 'service complaint', 'fraud or scam',
                                 'financial difficulty', 'card or app problem', 'product question', 'account admin']):labels[0]::VARCHAR AS CALL_REASON,
       AI_CLASSIFY(t.TRANSCRIPT, ['mentions health or disability', 'mentions bereavement', 'mentions money worries', 'none'],
                   {'output_mode': 'multi'}):labels AS VULNERABILITY_CUES,
       c.CHURNED, c.AFFORDABILITY_BAND
FROM BARCLAYS_HOL.RAW_DATA.RB_CALL_TRANSCRIPTS t
JOIN BARCLAYS_HOL.RAW_DATA.RB_CUSTOMERS c ON c.CUSTOMER_ID = t.CUSTOMER_ID
WHERE t.CALL_START_TS >= '2026-08-01'
LIMIT 300;

-- Does call sentiment line up with who left?
SELECT CALL_REASON, COUNT(*) AS CALLS, ROUND(100 * AVG(IFF(SENTIMENT = 'negative', 1, 0))) AS PCT_NEGATIVE,
       ROUND(100 * AVG(IFF(CHURNED, 1, 0))) AS PCT_CALLERS_WHO_LEFT
FROM RB_CALL_INSIGHTS GROUP BY 1 ORDER BY CALLS DESC;

-- 2. Pull structured fields out of complaints
SELECT COMPLAINT_ID, CATEGORY,
       AI_EXTRACT(text => COMPLAINT_TEXT, responseFormat => {
           'product': 'Which bank product is the complaint about?',
           'amount_gbp': 'What amount of money in pounds is mentioned, as a number?',
           'requested_outcome': 'What does the customer want the bank to do?'}):response AS EXTRACTED
FROM BARCLAYS_HOL.RAW_DATA.RB_COMPLAINTS
LIMIT 10;

-- 3. What leavers said in the 3 months before leaving, in one paragraph
SELECT AI_AGG(t.TRANSCRIPT, 'These calls are from retail bank customers who closed their accounts soon after. List the top 5 reasons they gave, with how often each came up, and one action the bank could take for each.') AS WHY_THEY_LEFT
FROM BARCLAYS_HOL.RAW_DATA.RB_CALL_TRANSCRIPTS t
JOIN BARCLAYS_HOL.RAW_DATA.RB_CUSTOMERS c ON c.CUSTOMER_ID = t.CUSTOMER_ID
WHERE c.CHURNED AND t.CALL_START_TS BETWEEN DATEADD(month, -3, c.CHURN_DATE) AND c.CHURN_DATE;

-- 4. Police report PDFs: extract the crime reference and loss, and reconcile to the case
SELECT e.CASE_ID, f.LOSS_GBP AS CASE_LOSS_GBP,
       AI_EXTRACT(file => TO_FILE('@BARCLAYS_HOL.RETAIL.FINCRIME_EVIDENCE', e.FILE_NAME), responseFormat => {
           'crime_reference': 'What is the crime reference number?',
           'date_reported': 'What date was it reported?',
           'amount_lost': 'What amount was lost, as a number?'}):response AS FROM_PDF
FROM BARCLAYS_HOL.RAW_DATA.RB_EVIDENCE_FILES e
JOIN BARCLAYS_HOL.RAW_DATA.RB_FRAUD_CASES f ON f.CASE_ID = e.CASE_ID
WHERE e.EVIDENCE_TYPE = 'POLICE_REPORT_PDF'
LIMIT 5;

-- 5. Phishing screenshots: who is being impersonated, and the red flags
SELECT e.CASE_ID, e.FILE_NAME,
       AI_COMPLETE('claude-sonnet-4-5',
                   'This is a screenshot a fraud victim sent to their bank. Which organisation does the message impersonate, and what are its red flags? Answer in two short lines.',
                   TO_FILE('@BARCLAYS_HOL.RETAIL.FINCRIME_EVIDENCE', e.FILE_NAME)) AS ANALYSIS
FROM BARCLAYS_HOL.RAW_DATA.RB_EVIDENCE_FILES e
WHERE e.EVIDENCE_TYPE = 'PHISHING_SCREENSHOT'
LIMIT 3;

-- 6. One fraud case file, summarised into a decision draft from every source
SELECT f.CASE_ID, f.DECISION, c.AGE, c.VULNERABLE_FLAG,
       AI_COMPLETE('claude-sonnet-4-5', CONCAT(
           'You are a fraud operations team leader. Draft a 150-word case summary and a reimbursement recommendation, ',
           'citing the evidence, and flag anything in the sources that disagrees. Case notes: ', f.INVESTIGATOR_NOTES,
           ' Customer call: ', COALESCE(t.TRANSCRIPT, 'none'),
           ' Customer age: ', c.AGE, '. On the vulnerable customers register: ', IFF(c.VULNERABLE_FLAG, 'yes', 'no'),
           '. Decision recorded: ', f.DECISION)) AS DECISION_DRAFT
FROM BARCLAYS_HOL.RAW_DATA.RB_FRAUD_CASES f
JOIN BARCLAYS_HOL.RAW_DATA.RB_CUSTOMERS c ON c.CUSTOMER_ID = f.CUSTOMER_ID
LEFT JOIN BARCLAYS_HOL.RAW_DATA.RB_CALL_TRANSCRIPTS t
       ON t.CUSTOMER_ID = f.CUSTOMER_ID AND t.QUEUE = 'FRAUD' AND t.TXN_ID = f.FIRST_FRAUD_TXN_ID
WHERE f.FRAUD_TYPE = 'APP_SCAM' AND t.CALL_ID IS NOT NULL
ORDER BY f.CASE_ID
LIMIT 1;

-- 7. SAR narrative quality check: one AI_EXTRACT question per element, scored against the planted QA_ISSUE
WITH x AS (
    SELECT SAR_ID, QA_ISSUE,
           AI_EXTRACT(text => NARRATIVE, responseFormat => {
               'reason': 'Why does the bank consider this activity suspicious? Answer None if no reason is given.',
               'date':   'What is the specific date of the activity? Answer None if no date is given.',
               'amount': 'What specific amount of money in pounds is mentioned? Answer None if none.',
               'action': 'What action did the bank take or will it take? Answer None if no action is stated.'}):response AS R
    FROM BARCLAYS_HOL.RAW_DATA.RB_SAR_NARRATIVES
), f AS (
    SELECT SAR_ID, QA_ISSUE,
           CASE WHEN COALESCE(R:date::STRING, 'none') ILIKE 'none%' OR COALESCE(R:amount::STRING, 'none') ILIKE 'none%' THEN 'MISSING_DATES_AMOUNTS'
                WHEN COALESCE(R:action::STRING, 'none') ILIKE 'none%' THEN 'MISSING_ACTION'
                WHEN COALESCE(R:reason::STRING, 'none') ILIKE 'none%' THEN 'MISSING_REASON'
                ELSE 'COMPLETE' END AS AI_FINDING
    FROM x
)
SELECT QA_ISSUE, AI_FINDING, COUNT(*) AS SARS,
       ROUND(100 * SUM(COUNT_IF(QA_ISSUE = AI_FINDING)) OVER () / SUM(COUNT(*)) OVER ()) AS PCT_MATCH
FROM f GROUP BY 1, 2 ORDER BY 1, 3 DESC;
