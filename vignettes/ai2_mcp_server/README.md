# AI2: Snowflake-managed MCP server

| | |
|---|---|
| **Persona** | AI Builder |
| **Time** | ~30 min |
| **Prerequisites** | DA1, OPS1, AI1 and the knowledge extension from facilitator setup |
| **Script** | [`ai2.sql`](ai2.sql) |

## Business question
> Teams use different AI clients. Expose governed payments tools to all of them once.

## What you'll build
- MCP server `BARCLAYS_HOL.AGENTS.PAYMENTS_MCP` with Analyst, Agent, UDF and knowledge-extension tools

## Steps
1. Create the MCP server.
2. Get the endpoint URL and create a short-lived PAT for `HOL_PARTICIPANT`.
3. Connect Cortex Code (or another MCP client) and call the tools.

## Cortex Code prompts
- *"Using the barclays-payments tools, which clients have open critical alerts?"*

## Check your work
Your MCP client lists `client-360-analyst`, `payments-360-agent`, `payment-lookup` and `snowflake-docs`.

## Barclayflake note
MCP is approved this quarter. Control reach with `GRANT USAGE ON MCP SERVER`; every call runs as the caller's role.
