# C1: Explore the Iceberg data product

| | |
|---|---|
| **Persona** | All personas |
| **Time** | ~25 min |
| **Prerequisites** | Facilitator setup complete |
| **Reference SQL** | [`C1_explore_iceberg.sql`](C1_explore_iceberg.sql) |

## Business question
> What has the platform team published to us, and what can we (not) do with it?

## What you'll build
- Nothing yet: you explore the nine read-only Snowflake-managed Iceberg tables with Cortex Code, and get to know the Workspace you'll build everything else in.

## Steps
### Open the payments-hol Workspace
Where: Snowsight > **Projects > Workspaces**, then the **My Workspace** dropdown (top left) > **payments-hol**
This shared Workspace is where you'll build every module. Take a quick tour: **Home** and the **+** button list everything you can create here (SQL file, Notebook, dbt Project, Streamlit App, Agent, Semantic view, Pipeline Builder). The file explorer on the left holds the lab project (`dbt/`, `vignettes/`). The bottom panel has Query History and, later, the dbt pane.
Stay in **payments-hol** for the whole lab: every module's files, starter notebooks and the dbt project are here, and Cortex Code only finds them when this Workspace is open. Snowsight sometimes reopens **My Workspace**, so check the name top left whenever you come back.
Expect: the payments-hol Workspace open, with `dbt/`, `notebooks/` and `vignettes/` in the file explorer

### Open Cortex Code
Where: payments-hol Workspace, the Cortex Code sidebar (right-hand panel)
Open the Cortex Code sidebar from the right-hand side of the Workspace. You'll paste every prompt in this lab into it. Start a new chat (**+** at the top of the sidebar) at the beginning of each module, so each one starts with a clean context. You're signed in as `HOL_PARTICIPANT` with the `BARCLAYS_WH` warehouse. Cortex Code still checks for a warehouse at the start of each chat, so each module page gives you a one-line context prompt to paste first. That saves it looking.

### See what has been published
```prompt
List the Iceberg tables in BARCLAYS_HOL.RAW_DATA with their row counts, and show the Iceberg metadata location for BARCLAYS_HOL.RAW_DATA.PAYMENTS. Explain what Snowflake-managed Iceberg means for other engines reading this data.
```
Expect: nine Iceberg tables (PAYMENTS has 50,000 rows) and a metadata JSON location
Check: c1_iceberg_published

### Prove the guard-rails
```prompt
Try to insert a test row into BARCLAYS_HOL.RAW_DATA.PAYMENTS using my current role, then explain the error and why the platform team set it up this way.
```
Expect: an "Insufficient privileges" error. That's intentional: sources are read-only.
Check: c1_payments_rows

### Learn the data model
```prompt
Describe the tables in BARCLAYS_HOL.RAW_DATA and how they join together. Draw the relationships as a simple text diagram.
```
Expect: customers -> relationship managers, customers -> accounts -> payments (via ORIGINATOR_ACCOUNT_ID), plus feedback, alerts, schemes, SLAs and error codes

### Profile payments and build a first client 360
```prompt
Using BARCLAYS_HOL.RAW_DATA, show payment count, volume in GBP millions and success rate by PAYMENT_TYPE. Then list the 10 corporate clients with the most failed payments, with their RM, sector, account count and feedback count. Run both queries.
```
Expect: six payment schemes, then a top-10 client table you can sanity-check against the reference SQL

## Check your work
Your role can read all nine Iceberg tables but cannot insert into them.

## Barclayflake note
At Barclays the same tables sit on the bank's own object storage via an external volume; the SQL is identical.
