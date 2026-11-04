# GOV2: Lineage, audit and trust

| | |
|---|---|
| **Persona** | Governance / Risk / Audit |
| **Time** | ~30 min |
| **Prerequisites** | C1 only. GOV2 uses a ready-made audit pack in `BARCLAYS_HOL.AUDIT_PACK`, so it doesn't depend on any other module |
| **Reference SQL** | [`gov2.sql`](gov2.sql) |

## Business question
> If a source Iceberg table changes, what breaks? And who - human or agent - has been reading client data?

## What you'll build
- Lineage and access-history queries
- Business comments on the SLA data product
- A daily Cortex Code automation `RESTRICTED_COLUMN_WATCH` reporting new reads of restricted columns

## Steps
### Ask the agent a few questions first
Where: Snowsight > **AI & ML > Agents > PAYMENTS_AUDIT_AGENT** (the chat on the right)
GOV2 audits a ready-made **audit pack** in `BARCLAYS_HOL.AUDIT_PACK`, built on the Iceberg sources: a daily SLA data product (`PAYMENT_SLA_DAILY`), a client accounts view with restricted columns (`CLIENT_ACCOUNTS`), a semantic view (`SV_PAYMENTS_AUDIT`) and an agent (`PAYMENTS_AUDIT_AGENT`). It's separate from everything the other modules build, so you can still do those afterwards. Do this now, at the start of the module: agent usage takes up to about 45 minutes to reach ACCOUNT_USAGE, so the queries you ask here are what you'll audit in "What are our agents doing?" later. Ask the agent three questions, one at a time: paste the first from the card below, then ask "What is the success rate by payment scheme?" and "How many client accounts does each relationship manager look after?"
Paste: the **PAYMENTS_AUDIT_AGENT** chat (not the Cortex Code sidebar)
```prompt
Which payment scheme had the most SLA breach days?
```
Expect: an answer to each question, with the SQL the agent ran over SV_PAYMENTS_AUDIT. Carry on with the next steps while the usage data arrives.

### Impact analysis on the Iceberg source
Where: the Cortex Code sidebar; also Snowsight > **Catalog > BARCLAYS_HOL > RAW_DATA > PAYMENTS > Lineage**
```prompt
If I drop the column PROCESSING_TIME_MS from BARCLAYS_HOL.RAW_DATA.PAYMENTS, which downstream objects and agents break? Use SNOWFLAKE.CORE.GET_LINEAGE downstream to 3 levels, and explain any objects shown as ***.***.***.
```
Expect: the audit pack chain `PAYMENT_SLA_DAILY` > `SV_PAYMENTS_AUDIT` > `PAYMENTS_AUDIT_AGENT`, so the agent breaks, plus any staging views, marts and dynamic tables you built in other modules. Masked rows are objects your role can't see: lineage never leaks them.

### Where does the data product come from?
```prompt
Show the upstream lineage of the agent BARCLAYS_HOL.AUDIT_PACK.PAYMENTS_AUDIT_AGENT to 3 levels (use OBJECT_DOMAIN CORTEX_AGENT), so I can see which semantic view, tables and Iceberg sources its answers come from.
```
Expect: the path back from the agent through `SV_PAYMENTS_AUDIT` and `PAYMENT_SLA_DAILY` to the Iceberg tables in `RAW_DATA`

### Who read restricted columns?
```prompt
From SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY, show who accessed the IBAN, ACCOUNT_NUMBER or SORT_CODE columns of any BARCLAYS_HOL object in the last day, with time, user and object.
```
Expect: recent reads, including your GOV1 queries if you did GOV1. To be sure there's something to find, first run `SELECT * FROM BARCLAYS_HOL.AUDIT_PACK.CLIENT_ACCOUNTS LIMIT 5`. ACCOUNT_USAGE can lag by up to about 3 hours, so this may be empty early in the day.

### Turn the access check into a daily automation
Where: the Cortex Code sidebar (same chat as the step above)
**Autonomous Data Engineering:** autonomous agents. A Cortex Code automation (GA in the CLI, public preview in Desktop) runs a prompt on a schedule, unattended; Cortex Code Cloud Agents take the same idea to longer, background tasks.
Cortex Code offers to run the access-history query as a daily **Cortex Code automation**: a scheduled, unattended Cortex Code run in a Snowflake-managed sandbox. Accept the offer, or ask for it:
```prompt
Set up a daily Cortex Code automation called RESTRICTED_COLUMN_WATCH that runs at 08:00 Europe/London. Each run: query SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY for reads of the IBAN, ACCOUNT_NUMBER or SORT_CODE columns of any BARCLAYS_HOL object in the last 24 hours, and report who read them, when, and from which object. It runs unattended, so it must not ask questions and must stay read-only. Create it paused, run it once now so I can see the report, then start the schedule.
```
Expect: Cortex Code summarises the automation (name, schedule, read-only), creates it paused, runs it once and shows the report, then asks before starting the schedule. See it under **Automations** in the Cortex Code sidebar. Each run uses your default role (`HOL_PARTICIPANT`), so it sees exactly what you see: masked values stay masked. Your lab login has no email address, so there's no emailed run report; read the report in the run's thread instead.
Check: gov2_automation

### What are our agents doing?
Where: the Cortex Code sidebar; also Snowsight > **AI & ML > Agents > PAYMENTS_AUDIT_AGENT > Monitoring**
```prompt
From SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY, show queries in the last day against BARCLAYS_HOL that used SEMANTIC_VIEW, with user, role, start time, duration and a preview of the SQL.
```
Expect: the queries your agents and Cortex Analyst generated, including the three questions you asked at the start, attributed to the user who asked. If they aren't there yet, usage can take up to about 45 minutes to appear: carry on with the last step and come back to this one.

### Document the data product
```prompt
Add a table comment to BARCLAYS_HOL.AUDIT_PACK.PAYMENT_SLA_DAILY that starts "Daily SLA compliance per payment scheme. Owner: Payments Operations." and states its grain (day x scheme) and source, plus a column comment on SLA_STATUS explaining COMPLIANT, AT RISK and BREACH. Then produce a one-page data product card for it: owner, grain, lineage, quality checks, sensitivity tags and consumers.
```
Expect: the comments saved, so humans and AI find the right table, and a data product card in the sidebar
Check: gov2_documented

## Check your work
Downstream lineage from `RAW_DATA.PAYMENTS` reaches `PAYMENTS_AUDIT_AGENT`, the agent's questions show in query history, and `PAYMENT_SLA_DAILY` is documented.

## Barclayflake note
ACCOUNT_USAGE views have up to ~3 hours latency - run history queries at the end of the session.
