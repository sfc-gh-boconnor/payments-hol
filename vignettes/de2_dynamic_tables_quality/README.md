# DE2: Dynamic Tables + data quality

| | |
|---|---|
| **Persona** | Data Engineer |
| **Time** | ~45 min |
| **Prerequisites** | `setup/catchup/core_analytics.sql` (or DE1 + DA2) |
| **Reference SQL** | [`de2.sql`](de2.sql) |

## Business question
> Keep an ops-floor SLA monitor fresh without orchestration code, and prove the data feeding it is trustworthy.

## What you'll build
- `DT_LIVE_SLA_BREACHES` (1-minute lag)
- `DT_FAILED_PAYMENT_TRIAGE` reading Iceberg directly, chained to `DT_RETRYABLE_SUMMARY`
- System and custom data metric functions with an expectation on `MART_CUSTOMER_PAYMENTS`

## Steps
### Set your context
Where: payments-hol Workspace > **+ > SQL file**
```sql
USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.ANALYTICS;
```

### Build the SLA breach monitor
Where: the Cortex Code sidebar
```prompt
Create a dynamic table BARCLAYS_HOL.ANALYTICS.DT_LIVE_SLA_BREACHES with TARGET_LAG = '1 minute' on warehouse BARCLAYS_WH. From MART_SLA_COMPLIANCE where SLA_STATUS = 'BREACH', group by PAYMENT_TYPE and return total payments, breached (failed) payments, breach rate % and the earliest and latest breach day.
```
Expect: one row per payment scheme with breaches

### Build the failed-payment triage feed straight off Iceberg
```prompt
Create a dynamic table BARCLAYS_HOL.ANALYTICS.DT_FAILED_PAYMENT_TRIAGE with TARGET_LAG = DOWNSTREAM on BARCLAYS_WH. Read directly from the Iceberg tables in BARCLAYS_HOL.RAW_DATA: PAYMENTS with STATUS FAILED or RETURNED, joined to ERROR_CODES, ACCOUNTS (on ORIGINATOR_ACCOUNT_ID), CUSTOMERS and RELATIONSHIP_MANAGERS. Include payment id, date, type, amount, currency, error code, description, category, IS_RETRYABLE, customer name, sector and RM name. Then create DT_RETRYABLE_SUMMARY with TARGET_LAG = '5 minutes' that groups DT_FAILED_PAYMENT_TRIAGE by PAYMENT_TYPE, ERROR_CATEGORY and IS_RETRYABLE with a payment count and VALUE_AT_RISK (sum of amount).
```
Expect: two chained dynamic tables. In Snowsight, **Monitoring > Dynamic Tables > DT_RETRYABLE_SUMMARY > Graph** shows the pipeline from the Iceberg sources.
Check: de2_dynamic_tables

### Watch them refresh
```prompt
Show me the refresh history for the DT_ dynamic tables in BARCLAYS_HOL.ANALYTICS, and how many rows DT_RETRYABLE_SUMMARY has. If it has not refreshed yet, refresh it.
```
Expect: successful refreshes and rows in `DT_RETRYABLE_SUMMARY`
Check: de2_dt_refreshed

### Add data quality checks
```prompt
On BARCLAYS_HOL.ANALYTICS.MART_CUSTOMER_PAYMENTS: set DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES', attach SNOWFLAKE.CORE.NULL_COUNT on RM_NAME and SNOWFLAKE.CORE.DUPLICATE_COUNT on CUSTOMER_ID, create a custom data metric function INVALID_SUCCESS_RATE_COUNT that counts rows where SUCCESS_RATE_PCT (FLOAT) is null, below 0 or above 100, and attach it. Add an expectation NO_DUPLICATE_CUSTOMERS (VALUE = 0) on the duplicate check. Then run all three checks on demand.
```
Expect: three data metric functions attached, and the on-demand checks return `0, 0, 0`
Check: de2_dmfs

### Optional: explore Pipeline Builder
Where: payments-hol Workspace > **+ > Pipeline Builder** (Preview)
Pipeline Builder is a new, visual way to build pipelines in the Workspace. Open it and see how it lays out sources, transformations and targets. Your dynamic tables above stay the source of truth for this module.

## Check your work
`SELECT * FROM DT_RETRYABLE_SUMMARY` returns rows; the on-demand data metric checks return `0, 0, 0`.

## Barclayflake note
Real-time payments streaming is out of scope at Barclays today; dynamic tables give near-real-time freshness over data the platform already lands.
