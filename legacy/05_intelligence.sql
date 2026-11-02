-- =====================================================
-- BARCLAYS HANDS-ON LAB
-- STEP 5: SEMANTIC VIEW + CORTEX AGENT
-- Creates a Semantic View with relationships, metrics,
-- verified queries, and AI instructions via DDL
-- =====================================================

USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.ANALYTICS;

-- =====================================================
-- 5.1: Create Semantic View
-- 3 logical tables, 1 relationship, 15 dimensions,
-- 16 facts, 7 metrics, 8 verified queries
-- =====================================================

CREATE OR REPLACE SEMANTIC VIEW SV_PAYMENTS

  -- Logical tables
  TABLES (
    payments AS BARCLAYS_HOL.ANALYTICS.MART_PAYMENT_KPIS
      PRIMARY KEY (PAYMENT_DAY, PAYMENT_TYPE, REGION, CHANNEL, CUSTOMER_SECTOR, RM_NAME, RM_TEAM)
      WITH SYNONYMS = ('payment data', 'transactions')
      COMMENT = 'Daily payment KPIs by scheme, region, channel, sector, and RM',

    sla AS BARCLAYS_HOL.ANALYTICS.MART_SLA_COMPLIANCE
      PRIMARY KEY (PAYMENT_DAY, PAYMENT_TYPE)
      WITH SYNONYMS = ('sla data', 'compliance', 'service levels')
      COMMENT = 'Daily SLA compliance per payment scheme',

    feedback AS BARCLAYS_HOL.ANALYTICS.FEEDBACK_ENRICHED
      PRIMARY KEY (FEEDBACK_ID)
      WITH SYNONYMS = ('customer feedback', 'sentiment', 'complaints')
      COMMENT = 'AI-enriched customer feedback with sentiment and topic classification'
  )

  -- Relationships
  RELATIONSHIPS (
    payments_sla AS payments (PAYMENT_DAY, PAYMENT_TYPE)
      REFERENCES sla (PAYMENT_DAY, PAYMENT_TYPE)
  )

  -- Facts
  FACTS (
    -- Payment facts
    payments.total_payments AS TOTAL_PAYMENTS
      COMMENT = 'Number of payments',
    payments.successful_payments AS SUCCESSFUL_PAYMENTS
      COMMENT = 'Payments with COMPLETED status',
    payments.failed_payments AS FAILED_PAYMENTS
      COMMENT = 'Payments with FAILED status',
    payments.total_volume_gbp AS TOTAL_VOLUME_GBP
      WITH SYNONYMS = ('volume', 'payment volume')
      COMMENT = 'Total amount in GBP',
    payments.avg_payment_amount AS AVG_PAYMENT_AMOUNT
      COMMENT = 'Average payment amount in GBP',
    payments.avg_processing_time_ms AS AVG_PROCESSING_TIME_MS
      WITH SYNONYMS = ('average latency')
      COMMENT = 'Average processing time (ms)',
    payments.p95_processing_time_ms AS P95_PROCESSING_TIME_MS
      WITH SYNONYMS = ('p95 latency', 'p95')
      COMMENT = '95th percentile processing time (ms)',

    -- SLA facts
    sla.sla_target_pct AS SLA_TARGET_PCT
      COMMENT = 'SLA target success rate',
    sla.sla_threshold_ms AS SLA_THRESHOLD_MS
      COMMENT = 'SLA max P95 (ms)',
    sla.actual_success_rate AS ACTUAL_SUCCESS_RATE
      COMMENT = 'Actual daily success rate',
    sla.actual_p95_ms AS ACTUAL_P95_MS
      COMMENT = 'Actual daily P95 (ms)',
    sla.rate_gap_pct AS RATE_GAP_PCT
      COMMENT = 'Success rate gap vs target',
    sla.time_gap_ms AS TIME_GAP_MS
      COMMENT = 'P95 gap vs threshold (ms)',

    -- Feedback facts
    feedback.rating AS RATING
      COMMENT = 'Satisfaction rating 1 to 5',
    feedback.sentiment_score AS SENTIMENT_SCORE
      WITH SYNONYMS = ('sentiment')
      COMMENT = 'AI sentiment -1.0 to +1.0',
    feedback.classification_confidence AS CLASSIFICATION_CONFIDENCE
      COMMENT = 'AI classification confidence'
  )

  -- Dimensions
  DIMENSIONS (
    -- Payment dimensions
    payments.payment_type AS PAYMENT_TYPE
      WITH SYNONYMS = ('scheme', 'payment scheme', 'rail')
      COMMENT = 'CHAPS, FASTER_PAYMENTS, BACS, SWIFT, SEPA, WIRE_TRANSFER',
    payments.channel AS CHANNEL
      COMMENT = 'API, Online Banking, Branch, File Upload, Mobile',
    payments.region AS REGION
      COMMENT = 'UK, EMEA, APAC, Americas',
    payments.customer_sector AS CUSTOMER_SECTOR
      WITH SYNONYMS = ('sector', 'industry')
      COMMENT = 'Industry sector of originating customer',
    payments.rm_name AS RM_NAME
      WITH SYNONYMS = ('relationship manager', 'RM', 'account manager')
      COMMENT = 'Relationship manager name',
    payments.rm_team AS RM_TEAM
      COMMENT = 'Corporate Banking, Institutional Banking, SME Banking',

    -- SLA dimensions
    sla.sla_name AS SLA_NAME
      COMMENT = 'SLA definition name',
    sla.sla_status AS SLA_STATUS
      WITH SYNONYMS = ('compliance status')
      COMMENT = 'COMPLIANT, AT RISK, or BREACH',

    -- Feedback dimensions (enables sentiment/rating breakdown by scheme, sector, RM)
    feedback.feedback_payment_type AS PAYMENT_TYPE
      WITH SYNONYMS = ('feedback scheme', 'sentiment scheme')
      COMMENT = 'Payment scheme on feedback rows: CHAPS, FASTER_PAYMENTS, BACS, SWIFT, SEPA',
    feedback.customer_name AS CUSTOMER_NAME
      WITH SYNONYMS = ('customer', 'client')
      COMMENT = 'Feedback customer',
    feedback.feedback_sector AS CUSTOMER_SECTOR
      WITH SYNONYMS = ('feedback sector')
      COMMENT = 'Sector of the customer who gave feedback',
    feedback.feedback_rm AS RM_NAME
      WITH SYNONYMS = ('feedback RM')
      COMMENT = 'RM of the customer who gave feedback',
    feedback.feedback_channel AS FEEDBACK_CHANNEL
      COMMENT = 'Email, Phone, Portal, Survey, Chat',
    feedback.sentiment_label AS SENTIMENT_LABEL
      COMMENT = 'POSITIVE, NEUTRAL, or NEGATIVE',
    feedback.topic_category AS TOPIC_CATEGORY
      WITH SYNONYMS = ('topic', 'feedback topic')
      COMMENT = 'AI-classified feedback topic'
  )

  -- Metrics (derived aggregations)
  METRICS (
    payments.success_rate AS
      ROUND(SUM(payments.successful_payments)::FLOAT
        / NULLIF(SUM(payments.total_payments), 0) * 100, 2)
      WITH SYNONYMS = ('success rate', 'completion rate')
      COMMENT = 'Weighted success rate',

    payments.failure_rate AS
      ROUND(SUM(payments.failed_payments)::FLOAT
        / NULLIF(SUM(payments.total_payments), 0) * 100, 2)
      WITH SYNONYMS = ('failure rate', 'error rate')
      COMMENT = 'Weighted failure rate',

    sla.breach_count AS
      COUNT(CASE WHEN sla.sla_status = 'BREACH' THEN 1 END)
      WITH SYNONYMS = ('breaches', 'sla breaches')
      COMMENT = 'Number of BREACH records',

    sla.at_risk_count AS
      COUNT(CASE WHEN sla.sla_status = 'AT RISK' THEN 1 END)
      COMMENT = 'Number of AT RISK records',

    feedback.avg_sentiment AS
      ROUND(AVG(feedback.sentiment_score), 3)
      WITH SYNONYMS = ('average sentiment')
      COMMENT = 'Average AI sentiment score',

    feedback.negative_feedback_count AS
      COUNT(CASE WHEN feedback.sentiment_label = 'NEGATIVE' THEN 1 END)
      WITH SYNONYMS = ('complaints', 'negative reviews')
      COMMENT = 'Count of negative feedback',

    feedback.avg_rating AS
      ROUND(AVG(feedback.rating), 1)
      WITH SYNONYMS = ('average rating', 'customer rating')
      COMMENT = 'Average satisfaction rating (1-5)'
  )

  COMMENT = 'Barclays Payments Operations — KPIs, SLA compliance, and customer sentiment'

  -- AI instructions
  AI_SQL_GENERATION
    'UK payments operations. Schemes: CHAPS (same-day domestic), FASTER_PAYMENTS (real-time domestic max 250K),
     BACS (T+2 domestic batch), SWIFT (T+2 international), SEPA (T+1 EUR), WIRE_TRANSFER (same-day domestic).
     SUCCESS RATE: always SUM(SUCCESSFUL_PAYMENTS)/SUM(TOTAL_PAYMENTS)*100, never AVG(SUCCESS_RATE_PCT).
     SLA: COMPLIANT=within thresholds, AT RISK=within 5pct of target, BREACH=below.
     VOLUME: TOTAL_VOLUME_GBP for money, TOTAL_PAYMENTS for counts.
     Processing times vary by scheme: FASTER_PAYMENTS ~500ms, SWIFT ~9000ms.
     Sentiment: -1 to +1, POSITIVE>0.3, NEGATIVE<-0.3.
     IMPORTANT: The feedback table has its own PAYMENT_TYPE, CUSTOMER_SECTOR, and RM_NAME dimensions.
     For sentiment/rating/feedback questions broken down by payment type, sector, or RM, query the
     feedback table directly using its own dimensions. Do NOT try to join to the payments table for these.'

  AI_QUESTION_CATEGORIZATION
    'Payment volumes/counts/rates/processing times/P95 -> payments table.
     SLA compliance/breaches/targets/at risk -> sla table.
     Satisfaction/sentiment/complaints/ratings/topics/feedback -> feedback table.
     Sentiment or ratings BY payment type/scheme -> feedback table (has its own PAYMENT_TYPE).
     Sentiment or ratings BY sector -> feedback table (has its own CUSTOMER_SECTOR).
     Sentiment or ratings BY RM -> feedback table (has its own RM_NAME).'

  -- Verified queries (teach the model how to answer common questions)
  AI_VERIFIED_QUERIES (
    monthly_volume AS (
      QUESTION 'What is the total payment volume this month?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT SUM(TOTAL_VOLUME_GBP) AS total_volume_gbp
           FROM BARCLAYS_HOL.ANALYTICS.MART_PAYMENT_KPIS
           WHERE PAYMENT_DAY >= DATE_TRUNC(''MONTH'', CURRENT_DATE())'
    ),
    success_by_scheme AS (
      QUESTION 'What is the success rate by payment scheme?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT PAYMENT_TYPE,
                  ROUND(SUM(SUCCESSFUL_PAYMENTS)::FLOAT / NULLIF(SUM(TOTAL_PAYMENTS), 0) * 100, 2) AS success_rate
           FROM BARCLAYS_HOL.ANALYTICS.MART_PAYMENT_KPIS
           GROUP BY PAYMENT_TYPE ORDER BY success_rate'
    ),
    sla_breaches AS (
      QUESTION 'Which schemes are breaching SLA?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT PAYMENT_TYPE, COUNT(*) AS breach_days
           FROM BARCLAYS_HOL.ANALYTICS.MART_SLA_COMPLIANCE
           WHERE SLA_STATUS = ''BREACH''
             AND PAYMENT_DAY >= DATEADD(''day'', -30, CURRENT_DATE())
           GROUP BY PAYMENT_TYPE ORDER BY breach_days DESC'
    ),
    top_rms AS (
      QUESTION 'Top 5 relationship managers by volume?'
      SQL 'SELECT RM_NAME, SUM(TOTAL_VOLUME_GBP) AS volume
           FROM BARCLAYS_HOL.ANALYTICS.MART_PAYMENT_KPIS
           WHERE RM_NAME IS NOT NULL
           GROUP BY RM_NAME ORDER BY volume DESC LIMIT 5'
    ),
    swift_p95 AS (
      QUESTION 'Average P95 latency for SWIFT?'
      SQL 'SELECT ROUND(AVG(P95_PROCESSING_TIME_MS)) AS avg_p95_ms
           FROM BARCLAYS_HOL.ANALYTICS.MART_PAYMENT_KPIS
           WHERE PAYMENT_TYPE = ''SWIFT'''
    ),
    weekly_trend AS (
      QUESTION 'Weekly payment volume trend'
      SQL 'SELECT DATE_TRUNC(''WEEK'', PAYMENT_DAY) AS week,
                  SUM(TOTAL_PAYMENTS) AS payments
           FROM BARCLAYS_HOL.ANALYTICS.MART_PAYMENT_KPIS
           GROUP BY week ORDER BY week'
    ),
    failed_sectors AS (
      QUESTION 'Which sectors have the most failures?'
      SQL 'SELECT CUSTOMER_SECTOR, SUM(FAILED_PAYMENTS) AS failures
           FROM BARCLAYS_HOL.ANALYTICS.MART_PAYMENT_KPIS
           WHERE CUSTOMER_SECTOR IS NOT NULL
           GROUP BY CUSTOMER_SECTOR ORDER BY failures DESC'
    ),
    sentiment_schemes AS (
      QUESTION 'How does customer sentiment compare across payment types?'
      ONBOARDING_QUESTION TRUE
      SQL 'SELECT PAYMENT_TYPE, ROUND(AVG(SENTIMENT_SCORE), 3) AS avg_sentiment,
                  COUNT(*) AS feedback_count
           FROM BARCLAYS_HOL.ANALYTICS.FEEDBACK_ENRICHED
           GROUP BY PAYMENT_TYPE ORDER BY avg_sentiment'
    )
  );

-- Verify
SHOW SEMANTIC VIEWS IN SCHEMA BARCLAYS_HOL.ANALYTICS;
SHOW SEMANTIC METRICS IN SV_PAYMENTS;
SHOW SEMANTIC DIMENSIONS IN SV_PAYMENTS;

-- =====================================================
-- 5.2: Create Cortex Agent
-- This agent is usable in CoWork, REST API, and SQL
-- =====================================================

CREATE OR REPLACE AGENT BARCLAYS_HOL.ANALYTICS.PAYMENTS_ASSISTANT
  COMMENT = 'Payments operations assistant for Barclays HOL. Answers questions about payment volumes, SLA compliance, processing times, customer sectors, relationship managers, and customer sentiment.'
  PROFILE = '{"display_name": "Payments Assistant", "color": "blue"}'
  FROM SPECIFICATION
  $$
  orchestration:
    tool_not_accessible: accept
    budget:
      seconds: 60
      tokens: 16000

  models:
    orchestration: auto

  instructions:
    response: >
      You are a payments operations assistant for a UK bank.
      Answer questions clearly and concisely using data from the payments operations semantic view.
      When presenting numbers, use appropriate formatting (commas for thousands, percentages with 1 decimal).
      If asked about success rates, always use the weighted calculation: SUM(successful)/SUM(total)*100.
      If the data does not contain enough information to answer, say so rather than guessing.
      When showing tables, keep them to 10 rows or fewer unless the user asks for more.

    orchestration: >
      Use the Analyst tool for all questions about payment volumes, success rates, processing times,
      SLA compliance, customer sectors, relationship managers, channels, regions, and customer sentiment.
      The semantic view contains three logical tables:
        - payments: daily KPIs by scheme, region, channel, sector, and RM
        - sla: daily SLA compliance status per scheme (COMPLIANT, AT RISK, BREACH)
        - feedback: AI-enriched customer feedback with sentiment scores, topic classification,
          and its own PAYMENT_TYPE, CUSTOMER_SECTOR, and RM_NAME dimensions
      For sentiment or feedback broken down by payment type, sector, or RM, the feedback table
      has its own dimensions for these — no need to join to the payments table.

    sample_questions:
      - question: "What is the total payment volume this month?"
      - question: "Which payment scheme has the lowest success rate?"
      - question: "How many SLA breaches occurred last week?"
      - question: "Which relationship manager handles the most volume?"
      - question: "How does customer sentiment compare across payment types?"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "Analyst"
        description: >
          Queries payment operations data including daily payment KPIs (volume, success rates,
          processing times), SLA compliance (breach/at-risk/compliant status), and AI-enriched
          customer feedback (sentiment scores, topic classification). Data covers 6 UK payment
          schemes (CHAPS, Faster Payments, BACS, SWIFT, SEPA, Wire Transfer) with dimensions
          for region, channel, customer sector, and relationship manager.
    - tool_spec:
        type: "data_to_chart"
        name: "data_to_chart"
        description: "Generates charts and visualizations from query results"

  tool_resources:
    Analyst:
      semantic_view: "BARCLAYS_HOL.ANALYTICS.SV_PAYMENTS"
      execution_environment:
        type: "warehouse"
        warehouse: "BARCLAYS_WH"
  $$;

-- Verify agent
SHOW AGENTS IN SCHEMA BARCLAYS_HOL.ANALYTICS;

-- =====================================================
-- 5.3: Test the agent in CoWork
--
-- STEPS:
--   1. Go to: Snowflake CoWork (click the CoWork icon in the left nav)
--   2. The Payments Assistant should appear as an available agent
--   3. Start a conversation and try the sample questions below
--
-- SAMPLE QUESTIONS:
--   "What is the total payment volume this month?"
--   "Which payment scheme has the lowest success rate?"
--   "Show me the weekly trend of CHAPS payments"
--   "Compare success rates across all regions"
--   "Which relationship manager handles the most volume?"
--   "What sectors have the most failed payments?"
--   "How many SLA breaches occurred last week?"
--   "How does customer sentiment compare across payment types?"
--   "What are the most common feedback topics?"
--   "Show me the top 5 customers by payment volume"
--   "What is the average P95 latency for each scheme?"
--   "Break down payment volume by channel for SWIFT"
-- =====================================================
