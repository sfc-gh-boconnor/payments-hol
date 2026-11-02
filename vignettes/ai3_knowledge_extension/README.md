# AI3: Marketplace knowledge extension (instead of Cortex Search)

| | |
|---|---|
| **Persona** | AI Builder |
| **Time** | ~30 min |
| **Prerequisites** | Facilitator setup 00 (installs `SNOWFLAKE_DOCS_CKE`), DA1 |
| **Script** | [`ai3.sql`](ai3.sql) |

## Business question
> Agents need trusted unstructured knowledge, but internal (PII) data cannot be vectorised yet. What can we do?

## What you'll build
- Agent `SNOWFLAKE_INTELLIGENCE.AGENTS.PAYMENTS_PLATFORM_COPILOT` combining `SV_CLIENT_360` with a provider-hosted search service

## Steps
1. Inspect the installed Cortex Knowledge Extension - note you did not build it.
2. Query it with `SEARCH_PREVIEW`.
3. Create an agent that uses both internal data and the extension.
4. Ask a question that needs both.

## Cortex Code prompts
- *"Which 3 clients have the most open critical alerts, and how could I build a dynamic table to keep that list up to date?"*

## Check your work
The agent calls both `Client360` and `PlatformDocs` and cites documentation URLs.

## Barclayflake note
Cortex Search over internal data is not approved at Barclays. Knowledge extensions are built and hosted by the provider; no bank data is indexed. Finance publishers (e.g. Investopedia, FactSet) offer extensions too - personalised listings must be requested by the account admin.
