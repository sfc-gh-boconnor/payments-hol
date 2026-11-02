# DE2: Dynamic Tables + data quality

| | |
|---|---|
| **Persona** | Data Engineer |
| **Time** | ~45 min |
| **Prerequisites** | `setup/catchup/core_analytics.sql` (or DE1 + DA2) |
| **Script** | [`de2.sql`](de2.sql) |

## Business question
> Keep an ops-floor SLA monitor fresh without orchestration code, and prove the data feeding it is trustworthy.

## What you'll build
- `DT_LIVE_SLA_BREACHES` (1-minute lag)
- `DT_FAILED_PAYMENT_TRIAGE` reading Iceberg directly, chained to `DT_RETRYABLE_SUMMARY`
- System and custom data metric functions with an expectation on `MART_CUSTOMER_PAYMENTS`

## Steps
1. Create the three dynamic tables and inspect the pipeline graph in **Monitoring > Dynamic Tables**.
2. Attach `NULL_COUNT` and `DUPLICATE_COUNT` DMFs and a custom `INVALID_SUCCESS_RATE_COUNT` DMF.
3. Add an expectation and run the checks on demand.

## Cortex Code prompts
- *"Add a dynamic table DT_HIGH_VALUE_FAILURES ... refreshing every 2 minutes."*
- *"Add a data metric function to MART_PAYMENT_KPIS that counts rows where P95 < average, and attach it."*

## Check your work
`SELECT * FROM DT_RETRYABLE_SUMMARY` returns rows; the on-demand DMF query returns `0, 0, 0`.

## Barclayflake note
Real-time payments streaming is out of scope at Barclays today; dynamic tables give near-real-time freshness over data the platform already lands.
