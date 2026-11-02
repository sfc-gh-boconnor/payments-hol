# DA2: AI SQL on customer feedback

| | |
|---|---|
| **Persona** | Data Analyst |
| **Time** | ~45 min |
| **Prerequisites** | `setup/catchup/core_analytics.sql` (or DE1) |
| **Script** | [`da2.sql`](da2.sql) |

## Business question
> What are corporate clients actually complaining about, by scheme and by relationship manager - without reading 2,000 comments?

## What you'll build
- `FEEDBACK_ENRICHED` (sentiment + topic)
- `RM_FEEDBACK_THEMES` (AI_AGG themes and actions per RM)

## Steps
1. Aspect sentiment with `AI_SENTIMENT`.
2. Enrich all feedback with sentiment and `AI_CLASSIFY` topics.
3. Natural-language filtering with `AI_FILTER` (churn risk).
4. Per-RM complaint themes with `AI_AGG`.
5. Draft a client reply with `AI_COMPLETE`.

## Cortex Code prompts
- *"Show which customer sectors have worsening sentiment month over month and chart it."*
- *"Use AI_EXTRACT on FEEDBACK_TEXT to pull out payment references or amounts into FEEDBACK_ENTITIES."*

## Check your work
`RM_FEEDBACK_THEMES` has one row per RM with three themes and actions.

## Barclayflake note
AI functions run inside Snowflake's security boundary - no data leaves the platform and nothing is vectorised or stored by the model.
