# DA1: Build a semantic view + ask Cortex Analyst

| | |
|---|---|
| **Persona** | Data Analyst |
| **Time** | ~60 min |
| **Prerequisites** | `setup/catchup/core_analytics.sql` |
| **Script** | [`da1.sql`](da1.sql) |

## Business question
> Give RMs and ops a single, trusted definition of a corporate client's payments health that anyone can query in plain English.

## What you'll build
- Contract views `V_CLIENT_PAYMENT_SUMMARY`, `V_CLIENT_ALERTS`
- Semantic view `SV_CLIENT_360` (4 tables, 3 relationships, 9 metrics, 2 verified queries)

## Steps
1. Compare with the worked example `SV_PAYMENTS` in `setup/catchup/semantic_view_and_agent.sql`.
2. Create the contract views, then the semantic view (DDL, Snowsight UI, or CoCo).
3. Query it with `SEMANTIC_VIEW(...)` SQL.
4. Ask questions in Cortex Analyst and read the generated SQL.

## Cortex Code prompts
- *"Create a semantic view over STG_CUSTOMERS, V_CLIENT_PAYMENT_SUMMARY, FEEDBACK_ENRICHED and V_CLIENT_ALERTS joined on CUSTOMER_ID."*
- *"Add a verified query to SV_CLIENT_360 for 'clients with negative sentiment and success rate below 96%'."*

## Check your work
The `SEMANTIC_VIEW` query returns one row per RM with volume, success rate and open alerts.

## Barclayflake note
Semantic views, Analyst and agents are approved for rollout at Barclays this quarter.
