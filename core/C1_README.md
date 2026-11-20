# C1: Explore the Iceberg data product

| | |
|---|---|
| **Persona** | All personas |
| **Time** | ~25 min |
| **Prerequisites** | Facilitator setup complete |

## Business question
> What has the platform team published to us, and what can we (not) do with it?

## What you'll build
- Nothing yet: you explore the nine read-only Snowflake-managed Iceberg tables with Cortex Code, and get to know the Workspace you'll build everything else in.

## Steps
### Open Cortex Code
Where: Snowsight home page, the **Home / CoCo** toggle (top left) > **CoCo**
Media: start_open_coco.mp4 | Home > CoCo, then paste the first prompt
1. At the top left of Snowsight, switch the toggle from **Home** to **CoCo**.
2. Close the **CoCo mode (preview)** pop-up if it appears.
3. Press **New session**.
4. Paste each prompt in this module into the **How can I help?** box.
What's on the CoCo screen:
- **New session** starts a fresh chat. Start one for each module, so it begins with a clean context.
- **Automations** lists prompts scheduled to run on their own. You'll create one in GOV2.
When Cortex Code wants to run a query, it shows a **Run this command?** card:
- **Allow** lets it run
- **Skip** stops it
**Tip:** you're signed in as `HOL_PARTICIPANT`, with `BARCLAYS_WH` and `BARCLAYS_HOL` as your defaults. Cortex Code uses them, so you don't need to set a role or warehouse.
Expect: the Cortex Code screen with a **How can I help?** box

### See what has been published
```prompt
List the Iceberg tables in BARCLAYS_HOL.RAW_DATA with their row counts, and show the Iceberg metadata location for BARCLAYS_HOL.RAW_DATA.PAYMENTS. Explain what Snowflake-managed Iceberg means for other engines reading this data.
```
Expect: nine Iceberg tables (PAYMENTS has 50,000 rows) and a metadata JSON location
Check: c1_iceberg_published

### Go back Home and open the payments-hol Workspace
Where: the **Home / CoCo** toggle > **Home**, then **Projects > Workspaces** > the **My Workspace** dropdown (top left) > **payments-hol**
Media: start_open_workspace.mp4 | CoCo > Home > Workspaces > payments-hol, then the Cortex Code sidebar
1. Switch the toggle at the top left back to **Home**.
2. Open **Projects > Workspaces**.
3. Open the **My Workspace** dropdown (top left) and pick **payments-hol**.
**Important:** go back to **Home** first. Workspaces isn't on the CoCo side.
What's in the Workspace:
- **+** creates SQL files, notebooks, dbt projects, Streamlit apps, agents, semantic views and pipelines
- the file explorer (left) holds the lab: `dbt/`, `notebooks/`, `vignettes/`
- the bottom panel has Query History and, later, the dbt pane
- Cortex Code is here too, as a sidebar: the round button at the bottom right
Use **payments-hol** whenever a module says Workspace. Cortex Code only finds the lab files when it's open.
**Tip:** Snowsight sometimes reopens **My Workspace**. Check the name at the top left whenever you come back.
For the rest of this module, use either the CoCo tab or the Workspace sidebar.
Expect: the payments-hol Workspace open, with `dbt/`, `notebooks/` and `vignettes/` in the file explorer

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
Expect: six payment schemes, then a top-10 client table ranked by failed payments, with each client's RM and sector

## Check your work
Your role can read all nine Iceberg tables but cannot insert into them.

## Barclayflake note
At Barclays the same tables sit on the bank's own object storage via an external volume; the SQL is identical.
