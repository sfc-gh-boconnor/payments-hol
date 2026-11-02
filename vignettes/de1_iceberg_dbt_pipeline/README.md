# DE1: Iceberg + dbt pipeline with Cortex Code

| | |
|---|---|
| **Persona** | Data Engineer |
| **Time** | ~60 min |
| **Prerequisites** | Core C1 only |
| **Script** | [`de1.sql`](de1.sql) |

## Business question
> Turn the published Iceberg sources into governed, tested data products - and publish them back to the lake as Iceberg.

## What you'll build
- dbt Project on Snowflake `BARCLAYS_DBT` (4 staging views, 2 marts, 27 tests)
- Two CoCo-built marts: `mart_customer_payments`, `mart_rm_performance`
- Nightly task `TSK_DBT_NIGHTLY_BUILD` (suspended)
- Iceberg data product `DP_SLA_COMPLIANCE`

## Steps
1. Open a Workspace from this Git repo and walk `dbt/` - sources point at `RAW_DATA` Iceberg tables with no code changes.
2. Deploy `dbt/` as a dbt Project and run `build` (Workspace **Deploy/Run**, or `EXECUTE DBT PROJECT`).
3. Use the two Cortex Code prompts to generate the missing marts; re-run `build` until the pre-written tests pass.
4. Schedule the project with a task.
5. Publish `MART_SLA_COMPLIANCE` back out as an Iceberg table.

## Cortex Code prompts
- *"Create a dbt mart model mart_customer_payments ... (full prompt in de1.sql)"*
- *"Create mart_rm_performance ... then run dbt build and fix any failing tests."*

## Check your work
`EXECUTE DBT PROJECT` reports `PASS=27 ERROR=0` (more once the CoCo marts exist); `SHOW ICEBERG TABLES IN SCHEMA ANALYTICS` lists `DP_SLA_COMPLIANCE`.

## Barclayflake note
Production Iceberg tables use the bank's external volume (one volume, one IAM role across accounts) rather than Snowflake-managed storage. dbt models and SQL are otherwise identical.
