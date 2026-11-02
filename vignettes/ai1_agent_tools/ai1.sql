-- =====================================================
-- VIGNETTE AI1: AGENT WITH CUSTOM TOOLS   (~45 min)
-- Persona: AI Builder
-- Question: "Ops staff ask about specific payments by ID and about scheme
--            rules - not just aggregates. Give the agent precise tools."
-- Prereq:   setup/catchup/core_analytics.sql + setup/catchup/semantic_view_and_agent.sql
-- Builds:   2 UDF tools + PAYMENTS_INVESTIGATOR agent
-- =====================================================

USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;   -- see exactly what an attendee sees
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.AGENTS;

-- -----------------------------------------------------
-- AI1.1 Tool 1: exact payment lookup (deterministic - no text-to-SQL guessing)
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION GET_PAYMENT_DETAILS(PAYMENT_ID_IN VARCHAR)
RETURNS TABLE (PAYMENT_ID VARCHAR, PAYMENT_DATE TIMESTAMP, PAYMENT_TYPE VARCHAR,
               AMOUNT NUMBER(15,2), CURRENCY VARCHAR, STATUS VARCHAR,
               PROCESSING_TIME_MS NUMBER, ERROR_CODE VARCHAR, ERROR_DESCRIPTION VARCHAR,
               IS_RETRYABLE BOOLEAN, CUSTOMER_NAME VARCHAR, RM_NAME VARCHAR,
               OPEN_ALERTS NUMBER)
COMMENT = 'Look up one payment by PAYMENT_ID with its error, client, RM and open alert count'
AS
$$
    SELECT p.PAYMENT_ID, p.PAYMENT_DATE, p.PAYMENT_TYPE, p.AMOUNT, p.CURRENCY, p.STATUS,
           p.PROCESSING_TIME_MS, p.ERROR_CODE, e.ERROR_DESCRIPTION, e.IS_RETRYABLE,
           c.CUSTOMER_NAME, c.RM_NAME,
           (SELECT COUNT(*) FROM BARCLAYS_HOL.RAW_DATA.OPERATIONAL_ALERTS al
             WHERE al.PAYMENT_ID = p.PAYMENT_ID AND al.STATUS <> 'RESOLVED')
    FROM BARCLAYS_HOL.ANALYTICS.STG_PAYMENTS p
    LEFT JOIN BARCLAYS_HOL.RAW_DATA.ERROR_CODES e  ON p.ERROR_CODE = e.ERROR_CODE
    LEFT JOIN BARCLAYS_HOL.ANALYTICS.STG_ACCOUNTS a ON p.ORIGINATOR_ACCOUNT_ID = a.ACCOUNT_ID
    LEFT JOIN BARCLAYS_HOL.ANALYTICS.STG_CUSTOMERS c ON a.CUSTOMER_ID = c.CUSTOMER_ID
    WHERE p.PAYMENT_ID = UPPER(TRIM(PAYMENT_ID_IN))
$$;

-- Agent custom tools need a scalar return - wrap the table function as JSON
CREATE OR REPLACE FUNCTION PAYMENT_LOOKUP(PAYMENT_ID VARCHAR)
RETURNS VARIANT
COMMENT = 'Agent tool: payment details as JSON'
AS
$$
    SELECT COALESCE(ARRAY_AGG(OBJECT_CONSTRUCT(*))[0],
                    OBJECT_CONSTRUCT('error', 'No payment found with ID ' || PAYMENT_ID))
    FROM TABLE(GET_PAYMENT_DETAILS(PAYMENT_ID))
$$;

SELECT PAYMENT_LOOKUP((SELECT MIN(PAYMENT_ID) FROM BARCLAYS_HOL.RAW_DATA.PAYMENTS WHERE STATUS = 'FAILED')) AS RESULT;

-- -----------------------------------------------------
-- AI1.2 Tool 2: scheme rules ("can I still send this today?")
-- -----------------------------------------------------
CREATE OR REPLACE FUNCTION SCHEME_RULES(SCHEME VARCHAR)
RETURNS VARIANT
COMMENT = 'Agent tool: payment scheme rules - settlement cycle, value limit, cutoff and SLA'
AS
$$
    SELECT COALESCE(ARRAY_AGG(OBJECT_CONSTRUCT(
               'scheme', s.SCHEME_CODE, 'name', s.SCHEME_NAME,
               'settlement_cycle', s.SETTLEMENT_CYCLE, 'domestic', s.IS_DOMESTIC,
               'max_value_gbp', s.MAX_VALUE_GBP, 'cutoff_time_uk', s.CUTOFF_TIME::STRING,
               'currency', s.OPERATING_CURRENCY,
               'sla_target_success_rate', sla.TARGET_SUCCESS_RATE,
               'sla_max_p95_ms', sla.MAX_PROCESSING_TIME_MS))[0],
             OBJECT_CONSTRUCT('error', 'Unknown scheme. Valid: CHAPS, FASTER_PAYMENTS, BACS, SWIFT, SEPA, WIRE_TRANSFER'))
    FROM BARCLAYS_HOL.RAW_DATA.PAYMENT_SCHEMES s
    LEFT JOIN BARCLAYS_HOL.RAW_DATA.SLA_DEFINITIONS sla ON sla.PAYMENT_TYPE = s.SCHEME_CODE
    WHERE s.SCHEME_CODE = UPPER(REPLACE(TRIM(SCHEME), ' ', '_'))
$$;

SELECT SCHEME_RULES('chaps') AS RESULT;

-- -----------------------------------------------------
-- AI1.3 The agent: Analyst for aggregates + custom tools for precision
-- -----------------------------------------------------
CREATE OR REPLACE AGENT BARCLAYS_HOL.AGENTS.PAYMENTS_INVESTIGATOR
  COMMENT = 'Barclays HOL - investigates individual payments and scheme rules, plus KPI questions'
  PROFILE = '{"display_name": "Payments Investigator", "color": "green"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  instructions:
    response: >
      You help payments operations investigate individual payments. Be precise and brief.
      When reporting a payment, state status, error and whether it is retryable first.
    orchestration: >
      If the user gives a payment ID (format PAY followed by digits), call PaymentLookup.
      For questions about a scheme's cutoff, limit, settlement cycle or SLA, call SchemeRules.
      For counts, volumes, trends or comparisons, use PaymentsOps.
      You can chain tools, e.g. look up a payment then check its scheme's cutoff.
  tools:
    - tool_spec:
        type: generic
        name: PaymentLookup
        description: Returns full details for a single payment ID, including error, retryability, client, RM and open alerts.
        input_schema:
          type: object
          properties:
            payment_id:
              type: string
              description: The payment ID, e.g. PAY0000000123
          required: [payment_id]
    - tool_spec:
        type: generic
        name: SchemeRules
        description: Returns rules for a payment scheme - settlement cycle, max value, daily cutoff time and SLA targets.
        input_schema:
          type: object
          properties:
            scheme:
              type: string
              description: One of CHAPS, FASTER_PAYMENTS, BACS, SWIFT, SEPA, WIRE_TRANSFER
          required: [scheme]
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: PaymentsOps
        description: Aggregated daily payment KPIs and SLA compliance by scheme, region, channel, sector and RM.
  tool_resources:
    PaymentLookup:
      type: function
      identifier: BARCLAYS_HOL.AGENTS.PAYMENT_LOOKUP
      execution_environment:
        type: warehouse
        warehouse: BARCLAYS_WH
    SchemeRules:
      type: function
      identifier: BARCLAYS_HOL.AGENTS.SCHEME_RULES
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
-- AI1.4 Test (Snowsight: AI & ML > Agents > PAYMENTS_INVESTIGATOR > Playground)
-- Grab a failed payment ID to ask about:
SELECT PAYMENT_ID, PAYMENT_TYPE, AMOUNT FROM BARCLAYS_HOL.RAW_DATA.PAYMENTS WHERE STATUS = 'FAILED' LIMIT 3;
-- Try:
--   "What happened to payment <ID>? Can we retry it, and is there still time before the scheme cutoff today?"
--   "What's the maximum value for Faster Payments, and how many failed last week?"
-- CoCo prompt: "Add a third tool to PAYMENTS_INVESTIGATOR that lists the open alerts
--   for a given customer name, using a new UDF in BARCLAYS_HOL.AGENTS."
-- -----------------------------------------------------

SELECT 'AI1 complete' AS STATUS;
