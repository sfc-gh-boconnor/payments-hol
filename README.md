# Barclays Payments Operations - Hands-on Lab v2

A modular, half-day hands-on lab: build a **Corporate Banking Payments Operations data product** on Snowflake, from Snowflake-managed Iceberg sources to governed AI agents. It is split into persona pathways so the same asset serves data engineers, analysts, payments operations, AI builders and governance teams.

v2 of [gemmamcginlay-sf/barclays-hol](https://github.com/gemmamcginlay-sf/barclays-hol) (the 2-hour lab by Gemma McGinlay). The synthetic data model, dbt project, semantic view and dashboard come from that lab. The original SQL and guide are kept in [`legacy/`](legacy/).

> All data is entirely synthetic. No real customer, transaction or Barclays data is used.

## How it mirrors the Barclays platform

| Barclays enterprise platform | In this lab |
|---|---|
| Source data lands centrally in Iceberg | `BARCLAYS_HOL.RAW_DATA`: 9 **Snowflake-managed Iceberg** tables (no external volume needed) |
| End users cannot load data | Attendees (`HOL_PARTICIPANT`) have read-only access to `RAW_DATA` and build in `ANALYTICS` / `AGENTS` |
| Semantic Views, Agents, MCP and CoWork approved this quarter | Covered by DA1, OPS1, AI1, AI2 |
| Cortex Search over internal data not approved (PII and vectorisation concerns) | **No search service is built.** AI3 uses a Marketplace Cortex Knowledge Extension instead |
| Strict governance | GOV1 tags, masking and row access; GOV2 lineage and audit |

## Structure

```
setup/          facilitator: provisioning, synthetic data, Iceberg publish, catch-up scripts
core/           shared core for all attendees (C1 SQL, C2 tour)
vignettes/      11 self-contained modules, each with README.md + .sql
pathways/       persona agendas, half-day template, shorter formats
dbt/            dbt project (runs as a dbt Project on Snowflake)
payments-dashboard/  Streamlit dashboard
guide/          static HTML lab guide (offline fallback for the Lab Companion)
lab-companion/  Lab Companion: React app on Snowflake App Runtime with Check my work
getting-started/  DataOps Live attendee landing page (step1.md)
dataops-integration/  DataOps configure step and wake-schedule reschedule
teardown/       remove everything
legacy/         original 2-hour lab files
docs/           data model, ERD and column dictionary
```

## Vignettes

| Code | Vignette | Persona | Min |
|---|---|---|---|
| [DE1](vignettes/de1_iceberg_dbt_pipeline/) | Iceberg + dbt pipeline with Cortex Code | Data Engineer | 60 |
| [DE2](vignettes/de2_dynamic_tables_quality/) | Dynamic Tables + data quality (DMFs) | Data Engineer | 45 |
| [DA1](vignettes/da1_semantic_view_analyst/) | Build a semantic view + Cortex Analyst | Data Analyst | 60 |
| [DA2](vignettes/da2_aisql_feedback/) | AI SQL on customer feedback (sentiment, AI_AGG themes per RM) | Data Analyst | 45 |
| [OPS1](vignettes/ops1_payments_360_agent/) | Corporate Payments 360 agent in Snowflake Intelligence | Payments Ops | 45 |
| [OPS2](vignettes/ops2_alert_triage/) | Alert triage + negative sentiment feed | Payments Ops | 30 |
| [AI1](vignettes/ai1_agent_tools/) | Agent with custom (UDF) tools | AI Builder | 45 |
| [AI2](vignettes/ai2_mcp_server/) | Snowflake-managed MCP server | AI Builder | 30 |
| [AI3](vignettes/ai3_knowledge_extension/) | Marketplace knowledge extension instead of Cortex Search | AI Builder | 30 |
| [GOV1](vignettes/gov1_pii_policies/) | Classify, tag, mask and filter PII | Governance | 45 |
| [GOV2](vignettes/gov2_lineage_audit/) | Lineage, audit and trust | Governance | 30 |

See [pathways/](pathways/README.md) for the half-day agenda and which vignettes each persona runs.

## Setup: two options

The Iceberg sources, read-only access and Marketplace extension recreate the Barclays platform constraints inside the lab account. Either way, every account ends with the **Lab Companion**, the live lab guide.

| | Option 1: DataOps pre-provisioned accounts | Option 2: any account |
|---|---|---|
| Who | Hands-on lab team, before the event | Anyone with ACCOUNTADMIN |
| Data and objects | `dataops-integration/configure_account.sh` (or `setup/provision_account.sh`) | Paste [`INSTALL.sql`](INSTALL.sql) into a Snowsight worksheet, Run All |
| Lab Companion | Installed by the same script | `./setup/install_lab_companion.sh <connection>` from a clone (Snowflake CLI) |
| Wake schedule | From the event times | Not needed |

The Lab Companion needs **Snowflake App Runtime** on the account.

### Option 2: any account

1. In Snowsight, open a SQL worksheet, paste [`INSTALL.sql`](INSTALL.sql), set the role to ACCOUNTADMIN and press **Run All** (about 10 minutes). It connects the account to this GitHub repo and runs the setup scripts and dbt project from it. Uncomment section 5 for the Payments Ops reference build.
2. From a clone of the repo, with a Snowflake CLI connection (ACCOUNTADMIN): `./setup/install_lab_companion.sh <connection>`. It prints the Lab Companion URL.
3. Grant `HOL_PARTICIPANT` to attendees (`setup/03_add_participants.sql`).

### Option 1: DataOps or CLI, everything in one command

From a clone of this GitHub repo, with a Snowflake CLI connection (ACCOUNTADMIN) to each account:

```bash
./setup/provision_account.sh <connection>                          # everything, about 10 minutes
./setup/provision_account.sh <connection> --with-reference-build   # also pre-builds analytics, semantic views and agents
```

The script runs these steps in order:

```bash
snow sql -c <connection> -f setup/00_admin_provision.sql    # roles, DB, warehouse, Marketplace knowledge extension
snow sql -c <connection> -f setup/01_seed_synthetic_data.sql # synthetic data (SEED schema)
snow sql -c <connection> -f setup/02_publish_iceberg.sql     # publish as Snowflake-managed Iceberg
snow sql -c <connection> -f setup/git_repo.sql              # connect the lab GitHub repo (skipped with a warning if unreachable)
snow dbt deploy BARCLAYS_DBT --source dbt --database BARCLAYS_HOL --schema ANALYTICS --role HOL_PARTICIPANT -c <connection>
snow sql -c <connection> -f setup/04_lab_companion.sql      # Lab Companion schema + progress table
./setup/install_lab_companion.sh <connection>                # Lab Companion app + URL
snow sql -c <connection> -f setup/05_wake_schedule.sql      # WAKE_LAB / SLEEP_LAB / SCHEDULE_LAB
```

Accounts are provisioned days ahead, so set the event times to wake the Lab Companion 30 minutes before the start and let it auto-suspend again afterwards:

```bash
LAB_START='2026-12-01 09:30:00 +00:00' LAB_END='2026-12-01 13:30:00 +00:00' ./setup/provision_account.sh <connection>
```

Without them, no tasks are created; run `CALL BARCLAYS_HOL.LAB.WAKE_LAB();` on the day. With DataOps, use [`dataops-integration/`](dataops-integration/README.md), which maps `EVENT_START_DATETIME` / `EVENT_END_DATETIME`.

Then grant `HOL_PARTICIPANT` to the attendee users (`setup/03_add_participants.sql`).

`00` accepts the Marketplace terms for the free **Snowflake Documentation** knowledge extension (listing `GZSTZ67BY9OQ4`) and installs it as `SNOWFLAKE_DOCS_CKE`. To use a finance publisher instead (for example Investopedia), request the listing in Snowsight, then update the service name in `ai3.sql` and `ai2.sql`.

For the **Payments Ops** pathway (low-code), also pre-run the catch-up scripts and DA1 so the agent has data to use. See [pathways/](pathways/README.md#catch-up-order-any-vignette-any-time).

Teardown: `(cd lab-companion && snow app teardown --force -c <connection> --role HOL_ADMIN)`, then `snow sql -c <connection> -f teardown/teardown.sql`

## Lab Companion app

Every account gets the **Lab Companion**, a React app on Snowflake App Runtime ([`lab-companion/`](lab-companion/README.md)):

- **Pathways:** the attendee picks a persona and the app orders the modules for them.
- **Instructions:** each module's steps and SQL, generated from this repo.
- **Check my work:** a button per module that validates the objects the attendee actually built.
- **Progress:** stored in `BARCLAYS_HOL.LAB.LAB_PROGRESS`.
- **Facilitator view:** `/facilitator` shows who is stuck.

The provisioning script prints the app URL at the end.

## Attendee start

1. Log in and switch to role `HOL_PARTICIPANT`.
2. Open the **Lab Companion** app (URL from the facilitator) and choose your pathway.
3. Open the lab Workspace **payments-hol** (**Projects > Workspaces**, then the **My Workspace** dropdown > **payments-hol**) and the **Cortex Code** sidebar. Each Lab Companion step gives a prompt to paste; the module SQL is a fallback. DataOps accounts have it already; on any other account, create it from this repo with **Projects > Workspaces > From Git repository**.
4. Start with C1, then press **Check my work** at the end of each module.

Every attendee script starts with `USE SECONDARY ROLES NONE` so facilitators testing with admin rights see exactly what attendees see.

## Tested

Validated end to end on 2026-11-02 in a demo account (AWS us-west-2), from teardown to a full rebuild: every setup, catch-up and vignette script, the dbt build (27 passing), Cortex Analyst, all four agents, and the MCP server over HTTP as `HOL_PARTICIPANT`.

## Credits

Original lab, data model and dbt project: Gemma McGinlay. v2 modularisation: Becky O'Connor.
