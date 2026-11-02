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
guide/          interactive HTML lab guide with pathway selector
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

## Facilitator setup (once per lab account, about 10 minutes)

Run as ACCOUNTADMIN in a Snowsight worksheet, or with the Snowflake CLI:

```bash
snow sql -c <connection> -f setup/00_admin_provision.sql    # roles, DB, warehouse, Marketplace knowledge extension
snow sql -c <connection> -f setup/01_seed_synthetic_data.sql # synthetic data (SEED schema)
snow sql -c <connection> -f setup/02_publish_iceberg.sql     # publish as Snowflake-managed Iceberg
snow sql -c <connection> -f setup/03_add_participants.sql    # optional: shared-account events
snow dbt deploy BARCLAYS_DBT --source dbt --database BARCLAYS_HOL --schema ANALYTICS --role HOL_PARTICIPANT -c <connection>
```

`00` accepts the Marketplace terms for the free **Snowflake Documentation** knowledge extension (listing `GZSTZ67BY9OQ4`) and installs it as `SNOWFLAKE_DOCS_CKE`. To use a finance publisher instead (for example Investopedia), request the listing in Snowsight, then update the service name in `ai3.sql` and `ai2.sql`.

For the **Payments Ops** pathway (low-code), also pre-run the catch-up scripts and DA1 so the agent has data to use. See [pathways/](pathways/README.md#catch-up-order-any-vignette-any-time).

Teardown: `snow sql -c <connection> -f teardown/teardown.sql`

## Attendee start

1. Log in and switch to role `HOL_PARTICIPANT`.
2. Open a Workspace from this Git repository (**Projects > Workspaces > From Git repository**).
3. Run [`core/C1_explore_iceberg.sql`](core/C1_explore_iceberg.sql), then follow your pathway.

Every attendee script starts with `USE SECONDARY ROLES NONE` so facilitators testing with admin rights see exactly what attendees see.

## Tested

Validated end to end on 2026-11-02 in a demo account (AWS us-west-2), from teardown to a full rebuild: every setup, catch-up and vignette script, the dbt build (27 passing), Cortex Analyst, all four agents, and the MCP server over HTTP as `HOL_PARTICIPANT`.

## Credits

Original lab, data model and dbt project: Gemma McGinlay. v2 modularisation: Becky O'Connor.
