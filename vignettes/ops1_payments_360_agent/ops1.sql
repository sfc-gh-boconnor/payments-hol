-- =====================================================
-- VIGNETTE OPS1: CORPORATE PAYMENTS 360 AGENT   (~45 min)
-- Persona: Payments Operations analyst (no SQL needed after setup)
-- Question: "Before I call a client, tell me everything: payments health,
--            open incidents, and what they have been complaining about."
-- Prereq:   setup/catchup/core_analytics.sql + DA1 (SV_CLIENT_360)
--           + setup/catchup/semantic_view_and_agent.sql (SV_PAYMENTS)
--           Facilitator shortcut: run all three catch-up/DA1 scripts in order.
-- =====================================================

USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;   -- see exactly what an attendee sees
USE WAREHOUSE BARCLAYS_WH;

-- -----------------------------------------------------
-- OPS1.1 The agent: two semantic views as tools + charting
-- Created in SNOWFLAKE_INTELLIGENCE.AGENTS so it appears in Snowflake
-- Intelligence / CoWork for everyone with access.
-- (Snowsight alternative: AI & ML > Agents > Create agent - same settings.)
-- -----------------------------------------------------
CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.CORPORATE_PAYMENTS_360
  COMMENT = 'Barclays HOL - Corporate Payments 360: client payments health, incidents and sentiment'
  PROFILE = '{"display_name": "Corporate Payments 360", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  orchestration:
    budget:
      seconds: 90
      tokens: 20000

  instructions:
    response: >
      You support Payments Operations and Relationship Managers in a UK corporate bank.
      Lead with a one-line summary, then the supporting numbers.
      Format money in GBP with thousands separators and percentages to 1 decimal place.
      When briefing on a client, always cover: payment volume and success rate,
      failed value, open and critical alerts, and feedback sentiment with the main topic.
      If the data cannot answer the question, say so - never guess.
    orchestration: >
      Use Client360 for anything about a specific client, relationship manager,
      KYC status, alerts or incidents, and client feedback.
      Use PaymentsOps for scheme-level and daily trends: volumes by scheme/region/channel,
      processing times, P95 latency and SLA compliance or breaches.
      For a client briefing you may need Client360 more than once.
    sample_questions:
      - question: "Brief me on the client with the most failed payment value"
      - question: "Which relationship managers have the most open critical alerts?"
      - question: "Which payment schemes breached SLA most often in the last 30 days?"
      - question: "Show weekly payment volume for CHAPS as a chart"

  tools:
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: Client360
        description: >
          Corporate client 360: one row per client with sector, country, KYC status and RM;
          payment totals, success rate and failed value per client; AI-scored feedback
          sentiment and topic; and operational alerts with severity, status and resolution time.
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: PaymentsOps
        description: >
          Daily payment KPIs by scheme (CHAPS, Faster Payments, BACS, SWIFT, SEPA, Wire),
          region, channel, sector and RM, plus daily SLA compliance status per scheme.
    - tool_spec:
        type: data_to_chart
        name: data_to_chart
        description: Generates charts from query results

  tool_resources:
    Client360:
      semantic_view: BARCLAYS_HOL.ANALYTICS.SV_CLIENT_360
      execution_environment:
        type: warehouse
        warehouse: BARCLAYS_WH
    PaymentsOps:
      semantic_view: BARCLAYS_HOL.ANALYTICS.SV_PAYMENTS
      execution_environment:
        type: warehouse
        warehouse: BARCLAYS_WH
  $$;

-- -----------------------------------------------------
-- OPS1.2 Use it - Snowflake Intelligence (ai.snowflake.com) or CoWork
-- Select "Corporate Payments 360" and try:
--   1. "Brief me on the client with the most failed payment value"
--   2. "Which of Priya Sharma's clients have open critical alerts?"
--   3. "Is SWIFT meeting its SLA this month? Show a chart."
--   4. "Which clients have negative sentiment AND a success rate below 96%?"
-- Expand "Show details" on each answer to see the tool and SQL used.
-- -----------------------------------------------------

-- OPS1.3 The same agent from SQL (e.g. embedding in a process or app)
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'SNOWFLAKE_INTELLIGENCE.AGENTS.CORPORATE_PAYMENTS_360',
  $${"messages":[{"role":"user","content":[{"type":"text","text":"Which relationship managers have the most open critical alerts?"}]}]}$$
) AS RESPONSE;

-- Barclayflake note: agents inherit the caller's role - an RM only ever
-- sees what their role is granted (see GOV1 for masking and row access).

SELECT 'OPS1 complete' AS STATUS;
