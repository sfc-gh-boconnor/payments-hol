# OPS2: Alert triage + negative sentiment feed

| | |
|---|---|
| **Persona** | Payments Ops analyst / team lead |
| **Time** | ~30 min |
| **Prerequisites** | `setup/catchup/core_analytics.sql` |
| **Script** | [`ops2.sql`](ops2.sql) |

## Business question
> Which open alerts should my team work first, what should we do, and which unhappy clients are linked to them?

## What you'll build
- `DT_NEGATIVE_SENTIMENT_FEED`
- `V_ALERT_TRIAGE_QUEUE` with an explainable priority score
- `ALERT_RECOMMENDATIONS` (AI next actions for the top 10)

## Steps
1. Create the negative-sentiment dynamic table.
2. Build and review the prioritised triage queue.
3. Generate recommended actions with `AI_COMPLETE`.
4. Optionally add a Triage page to the Streamlit dashboard with CoCo.

## Cortex Code prompts
- *"Add a 'Triage' page to the Streamlit app showing V_ALERT_TRIAGE_QUEUE with ALERT_RECOMMENDATIONS alongside."*

## Check your work
The top recommendation for a critical compliance-hold alert says not to retry and to escalate.

## Barclayflake note
Recommendations are decision support for an analyst, not automated actions.
