# AI2: Snowflake-managed MCP server

| | |
|---|---|
| **Persona** | AI Builder |
| **Time** | ~30 min |
| **Prerequisites** | DA1, OPS1, AI1 and the knowledge extension from facilitator setup |
| **Reference SQL** | [`ai2.sql`](ai2.sql) |

## Business question
> Teams use different AI clients. Expose governed payments tools to all of them once.

## What you'll build
- MCP server `BARCLAYS_HOL.AGENTS.PAYMENTS_MCP` with Analyst, Agent, UDF and knowledge-extension tools

## Steps
### Create the MCP server
Where: the Cortex Code sidebar
One server, four governed tools, nothing to host. Every call runs as the caller's role.
```prompt
Create a Snowflake-managed MCP server BARCLAYS_HOL.AGENTS.PAYMENTS_MCP with four tools: "client-360-analyst" (CORTEX_ANALYST_MESSAGE on BARCLAYS_HOL.ANALYTICS.SV_CLIENT_360), "payments-360-agent" (CORTEX_AGENT_RUN on SNOWFLAKE_INTELLIGENCE.AGENTS.CORPORATE_PAYMENTS_360, read-only), "payment-lookup" (GENERIC function tool on BARCLAYS_HOL.AGENTS.PAYMENT_LOOKUP, warehouse BARCLAYS_WH, input payment_id string, read-only and idempotent) and "snowflake-docs" (CORTEX_SEARCH_SERVICE_QUERY on SNOWFLAKE_DOCS_CKE.SHARED.CKE_SNOWFLAKE_DOCS_SERVICE). Then describe it.
```
Expect: `PAYMENTS_MCP` listed by `SHOW MCP SERVERS IN SCHEMA BARCLAYS_HOL.AGENTS` with four tools
Check: ai2_mcp

### Get the endpoint
```prompt
Give me the MCP endpoint URL for BARCLAYS_HOL.AGENTS.PAYMENTS_MCP in this account (https://<account_url>/api/v2/databases/BARCLAYS_HOL/schemas/AGENTS/mcp-servers/PAYMENTS_MCP), and the MCP client JSON config for a server called barclays-payments using a bearer token.
```
Expect: your account's endpoint URL and a ready-to-paste config

### Connect a client and call the tools
Create a short-lived programmatic access token restricted to `HOL_PARTICIPANT` (Snowsight: **Settings > Authentication > Programmatic access tokens**). Add the config to an MCP client such as Cortex Code Desktop or CLI, then ask it:
```prompt
Using the barclays-payments tools, which clients have open critical alerts?
```
Expect: your client lists `client-360-analyst`, `payments-360-agent`, `payment-lookup` and `snowflake-docs`, and answers using them

## Check your work
Your MCP client lists `client-360-analyst`, `payments-360-agent`, `payment-lookup` and `snowflake-docs`.

## Barclayflake note
MCP is approved this quarter. Control reach with `GRANT USAGE ON MCP SERVER`; every call runs as the caller's role.
