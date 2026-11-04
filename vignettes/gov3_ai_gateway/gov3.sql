-- =====================================================
-- GOV3: AI governance with Cortex AI Gateway - reference SQL
-- The calls themselves are Python (gov3_gateway_calls.py); this is the SQL around them.
-- =====================================================
USE ROLE HOL_PARTICIPANT;
USE WAREHOUSE BARCLAYS_WH;

-- 1. The gateway Snowflake created for this account, and its specification
SHOW AI GATEWAYS;
DESCRIBE AI GATEWAY SNOWFLAKE;

-- 2. Your key pair (registered from the notebook with ALTER USER ADD KEY PAIR)
SHOW USER KEY PAIRS;

-- 3. What the gateway recorded for you in the last hour: one row per trace
WITH spans AS (
    SELECT trace:"trace_id"::STRING                                         AS TRACE_ID,
           resource_attributes:"user"::STRING                               AS USER_NAME,
           record_attributes:"gen_ai.request.model"::STRING                 AS MODEL,
           record_attributes:"gen_ai.conversation.id"::STRING               AS CONVERSATION_ID,
           TRY_TO_NUMBER(record_attributes:"gen_ai.usage.input_tokens"::STRING)  AS INPUT_TOKENS,
           TRY_TO_NUMBER(record_attributes:"gen_ai.usage.output_tokens"::STRING) AS OUTPUT_TOKENS,
           TRY_TO_NUMBER(record_attributes:"http.status_code"::STRING)      AS HTTP_STATUS,
           start_timestamp, timestamp
    FROM TABLE(AGENT_TRACE_TABLE('SNOWFLAKE'))
    WHERE timestamp >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
)
SELECT TRACE_ID, MIN(start_timestamp) AS STARTED_AT, MAX(USER_NAME) AS USER_NAME, MAX(MODEL) AS MODEL,
       MAX(CONVERSATION_ID) AS CONVERSATION_ID, SUM(INPUT_TOKENS) AS INPUT_TOKENS, SUM(OUTPUT_TOKENS) AS OUTPUT_TOKENS,
       DATEDIFF('millisecond', MIN(start_timestamp), MAX(timestamp)) AS DURATION_MS,
       IFF(COUNT_IF(HTTP_STATUS >= 400) = 0, 'SUCCESS', 'FAILURE') AS STATUS
FROM spans
GROUP BY TRACE_ID
ORDER BY STARTED_AT DESC;

-- 4. Draft only: a tighter specification. Needs ACCOUNTADMIN, and FROM SPECIFICATION
--    replaces the whole specification, so start from what DESCRIBE returns.
-- CREATE TAG IF NOT EXISTS BARCLAYS_HOL.GOVERNANCE.PAYLOAD_CAPTURE_EXEMPT;
-- ALTER AI GATEWAY SNOWFLAKE FROM SPECIFICATION $$
-- schema_version: 1
-- models:
--   - name: claude-sonnet-4-5
--   - name: claude-haiku-4-5
--   - name: openai-gpt-5
-- logging:
--   enabled: true
--   capture_payload:
--     request_response: true
--     exclude_tags:
--       - BARCLAYS_HOL.GOVERNANCE.PAYLOAD_CAPTURE_EXEMPT
-- $$;

-- 5. Usage per user and model in the last day (your own rows unless you have MONITOR)
SELECT resource_attributes:"user"::STRING                                       AS USER_NAME,
       record_attributes:"gen_ai.request.model"::STRING                         AS MODEL,
       COUNT(*)                                                                 AS REQUESTS,
       SUM(TRY_TO_NUMBER(record_attributes:"gen_ai.usage.input_tokens"::STRING))  AS INPUT_TOKENS,
       SUM(TRY_TO_NUMBER(record_attributes:"gen_ai.usage.output_tokens"::STRING)) AS OUTPUT_TOKENS,
       COUNT_IF(TRY_TO_NUMBER(record_attributes:"http.status_code"::STRING) >= 400) AS FAILURES
FROM TABLE(AGENT_TRACE_TABLE('SNOWFLAKE'))
WHERE timestamp >= DATEADD('day', -1, CURRENT_TIMESTAMP())
  AND record_attributes:"gen_ai.operation.name"::STRING = 'chat'
GROUP BY 1, 2
ORDER BY REQUESTS DESC;

-- Authoritative credits (lags; needs Account Usage access):
-- SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.AI_GATEWAY_USAGE_HISTORY ORDER BY START_TIME DESC LIMIT 50;

-- 6. Clean up
-- ALTER USER REMOVE KEY PAIR GOV3_GATEWAY_KEY;
