# Pathways and agendas

Every attendee does the **shared core**, then follows one pathway. Vignettes are self-contained: if a vignette lists a prerequisite you have not built, run the catch-up script it names (about a minute) and carry on. Facilitators run the setup scripts in advance (see the main README).

## Half-day template (about 4 hours)

| Time | Block | Content |
|---|---|---|
| 0:00 | Context (20 min) | Barclays enterprise data platform: Iceberg, read-only sources, approved AI capabilities. Use the reference architecture deck. |
| 0:20 | Shared core (45 min) | [C1 Explore the Iceberg data product](../core/C1_explore_iceberg.sql), [C2 Data product tour](../core/C2_data_product_tour.md) |
| 1:05 | Pathway block A (60 min) | First one or two vignettes in your pathway |
| 2:05 | Break (15 min) | |
| 2:20 | Pathway block B (60 min) | Remaining vignettes in your pathway |
| 3:20 | Cross-persona finale (25 min) | Everyone asks **Corporate Payments 360** about what they built (see below) |
| 3:45 | Wrap-up (15 min) | What's approved at Barclays now, what's next, feedback |

## The five pathways

### Data Engineer
| Block | Vignette | Time |
|---|---|---|
| A | [DE1 Iceberg + dbt pipeline with Cortex Code](../vignettes/de1_iceberg_dbt_pipeline/) | 60 |
| B | [DE2 Dynamic Tables + data quality](../vignettes/de2_dynamic_tables_quality/) | 45 |
| B (stretch) | [GOV2 Lineage and audit](../vignettes/gov2_lineage_audit/) | 15-30 |

### Data Analyst
| Block | Vignette | Time |
|---|---|---|
| A | Run `setup/catchup/core_analytics.sql`, then [DA2 AI SQL on customer feedback](../vignettes/da2_aisql_feedback/) | 45 |
| B | [DA1 Build a semantic view + Cortex Analyst](../vignettes/da1_semantic_view_analyst/) | 60 |
| C (stretch) | [DA3 Branch network and spatial analytics](../vignettes/da3_branch_network_geo/) (uses the retail data in `BARCLAYS_HOL.RETAIL`; no catch-up needed) | 45 |

### Payments Operations analyst (low-code)
| Block | Vignette | Time |
|---|---|---|
| A | Facilitator has pre-run the catch-up scripts and DA1. [OPS1 Corporate Payments 360 agent](../vignettes/ops1_payments_360_agent/) | 45 |
| A/B | [OPS2 Alert triage + negative sentiment feed](../vignettes/ops2_alert_triage/) | 30 |
| B | [DA2 AI SQL on feedback](../vignettes/da2_aisql_feedback/) sections 2.3-2.5 only (AI_FILTER, AI_AGG, AI_COMPLETE) | 30 |

### AI Builder
| Block | Vignette | Time |
|---|---|---|
| A | Run the catch-up scripts and DA1, then [AI1 Agent with custom tools](../vignettes/ai1_agent_tools/) | 45 |
| B | [AI3 Marketplace knowledge extension](../vignettes/ai3_knowledge_extension/) | 30 |
| B | [AI2 Snowflake-managed MCP server](../vignettes/ai2_mcp_server/) (needs OPS1 - run its script first) | 30 |

### Governance / Risk
| Block | Vignette | Time |
|---|---|---|
| A | Run `setup/catchup/core_analytics.sql`, then [GOV1 Classify, tag, mask and filter PII](../vignettes/gov1_pii_policies/) | 45 |
| B | [GOV2 Lineage, audit and trust](../vignettes/gov2_lineage_audit/) | 30 |
| B | [AI3](../vignettes/ai3_knowledge_extension/) discussion: why a knowledge extension is acceptable where Cortex Search is not | 15 |

## Catch-up order (any vignette, any time)

```
setup/catchup/core_analytics.sql          -- staging, marts, FEEDBACK_ENRICHED
setup/catchup/semantic_view_and_agent.sql -- SV_PAYMENTS + PAYMENTS_ASSISTANT
vignettes/da1_semantic_view_analyst/da1.sql   -- SV_CLIENT_360 (needed by OPS1, AI2, AI3)
vignettes/ops1_payments_360_agent/ops1.sql    -- needed by AI2
```

## Cross-persona finale (25 min)

In Snowflake Intelligence, open **Corporate Payments 360** and have each pathway ask a question that uses their work:

- **Data Engineer:** "Which schemes breached SLA most often?" (your dbt marts feed this)
- **Data Analyst:** "Which clients have negative sentiment and a success rate below 96%?" (your semantic view and AI enrichment)
- **Payments Ops:** "Brief me on Royal Trust PLC before my call." (your agent)
- **AI Builder:** ask the same question from Cortex Code through the MCP server
- **Governance:** switch to `HOL_RESTRICTED` and show what changes, and what doesn't leak

## Shorter formats

- **2-hour taster** (the original format): core C1 (20 min), then DE1 (dbt walk-through only), DA2, OPS1 as a facilitator-led flow.
- **Single-persona half day** for a homogeneous group (e.g. all analysts): core, then every vignette for that persona plus the finale.
- **Exec / business demo (30 min):** facilitator runs all catch-ups in advance, then demos OPS1, OPS2 and the GOV1 masking switch.
