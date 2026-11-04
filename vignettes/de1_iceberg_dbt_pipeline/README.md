# DE1: Iceberg + dbt pipeline with Cortex Code

| | |
|---|---|
| **Persona** | Data Engineer |
| **Time** | ~60 min |
| **Prerequisites** | Core C1 only |
| **Reference SQL** | [`de1.sql`](de1.sql) |

## Business question
> Turn the published Iceberg sources into governed, tested data products - and publish them back to the lake as Iceberg.

## What you'll build
- The dbt project in the Workspace (4 staging views, 2 marts, pre-written tests), run from the Workspace dbt pane
- Two Cortex Code-built marts: `mart_customer_payments`, `mart_rm_performance`
- Nightly task `TSK_DBT_NIGHTLY_BUILD` (suspended)
- Iceberg data product `DP_SLA_COMPLIANCE`

## Steps
### Open the dbt project in the Workspace
Where: Snowsight > **Projects > Workspaces** > **My Workspace** dropdown > **payments-hol**, then `dbt/` in the file explorer
Open `dbt/models/staging/schema.yml`: the sources point straight at the `RAW_DATA` Iceberg tables. dbt reads Iceberg exactly like native tables.
```prompt
Walk me through the dbt project in the dbt/ folder of this Workspace: what each staging and mart model does, where the sources come from, and which models are defined in models/marts/schema.yml but have no .sql file yet.
```
Expect: 4 staging models and 2 marts (`mart_payment_kpis`, `mart_sla_compliance`). `mart_customer_payments` and `mart_rm_performance` have tests in `schema.yml` but no SQL yet. Those are the two you'll build.

### Run dbt build from the dbt pane
Where: the bottom panel of the Workspace > **dbt** tab (next to Query History)
Open the **dbt** tab in the bottom panel. It shows Profile **dev** and a blue **Run** button. Click the arrow next to Run to open **Select Operation**, choose **Build** (not Run) and press **Execute**. Build runs the models and their tests in dependency order; Run only creates the models and skips the tests that prove Cortex Code's marts are correct.
Expect: the Output tab ends with every model and test passing (`ERROR=0`). Open the **DAG** tab to see the lineage from the Iceberg sources to the marts.
Check: de1_staging

### Generate mart_customer_payments with Cortex Code
Where: the Cortex Code sidebar, with the payments-hol Workspace open
```prompt
Create a dbt mart model dbt/models/marts/mart_customer_payments.sql that summarises payment activity per customer. Join stg_payments -> stg_accounts (on originator_account_id) -> stg_customers and follow the patterns in mart_payment_kpis.sql. Output one row per customer with these columns: customer_id, customer_name, customer_sector, rm_name, total_payments, total_volume_gbp, success_rate_pct (a float percentage, 0-100), avg_processing_time_ms and most_used_scheme. Keep the column names and tests already defined for this model in models/marts/schema.yml.
```
Expect: a new file `dbt/models/marts/mart_customer_payments.sql`. DE2 builds on this mart, so keep these column names.

### Generate mart_rm_performance with Cortex Code
Where: the Cortex Code sidebar
```prompt
Create dbt/models/marts/mart_rm_performance.sql: one row per relationship manager with rm_id, rm_name, client_count, total_volume_gbp, avg_success_rate_pct and the name of their client with the lowest success rate. Build it from mart_customer_payments and stg_customers, and keep the column names and tests in models/marts/schema.yml. Then run dbt build for mart_rm_performance and its upstream models in this Workspace, and fix the model until every test passes.
```
Expect: a new file `dbt/models/marts/mart_rm_performance.sql`, and Cortex Code reporting the tests passing. If it only compiles the model, that's fine: the next step builds everything.

### Build the whole project and check the tests
Where: the bottom panel of the Workspace > **dbt** tab
Writing or compiling a model doesn't create its table: only a build does. Click the arrow next to **Run** to open **Select Operation**, choose **Build** and press **Execute**.
Expect: the Output shows 8 models and every test passing (`ERROR=0`), including the tests for both Cortex Code marts. If a test fails, paste the error into Cortex Code, ask it to fix the model, and Build again.
Check: de1_coco_marts

### Deploy the project
The Workspace is where you develop; the deployed project object `BARCLAYS_HOL.ANALYTICS.BARCLAYS_DBT` is what production runs. It was deployed when the lab was set up, so it doesn't have the marts you just wrote yet.
```prompt
Deploy the dbt project in my payments-hol Workspace (snow://workspace/DEFAULT_DATABASE.PUBLIC."payments-hol"/versions/live/dbt) to the existing dbt project object BARCLAYS_HOL.ANALYTICS.BARCLAYS_DBT with ALTER DBT PROJECT ... ADD VERSION FROM. Then list the models in the deployed project to confirm MART_CUSTOMER_PAYMENTS and MART_RM_PERFORMANCE are included.
```
Expect: "Successfully deployed new files", and both Cortex Code marts listed in the deployed project. The nightly task in the next step now builds what you developed.

### Schedule the project
```prompt
Create a task BARCLAYS_HOL.ANALYTICS.TSK_DBT_NIGHTLY_BUILD on warehouse BARCLAYS_WH that runs EXECUTE DBT PROJECT BARCLAYS_HOL.ANALYTICS.BARCLAYS_DBT ARGS = 'build' every day at 05:00 Europe/London. Leave it suspended.
```
Expect: the task created and suspended, on a 05:00 Europe/London schedule. In production you'd resume it. No external orchestrator needed.
Check: de1_task

### Publish the data product back to the lake as Iceberg
```prompt
Create a Snowflake-managed Iceberg table BARCLAYS_HOL.ANALYTICS.DP_SLA_COMPLIANCE (CATALOG = 'SNOWFLAKE') from MART_SLA_COMPLIANCE, casting PAYMENT_DAY to TIMESTAMP_NTZ(6) because Iceberg stores microseconds. Add a comment describing it as a data product, then show its Iceberg metadata location.
```
Expect: `DP_SLA_COMPLIANCE` listed by `SHOW ICEBERG TABLES IN SCHEMA BARCLAYS_HOL.ANALYTICS`, with a metadata location other engines can read
Check: de1_iceberg_product

## Check your work
`dbt build` in the dbt pane passes with `ERROR=0` once the two Cortex Code marts exist, and `DP_SLA_COMPLIANCE` is an Iceberg table in `ANALYTICS`.

## Barclayflake note
Production Iceberg tables use the bank's external volume (one volume, one IAM role across accounts) rather than Snowflake-managed storage. dbt models and SQL are otherwise identical.
