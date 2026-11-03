# DA1: Semantic view + Cortex Analyst

| | |
|---|---|
| **Persona** | Data Analyst |
| **Time** | ~60 min |
| **Prerequisites** | `setup/catchup/core_analytics.sql` |
| **Reference SQL** | [`da1.sql`](da1.sql) |

## Business question
> Give RMs and ops a single, trusted definition of a corporate client's payments health that anyone can query in plain English.

## What you'll build
- Contract views `V_CLIENT_PAYMENT_SUMMARY`, `V_CLIENT_ALERTS`
- Semantic view `SV_CLIENT_360` (4 tables, 3 relationships, metrics and verified queries)

## Steps
### Build stable contract views
Where: the Cortex Code sidebar
Semantic views should sit on contracts, not raw tables.
```prompt
In BARCLAYS_HOL.ANALYTICS create two views. V_CLIENT_PAYMENT_SUMMARY: one row per CUSTOMER_ID from STG_PAYMENTS joined to STG_ACCOUNTS (on ORIGINATOR_ACCOUNT_ID), with TOTAL_PAYMENTS, SUCCESSFUL_PAYMENTS, FAILED_PAYMENTS, TOTAL_VOLUME_GBP and FAILED_VOLUME_GBP. V_CLIENT_ALERTS: one row per ALERT_ID from BARCLAYS_HOL.RAW_DATA.OPERATIONAL_ALERTS joined through STG_PAYMENTS and STG_ACCOUNTS to get CUSTOMER_ID, with SEVERITY, ALERT_STATUS, ALERT_TIME and RESOLUTION_TIME_MIN. Show 5 rows from each.
```
Expect: two views, with one row per client in the summary view

### Create the semantic view with Cortex Code
Where: payments-hol Workspace > **+ > Semantic view**, or the Cortex Code sidebar
Compare with the worked example `SV_PAYMENTS` if you want a pattern to follow.
```prompt
Create a semantic view BARCLAYS_HOL.ANALYTICS.SV_CLIENT_360 with four logical tables: clients (STG_CUSTOMERS, key CUSTOMER_ID), payments (V_CLIENT_PAYMENT_SUMMARY, key CUSTOMER_ID), feedback (FEEDBACK_ENRICHED, key FEEDBACK_ID) and alerts (V_CLIENT_ALERTS, key ALERT_ID), with payments, feedback and alerts each related to clients on CUSTOMER_ID. Add dimensions including clients.customer_name, clients.sector and clients.rm_name (synonyms "relationship manager", "RM"), and metrics including payments.payment_volume (sum of total volume GBP), payments.success_rate_pct, feedback.avg_sentiment, alerts.open_alert_count (status not RESOLVED) and alerts.critical_alert_count. Add business comments and synonyms, then deploy it.
```
Expect: `SV_CLIENT_360` exists. Keep the logical names `clients`, `payments`, `rm_name` and `payment_volume`: the check queries them.
Check: da1_semantic_view

### Query it with SQL - no joins to remember
```prompt
Query SV_CLIENT_360 with the SEMANTIC_VIEW function: payment volume, success rate and open alert count by RM name, ordered by open alerts.
```
Expect: one row per RM with volume, success rate and open alerts
Check: da1_semantic_query

### Ask in plain English and add a verified query
Where: Snowsight > **AI & ML > Cortex Analyst** > `SV_CLIENT_360`, then the Cortex Code sidebar
Ask Cortex Analyst "Which clients have negative sentiment and a success rate below 96%?" and read the SQL it generates.
```prompt
Add a verified query to SV_CLIENT_360 for "clients with negative sentiment and success rate below 96%", using the SQL Cortex Analyst generated if it is correct.
```
Expect: the verified query saved, so Analyst and agents answer that question the same way every time

## Check your work
The `SEMANTIC_VIEW` query returns one row per RM with volume, success rate and open alerts.

## Barclayflake note
Semantic views, Analyst and agents are approved for rollout at Barclays this quarter.
