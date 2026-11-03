-- =====================================================
-- VIGNETTE DA2: AI SQL ON CUSTOMER FEEDBACK   (~45 min)
-- Persona: Data Analyst
-- Question: "What are corporate clients actually complaining about, by
--            scheme and by relationship manager - without reading 2,000 comments?"
-- Prereq:   setup/catchup/core_analytics.sql (for STG_* views), or DE1
-- All functions run inside Snowflake: no data leaves the platform, no model training.
-- =====================================================

USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;   -- see exactly what an attendee sees
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.ANALYTICS;

-- -----------------------------------------------------
-- DA2.1 Overall and aspect-based sentiment
-- AI_SENTIMENT scores the whole text and named aspects separately
-- -----------------------------------------------------
SELECT LEFT(FEEDBACK_TEXT, 90) AS FEEDBACK,
       AI_SENTIMENT(FEEDBACK_TEXT, ['speed', 'communication', 'fees']) AS ASPECT_SENTIMENT
FROM STG_FEEDBACK
LIMIT 5;

-- -----------------------------------------------------
-- DA2.2 Build the enriched feedback table (score once, query many times)
-- -----------------------------------------------------
CREATE OR REPLACE TABLE FEEDBACK_ENRICHED AS
WITH ai_scored AS (
    SELECT f.*, c.CUSTOMER_NAME, c.SECTOR AS CUSTOMER_SECTOR, c.RM_NAME,
           -- AI_SENTIMENT returns a label, so map the overall label to -1, 0 or 1
           -- (legacy SNOWFLAKE.CORTEX.SENTIMENT is blocked on new accounts)
           DECODE(GET(FILTER(AI_SENTIMENT(f.FEEDBACK_TEXT):categories, c -> c:name::STRING = 'overall'), 0):sentiment::STRING,
                  'positive', 1, 'negative', -1, 0)::FLOAT AS SENTIMENT_SCORE,
           AI_CLASSIFY(f.FEEDBACK_TEXT,
               ['Performance Issue','Service Quality','Technical Problem',
                'Positive Experience','Feature Request']) AS CLASSIFICATION_RESULT
    FROM STG_FEEDBACK f
    LEFT JOIN STG_CUSTOMERS c ON f.CUSTOMER_ID = c.CUSTOMER_ID
)
SELECT FEEDBACK_ID, FEEDBACK_DATE, CUSTOMER_ID, CUSTOMER_NAME, CUSTOMER_SECTOR, RM_NAME,
       PAYMENT_ID, FEEDBACK_CHANNEL, FEEDBACK_TEXT, PAYMENT_TYPE, RATING, SENTIMENT_SCORE,
       CASE WHEN SENTIMENT_SCORE >  0.3 THEN 'POSITIVE'
            WHEN SENTIMENT_SCORE < -0.3 THEN 'NEGATIVE'
            ELSE 'NEUTRAL' END                  AS SENTIMENT_LABEL,
       CLASSIFICATION_RESULT:labels[0]::STRING  AS TOPIC_CATEGORY
FROM ai_scored;

SELECT PAYMENT_TYPE, COUNT(*) AS FEEDBACK,
       ROUND(AVG(SENTIMENT_SCORE), 3) AS AVG_SENTIMENT,
       ROUND(COUNT_IF(SENTIMENT_LABEL = 'NEGATIVE') / COUNT(*) * 100, 1) AS NEGATIVE_PCT
FROM FEEDBACK_ENRICHED
GROUP BY PAYMENT_TYPE ORDER BY AVG_SENTIMENT;

-- -----------------------------------------------------
-- DA2.3 AI_FILTER: natural-language WHERE clause
-- -----------------------------------------------------
SELECT CUSTOMER_NAME, PAYMENT_TYPE, LEFT(FEEDBACK_TEXT, 120) AS FEEDBACK
FROM FEEDBACK_ENRICHED
WHERE SENTIMENT_LABEL = 'NEGATIVE'
  AND AI_FILTER(PROMPT('Does this feedback mention a risk of the client moving their business elsewhere? {0}', FEEDBACK_TEXT))
LIMIT 10;

-- -----------------------------------------------------
-- DA2.4 AI_AGG: themes across many rows, per relationship manager
-- One LLM summary per group - no row limit, no prompt stuffing
-- -----------------------------------------------------
CREATE OR REPLACE TABLE RM_FEEDBACK_THEMES AS
SELECT RM_NAME,
       COUNT(*) AS NEGATIVE_FEEDBACK,
       AI_AGG(FEEDBACK_TEXT,
              'You are briefing a corporate banking relationship manager. List the top 3 recurring complaint themes in this client feedback, each with a one-line recommended action. Be concise.') AS TOP_THEMES
FROM FEEDBACK_ENRICHED
WHERE SENTIMENT_LABEL = 'NEGATIVE' AND RM_NAME IS NOT NULL
GROUP BY RM_NAME;

SELECT RM_NAME, NEGATIVE_FEEDBACK, TOP_THEMES FROM RM_FEEDBACK_THEMES ORDER BY NEGATIVE_FEEDBACK DESC;

-- -----------------------------------------------------
-- DA2.5 AI_COMPLETE: draft a client-ready response for the worst item
-- -----------------------------------------------------
SELECT CUSTOMER_NAME, FEEDBACK_TEXT,
       AI_COMPLETE('claude-sonnet-4-5',
         'Draft a short, professional reply from a UK corporate bank to this client feedback. Acknowledge the issue, avoid admitting liability, offer a follow-up call. Feedback: ' || FEEDBACK_TEXT) AS DRAFT_REPLY
FROM FEEDBACK_ENRICHED
WHERE SENTIMENT_LABEL = 'NEGATIVE'
ORDER BY SENTIMENT_SCORE
LIMIT 1;

-- -----------------------------------------------------
-- DA2.6 Cortex Code prompts
--  "Using FEEDBACK_ENRICHED, show me which customer sectors have worsening
--   sentiment month over month and chart it."
--  "Use AI_EXTRACT on FEEDBACK_TEXT to pull out any payment reference or amount
--   mentioned, into a new table FEEDBACK_ENTITIES."
-- -----------------------------------------------------

SELECT 'DA2 complete' AS STATUS;
