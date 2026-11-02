# OPS1: Corporate Payments 360 agent

| | |
|---|---|
| **Persona** | Payments Ops analyst |
| **Time** | ~45 min |
| **Prerequisites** | `core_analytics.sql`, DA1 (`SV_CLIENT_360`), `semantic_view_and_agent.sql` (`SV_PAYMENTS`) |
| **Script** | [`ops1.sql`](ops1.sql) |

## Business question
> Before I call a client, tell me everything: payments health, open incidents and what they have been complaining about.

## What you'll build
- Agent `SNOWFLAKE_INTELLIGENCE.AGENTS.CORPORATE_PAYMENTS_360` with two Analyst tools and charting

## Steps
1. Create the agent (SQL or Snowsight **AI & ML > Agents**).
2. Open Snowflake Intelligence / CoWork and run the four sample questions.
3. Expand **Show details** to see which tool and SQL were used.

## Cortex Code prompts
- *"Add a sample question to CORPORATE_PAYMENTS_360 for weekly CHAPS volume and update its orchestration instructions."*

## Check your work
"Brief me on the client with the most failed payment value" returns a briefing naming the client, failed value, open/critical alerts and feedback topic.

## Barclayflake note
Agents run with the caller's role, so RM-level entitlements (GOV1) apply automatically.
