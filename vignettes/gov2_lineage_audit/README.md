# GOV2: Lineage, audit and trust

| | |
|---|---|
| **Persona** | Governance / Risk / Audit |
| **Time** | ~30 min |
| **Prerequisites** | DE1 or catch-up, plus at least one agent run |
| **Reference SQL** | [`gov2.sql`](gov2.sql) |

## Business question
> If a source Iceberg table changes, what breaks? And who - human or agent - has been reading client data?

## What you'll build
- Lineage and access-history queries
- Business comments on the SLA data product

## Steps
### Set your context
Where: payments-hol Workspace > **+ > SQL file**
```sql
USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.ANALYTICS;
```

### Impact analysis on the Iceberg source
Where: the Cortex Code sidebar; also Snowsight > **Catalog > BARCLAYS_HOL > RAW_DATA > PAYMENTS > Lineage**
```prompt
If I drop the column PROCESSING_TIME_MS from BARCLAYS_HOL.RAW_DATA.PAYMENTS, which downstream objects and agents break? Use SNOWFLAKE.CORE.GET_LINEAGE downstream to 3 levels, and explain any objects shown as ***.***.***.
```
Expect: the staging views, marts, dynamic tables and `SV_CLIENT_360`. Masked rows are objects your role can't see: lineage never leaks them.

### Where does the data product come from?
```prompt
Show the upstream lineage of BARCLAYS_HOL.ANALYTICS.MART_SLA_COMPLIANCE to 3 levels, and list object dependencies in BARCLAYS_HOL from SNOWFLAKE.ACCOUNT_USAGE.OBJECT_DEPENDENCIES.
```
Expect: the path back from the mart through dbt staging to the Iceberg sources

### Who read restricted columns?
```prompt
From SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY, show who accessed the IBAN, ACCOUNT_NUMBER or SORT_CODE columns of any BARCLAYS_HOL object in the last day, with time, user and object.
```
Expect: recent reads, including your GOV1 queries. ACCOUNT_USAGE can lag by up to about 3 hours, so this may be empty early in the day.

### What are our agents doing?
Where: the Cortex Code sidebar; also Snowsight > **AI & ML > Agents > CORPORATE_PAYMENTS_360 > Monitoring**
```prompt
From SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY, show queries in the last day against BARCLAYS_HOL that used SEMANTIC_VIEW, with user, role, start time, duration and a preview of the SQL.
```
Expect: the queries your agents and Cortex Analyst generated, attributed to the user who asked

### Document the data product
```prompt
Add a table comment to BARCLAYS_HOL.ANALYTICS.MART_SLA_COMPLIANCE that starts "Daily SLA compliance per payment scheme. Owner: Payments Operations." and states its grain (day x scheme) and source, plus a column comment on SLA_STATUS explaining COMPLIANT, AT RISK and BREACH. Then produce a one-page data product card for it: owner, grain, lineage, quality checks, sensitivity tags and consumers.
```
Expect: the comments saved, so humans and AI find the right table, and a data product card in the sidebar
Check: gov2_documented

## Check your work
Downstream lineage lists the staging views, marts, dynamic tables and `SV_CLIENT_360`.

## Barclayflake note
ACCOUNT_USAGE views have up to ~3 hours latency - run history queries at the end of the session.
