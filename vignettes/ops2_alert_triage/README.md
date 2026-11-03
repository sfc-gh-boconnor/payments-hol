# OPS2: Alert triage with AI next actions

| | |
|---|---|
| **Persona** | Payments Ops analyst / team lead |
| **Time** | ~30 min |
| **Prerequisites** | `setup/catchup/core_analytics.sql` |
| **Reference SQL** | [`ops2.sql`](ops2.sql) |

## Business question
> Which open alerts should my team work first, what should we do, and which unhappy clients are linked to them?

## What you'll build
- `DT_NEGATIVE_SENTIMENT_FEED`
- `V_ALERT_TRIAGE_QUEUE` with an explainable priority score
- `ALERT_RECOMMENDATIONS` (AI next actions for the top 10)

## Steps
### Set your context
Where: payments-hol Workspace > **+ > SQL file**
```sql
USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.ANALYTICS;
```

### Feed negative sentiment to the escalation queue
Where: the Cortex Code sidebar
```prompt
Create a dynamic table BARCLAYS_HOL.ANALYTICS.DT_NEGATIVE_SENTIMENT_FEED with TARGET_LAG = '5 minutes' on BARCLAYS_WH, selecting the NEGATIVE rows of FEEDBACK_ENRICHED with feedback id, date, customer id, name, sector, RM name, payment id, payment type, feedback text, sentiment score and topic.
```
Expect: a dynamic table of negative feedback that stays fresh on its own

### Build the prioritised triage queue
```prompt
Create a view BARCLAYS_HOL.ANALYTICS.V_ALERT_TRIAGE_QUEUE of open alerts (STATUS <> 'RESOLVED') from BARCLAYS_HOL.RAW_DATA.OPERATIONAL_ALERTS, joined to STG_PAYMENTS, RAW_DATA.ERROR_CODES, STG_ACCOUNTS (on ORIGINATOR_ACCOUNT_ID), STG_CUSTOMERS and DT_NEGATIVE_SENTIMENT_FEED. Include alert, payment, error and client columns (ALERT_ID, SEVERITY, PAYMENT_TYPE, ALERT_DESCRIPTION, AMOUNT, CURRENCY, ERROR_DESCRIPTION, ERROR_CATEGORY, IS_RETRYABLE, CUSTOMER_NAME, RM_NAME), CLIENT_NEGATIVE_FEEDBACK (count) and an explainable PRIORITY_SCORE: severity CRITICAL 40 / HIGH 25 / MEDIUM 10, plus 30 for amounts of 1m or more or 15 for 100k or more, plus negative feedback count capped at 20, plus 10 for COMPLIANCE errors. Show the top 10.
```
Expect: the queue ordered by `PRIORITY_SCORE`, with critical, high-value alerts for unhappy clients at the top
Check: ops2_queue

### Generate AI next actions
```prompt
Create a table BARCLAYS_HOL.ANALYTICS.ALERT_RECOMMENDATIONS for the top 10 alerts in V_ALERT_TRIAGE_QUEUE by PRIORITY_SCORE, keeping ALERT_ID, SEVERITY, PAYMENT_TYPE, CUSTOMER_NAME, RM_NAME and PRIORITY_SCORE, with a RECOMMENDED_ACTION column from AI_COMPLETE (claude-sonnet-4-5) acting as a senior payments operations analyst at a UK bank: at most 3 short bullets covering whether to retry the payment and whether to contact the client or their RM, based on the alert, scheme, error, retryability, amount and negative feedback count.
```
Expect: 10 recommendations. A critical compliance-hold alert should say not to retry and to escalate.
Check: ops2_recommendations

### Optional: hand it to the business as an app
Where: payments-hol Workspace > **+ > Streamlit App**, then the Cortex Code sidebar
```prompt
Build a Streamlit app called Alert Triage that shows V_ALERT_TRIAGE_QUEUE ordered by PRIORITY_SCORE, with the matching ALERT_RECOMMENDATIONS alongside each alert and a filter by severity.
```
Expect: a triage app your team lead could use on the ops floor

## Check your work
The top recommendation for a critical compliance-hold alert says not to retry and to escalate.

## Barclayflake note
Recommendations are decision support for an analyst, not automated actions.
