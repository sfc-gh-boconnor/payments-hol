-- =====================================================
-- VIGNETTE AI2: SNOWFLAKE-MANAGED MCP SERVER   (~30 min)
-- Persona: AI Builder
-- Question: "Our teams use different AI clients (Cortex Code, Claude, Copilot,
--            in-house apps). Expose governed payments tools to all of them once."
-- Prereq:   DA1 (SV_CLIENT_360), OPS1 (CORPORATE_PAYMENTS_360), AI1 (PAYMENT_LOOKUP)
--           and the Marketplace knowledge extension installed by facilitator setup.
-- =====================================================

USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;   -- see exactly what an attendee sees
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.AGENTS;

-- -----------------------------------------------------
-- AI2.1 One server, four governed tools. No infrastructure to host.
-- Every call runs as the calling user's role - RBAC, masking and row
-- access policies all still apply.
-- -----------------------------------------------------
CREATE OR REPLACE MCP SERVER PAYMENTS_MCP
  FROM SPECIFICATION $$
    tools:
      - name: "client-360-analyst"
        type: "CORTEX_ANALYST_MESSAGE"
        identifier: "BARCLAYS_HOL.ANALYTICS.SV_CLIENT_360"
        title: "Corporate Client 360"
        description: "Ask natural-language questions about corporate clients: payment volumes, success rates, failed value, alerts and feedback sentiment."

      - name: "payments-360-agent"
        type: "CORTEX_AGENT_RUN"
        identifier: "SNOWFLAKE_INTELLIGENCE.AGENTS.CORPORATE_PAYMENTS_360"
        title: "Corporate Payments 360 Agent"
        description: "Full client briefings combining client 360 and scheme-level payments operations data."
        annotations:
          readOnlyHint: true
          openWorldHint: false

      - name: "payment-lookup"
        type: "GENERIC"
        identifier: "BARCLAYS_HOL.AGENTS.PAYMENT_LOOKUP"
        title: "Payment Lookup"
        description: "Returns full details for one payment ID: status, error, retryability, client, RM and open alerts."
        annotations:
          readOnlyHint: true
          destructiveHint: false
          idempotentHint: true
          openWorldHint: false
        config:
          type: "function"
          warehouse: "BARCLAYS_WH"
          input_schema:
            type: "object"
            properties:
              payment_id:
                description: "Payment ID, e.g. PAY0000000123"
                type: "string"

      - name: "snowflake-docs"
        type: "CORTEX_SEARCH_SERVICE_QUERY"
        identifier: "SNOWFLAKE_DOCS_CKE.SHARED.CKE_SNOWFLAKE_DOCS_SERVICE"
        title: "Snowflake Documentation (Knowledge Extension)"
        description: "Search official Snowflake documentation. Provider-hosted Marketplace Knowledge Extension - no internal data is indexed."
  $$;

SHOW MCP SERVERS IN SCHEMA BARCLAYS_HOL.AGENTS;
DESCRIBE MCP SERVER PAYMENTS_MCP;

-- -----------------------------------------------------
-- AI2.2 Connect a client
-- Endpoint:
--   https://<account_url>/api/v2/databases/BARCLAYS_HOL/schemas/AGENTS/mcp-servers/PAYMENTS_MCP
-- Find <account_url>:
SELECT REPLACE(LOWER(CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME()), '_', '-') || '.snowflakecomputing.com' AS ACCOUNT_URL;
--
-- Cortex Code (CLI / Desktop) - add to your MCP settings:
--   {
--     "mcpServers": {
--       "barclays-payments": {
--         "type": "http",
--         "url": "https://<account_url>/api/v2/databases/BARCLAYS_HOL/schemas/AGENTS/mcp-servers/PAYMENTS_MCP",
--         "headers": { "Authorization": "Bearer <PAT>" }
--       }
--     }
--   }
-- Create a short-lived PAT restricted to HOL_PARTICIPANT (Snowsight: Settings >
-- Authentication > Programmatic access tokens) or use OAuth for production.
--
-- Then ask your client:
--   "Using the barclays-payments tools, which clients have open critical alerts?"
--   "Look up payment <ID> and tell me if it can be retried."
--   "How do I create a dynamic table? Check the Snowflake docs tool."
-- -----------------------------------------------------

-- Barclayflake note: the MCP server is a schema object - grant USAGE on it
-- only to roles that should reach these tools:
--   GRANT USAGE ON MCP SERVER BARCLAYS_HOL.AGENTS.PAYMENTS_MCP TO ROLE <consumer_role>;

SELECT 'AI2 complete' AS STATUS;
