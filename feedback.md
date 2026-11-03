# Lab feedback

Test run: DataOps event `test-barclays-hol-roconnor` (v2, 2 Nov 2026).

Each issue: where it happened, what went wrong, what was expected, and severity
(**Blocker** stops the attendee, **Major** confusing or wrong, **Minor** polish).

## Setup and access

### 1. Attendees aren't sent to the Lab Companion app (Blocker) - FIXED 3 Nov

- **Fix:** the v2 install now runs inside Configure Attendee Account, which exports `LAB_COMPANION_URL` to the dotenv the instructions page reads. The event instructions (`dataops-integration/event_instructions.md`, applied with the admin API) show **1. Open Lab Companion** and **2. Open Snowflake**, each in its own tab. The old DataOps homepage button and job were removed.

- **Where:** the DataOps event instructions page (the event `instructions` template, edited through the admin API).
- **What happened:** the page has one "Lab Instructions" button (the DataOps homepage) and the Snowflake account URL. Nothing links to the Lab Companion, so attendees don't know to open it, and it's the lab guide with Check my work.
- **Expected:** two clear links, each opening in its own window, so attendees work with both side by side:
  1. **Open the Lab Companion**: this account's app URL (`https://<id>.snowflakecomputing.app`).
  2. **Open Snowflake**: `https://{{vars.DATAOPS_SNOWFLAKE_ACCOUNT}}.snowflakecomputing.com`.
- **Notes for the fix:**
  - The template gets per-account values from `vars`, which come from the dotenv artifact `dataops/event/attendee_account_outputs.env`, exported by **Configure Attendee Account**.
  - The Lab Companion URL is only known after **Deploy Barclays HOL v2**, so that job would need to export it (for example `LAB_COMPANION_URL`) in the same way.
  - Still to confirm: whether the instructions page reads `vars` from that job's dotenv, or only from Configure's.
  - `target="_blank"` on both links opens them in separate windows or tabs. Separate windows can't be forced; the page could tell attendees to drag one to its own window.
  - The URL format differs per account (for example `eqnravb-…-ukssih.snowflakecomputing.app`), so it must come from `SHOW APPLICATION SERVICES`, not be built from the account name.

## Lab Companion

## Workspace (payments-hol)

## C1 Explore the Iceberg data product

## C2 Data product tour

## DE1 Iceberg + dbt pipeline

## DE2 Dynamic Tables + data quality

## DA1 Semantic view + Cortex Analyst

## DA2 AI SQL on customer feedback

## OPS1 Corporate Payments 360 agent

## OPS2 Alert triage

## AI1 Agent with custom tools

## AI2 Snowflake-managed MCP server

## AI3 Marketplace knowledge extension

## GOV1 PII policies

## GOV2 Lineage, audit and trust

## General
