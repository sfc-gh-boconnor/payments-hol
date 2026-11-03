# AI3: Marketplace knowledge extension

| | |
|---|---|
| **Persona** | AI Builder |
| **Time** | ~30 min |
| **Prerequisites** | Facilitator setup 00 (installs `SNOWFLAKE_DOCS_CKE`), DA1 |
| **Reference SQL** | [`ai3.sql`](ai3.sql) |

## Business question
> Agents need trusted unstructured knowledge, but internal (PII) data cannot be vectorised yet. What can we do?

## What you'll build
- Agent `SNOWFLAKE_INTELLIGENCE.AGENTS.PAYMENTS_PLATFORM_COPILOT` combining `SV_CLIENT_360` with a provider-hosted search service

## Steps
### See what came from the Marketplace
Where: Snowsight > **Data Products > Marketplace**, search "Cortex Knowledge Extension"; then the Cortex Code sidebar
Browse the knowledge extension listings (finance publishers are there too). Then, in the payments-hol Workspace:
```prompt
Show the Cortex Search services in database SNOWFLAKE_DOCS_CKE and explain what a Cortex Knowledge Extension is: who built and hosts it, what we can see of its source data, and how we pay for it.
```
Expect: the `CKE_SNOWFLAKE_DOCS_SERVICE` search service. You didn't build it and can't see its source table.
Check: ai3_extension

### Query it directly
```prompt
Use SNOWFLAKE.CORTEX.SEARCH_PREVIEW on SNOWFLAKE_DOCS_CKE.SHARED.CKE_SNOWFLAKE_DOCS_SERVICE to answer "How do I apply a masking policy to a column?", returning DOCUMENT_TITLE, SOURCE_URL and the first 200 characters of CHUNK for the top 3 results.
```
Expect: three documentation excerpts with their URLs

### Create an agent that uses both
Where: payments-hol Workspace > **+ > Agent** > **Create with CoCo** (recommended)
Name the new agent file `payments_platform_copilot` straight away, then paste this brief.
```prompt
Create a Cortex Agent SNOWFLAKE_INTELLIGENCE.AGENTS.PAYMENTS_PLATFORM_COPILOT with display name "Payments Platform Copilot". Tools: a Cortex Analyst tool Client360 on BARCLAYS_HOL.ANALYTICS.SV_CLIENT_360 (warehouse BARCLAYS_WH) for client, alert and sentiment data, and a Cortex Search tool PlatformDocs on SNOWFLAKE_DOCS_CKE.SHARED.CKE_SNOWFLAKE_DOCS_SERVICE (max 4 results, title column DOCUMENT_TITLE, id column SOURCE_URL) for how-to questions about Snowflake. Instructions: use Client360 for data questions, PlatformDocs for how-to questions, both when a question needs both, and cite documentation URLs. Deploy it.
```
Expect: `PAYMENTS_PLATFORM_COPILOT` deployed in `SNOWFLAKE_INTELLIGENCE.AGENTS`
Check: ai3_agent

### Ask a question that needs both
Where: Snowsight > **AI & ML > Snowflake Intelligence** > **Payments Platform Copilot**
Ask "Which 3 clients have the most open critical alerts, and how could I build a dynamic table to keep that list up to date?"
Expect: the agent calls both `Client360` and `PlatformDocs`, names three clients and cites documentation URLs

## Check your work
The agent calls both `Client360` and `PlatformDocs` and cites documentation URLs.

## Barclayflake note
Cortex Search over internal data is not approved at Barclays. Knowledge extensions are built and hosted by the provider; no bank data is indexed. Finance publishers (e.g. Investopedia, FactSet) offer extensions too - personalised listings must be requested by the account admin.
