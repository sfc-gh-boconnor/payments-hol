# C2: Data product tour (20 min, all personas, facilitator-led)

A guided look at the end state everyone will be building towards, so each pathway knows where its work fits.

```
            Barclays enterprise data platform (published, read-only)
 ┌─────────────────────────────────────────────────────────────────────┐
 │ RAW_DATA - 9 Snowflake-managed Iceberg tables                       │
 │ PAYMENTS  CUSTOMERS  ACCOUNTS  RELATIONSHIP_MANAGERS  CUSTOMER_FEEDBACK │
 │ OPERATIONAL_ALERTS  PAYMENT_SCHEMES  SLA_DEFINITIONS  ERROR_CODES    │
 └───────────────┬─────────────────────────────────────────────────────┘
                 │  Data Engineer: DE1 dbt, DE2 dynamic tables + DMFs
 ┌───────────────▼─────────────────────────────────────────────────────┐
 │ ANALYTICS - staging views, marts, dynamic tables, DP_* Iceberg      │
 │            data products, FEEDBACK_ENRICHED (Analyst: DA2 AI SQL)   │
 └───────────────┬─────────────────────────────────────────────────────┘
                 │  Analyst: DA1 semantic views SV_CLIENT_360, SV_PAYMENTS
 ┌───────────────▼─────────────────────────────────────────────────────┐
 │ AI - Corporate Payments 360 agent (OPS1), triage (OPS2),            │
 │      custom tools (AI1), MCP server (AI2),                          │
 │      Marketplace knowledge extension instead of Cortex Search (AI3) │
 └─────────────────────────────────────────────────────────────────────┘
   Governance across every layer: classification, tags, masking,
   row access (GOV1); lineage, access history, agent monitoring (GOV2)
```

## Talking points

1. **Iceberg is the contract.** Source data arrives centrally as Iceberg, so the same files can be read by other engines. Attendees cannot load or change it, and that is deliberate.
2. **Build data products, not copies.** Everything downstream is a view, dynamic table or mart. DE1 publishes a mart back out as Iceberg.
3. **A semantic view is the trust layer for AI.** Business definitions (success rate, value at risk, open alerts) live in one place. Analyst, agents and MCP clients all use it.
4. **What's approved at Barclays.** Semantic views, Cortex Agents, Snowflake CoWork and MCP are moving forward this quarter. Cortex Search over internal data is not yet approved, so AI3 shows the knowledge-extension alternative.
5. **Governance follows the data.** Policies on the source flow through every model, view and agent, because agents run as the user.

## Demo (facilitator, 5 min)
If the facilitator has run the full build, open Snowflake CoWork and ask **Corporate Payments 360**: "Brief me on the client with the most failed payment value." Then show the lineage graph for `RAW_DATA.PAYMENTS` in Catalog.
