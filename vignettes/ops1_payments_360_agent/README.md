# OPS1: Corporate Payments 360 agent

| | |
|---|---|
| **Persona** | Payments Ops analyst |
| **Time** | ~45 min |
| **Prerequisites** | `core_analytics.sql`, DA1 (`SV_CLIENT_360`), `semantic_view_and_agent.sql` (`SV_PAYMENTS`) |
| **Reference SQL** | [`ops1.sql`](ops1.sql) |

## Business question
> Before I call a client, tell me everything: payments health, open incidents and what they have been complaining about.

## What you'll build
- Agent `SNOWFLAKE_INTELLIGENCE.AGENTS.CORPORATE_PAYMENTS_360` with two Analyst tools and charting

## Steps
### Create the agent with Cortex Code
Where: payments-hol Workspace > **+ > Agent** > **Create with CoCo** (recommended)
Name the new agent file `corporate_payments_360` straight away (it opens as "Untitled"). Cortex Code then guides you through the configuration; paste this as your brief.
```prompt
Create a Cortex Agent SNOWFLAKE_INTELLIGENCE.AGENTS.CORPORATE_PAYMENTS_360 with display name "Corporate Payments 360". It supports Payments Operations and Relationship Managers in a UK corporate bank. Tools: a Cortex Analyst tool Client360 on semantic view BARCLAYS_HOL.ANALYTICS.SV_CLIENT_360 (client health, alerts, sentiment), a Cortex Analyst tool PaymentsOps on BARCLAYS_HOL.ANALYTICS.SV_PAYMENTS (scheme volumes and SLAs), both on warehouse BARCLAYS_WH, plus charting. Response instructions: lead with a one-line summary, format money in GBP with thousands separators and percentages to 1 dp, and when briefing on a client always cover payment volume and success rate, failed value, open and critical alerts, and feedback sentiment with the main topic. Sample questions: "Brief me on the client with the most failed payment value", "Which relationship managers have the most open critical alerts?", "Which payment schemes breached SLA most often in the last 30 days?", "Show weekly payment volume for CHAPS as a chart". Deploy it.
```
Expect: the agent deployed as `CORPORATE_PAYMENTS_360` in `SNOWFLAKE_INTELLIGENCE.AGENTS`
Check: ops1_agent

### Ask it in Snowflake CoWork
Where: Snowsight > **AI & ML > CoWork** (formerly Snowflake Intelligence) > **Corporate Payments 360**
Run the four sample questions. Start with "Brief me on the client with the most failed payment value".
Expect: a briefing naming the client, failed value, open and critical alerts, and the main feedback topic. The CHAPS question returns a chart.

### See how it answered
Expand **Show details** on an answer to see which tool it chose and the SQL that ran.
Expect: client questions go to `Client360`, scheme questions to `PaymentsOps`

### Improve it
Where: the Cortex Code sidebar, with `corporate_payments_360` open
```prompt
Add a sample question to CORPORATE_PAYMENTS_360 for weekly CHAPS volume and update its orchestration instructions so scheme and SLA questions always use the PaymentsOps tool. Redeploy it.
```
Expect: the new sample question appears in CoWork

## Check your work
"Brief me on the client with the most failed payment value" returns a briefing naming the client, failed value, open/critical alerts and feedback topic.

## Barclayflake note
Agents run with the caller's role, so RM-level entitlements (GOV1) apply automatically.
