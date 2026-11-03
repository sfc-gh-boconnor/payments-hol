# DA2: AI SQL on customer feedback

| | |
|---|---|
| **Persona** | Data Analyst |
| **Time** | ~45 min |
| **Prerequisites** | `setup/catchup/core_analytics.sql` (or DE1) |
| **Reference SQL** | [`da2.sql`](da2.sql) |

## Business question
> What are corporate clients actually complaining about, by scheme and by relationship manager - without reading 2,000 comments?

## What you'll build
- `FEEDBACK_ENRICHED` (sentiment + topic)
- `RM_FEEDBACK_THEMES` (AI_AGG themes and actions per RM)

## Steps
### Set your context
Where: payments-hol Workspace > **+ > SQL file** (or **+ > Notebook**)
```sql
USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.ANALYTICS;
```

### Score sentiment by aspect
Where: the Cortex Code sidebar
```prompt
Using AI_SENTIMENT, score 5 rows of FEEDBACK_TEXT from BARCLAYS_HOL.ANALYTICS.STG_FEEDBACK overall and for the aspects speed, communication and fees. Explain what the output means.
```
Expect: an overall score plus a separate sentiment for each aspect

### Enrich all feedback once
```prompt
Create a table BARCLAYS_HOL.ANALYTICS.FEEDBACK_ENRICHED from STG_FEEDBACK left-joined to STG_CUSTOMERS. Keep the feedback columns plus CUSTOMER_NAME, CUSTOMER_SECTOR and RM_NAME. Add SENTIMENT_SCORE (rounded to 3 dp), SENTIMENT_LABEL (POSITIVE above 0.3, NEGATIVE below -0.3, otherwise NEUTRAL) and TOPIC_CATEGORY from AI_CLASSIFY into one of: Performance Issue, Service Quality, Technical Problem, Positive Experience, Feature Request. Then show average sentiment and % negative by PAYMENT_TYPE.
```
Expect: about 2,000 scored rows, every one with a topic. Score once, query many times.
Check: da2_enriched

### Find churn risk in plain English
```prompt
Use AI_FILTER on FEEDBACK_ENRICHED to find negative feedback that mentions a risk of the client moving their business elsewhere. Show customer, payment type and the first 120 characters of the feedback.
```
Expect: a short list of at-risk clients, found by meaning rather than keywords

### Summarise complaint themes per RM
```prompt
Create a table BARCLAYS_HOL.ANALYTICS.RM_FEEDBACK_THEMES with one row per RM_NAME from the NEGATIVE rows of FEEDBACK_ENRICHED: NEGATIVE_FEEDBACK (count) and TOP_THEMES using AI_AGG with the instruction "You are briefing a corporate banking relationship manager. List the top 3 recurring complaint themes in this client feedback, each with a one-line recommended action. Be concise."
```
Expect: one row per RM with three themes and actions
Check: da2_rm_themes

### Draft a client reply
```prompt
Use AI_COMPLETE to draft a short, professional reply from a UK corporate bank to the most negative item in FEEDBACK_ENRICHED: acknowledge the issue, avoid admitting liability and offer a follow-up call.
```
Expect: a client-ready draft for a human to review

### Go further
```prompt
Using FEEDBACK_ENRICHED, show me which customer sectors have worsening sentiment month over month and chart it.
```
Expect: a month-by-sector trend and a chart in the sidebar

## Check your work
`RM_FEEDBACK_THEMES` has one row per RM with three themes and actions.

## Barclayflake note
AI functions run inside Snowflake's security boundary - no data leaves the platform and nothing is vectorised or stored by the model.
