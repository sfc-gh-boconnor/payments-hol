# AI1: Agent with custom tools

| | |
|---|---|
| **Persona** | AI Builder |
| **Time** | ~45 min |
| **Prerequisites** | `core_analytics.sql`, `semantic_view_and_agent.sql` |
| **Script** | [`ai1.sql`](ai1.sql) |

## Business question
> Ops staff ask about specific payments by ID and about scheme rules - not just aggregates. Give the agent precise tools.

## What you'll build
- UDF tools `PAYMENT_LOOKUP`, `SCHEME_RULES`
- Agent `BARCLAYS_HOL.AGENTS.PAYMENTS_INVESTIGATOR`

## Steps
1. Create and test the two UDFs.
2. Create the agent with generic (function) tools plus Analyst.
3. Test in the agent playground with a real failed payment ID.

## Cortex Code prompts
- *"Add a third tool to PAYMENTS_INVESTIGATOR that lists open alerts for a customer name, using a new UDF."*

## Check your work
Asking about a failed CHAPS payment calls `PaymentLookup` then `SchemeRules` and reports retryability and the 15:45 cutoff.

## Barclayflake note
Deterministic tools for lookups keep answers exact and auditable; text-to-SQL is reserved for analytical questions.
