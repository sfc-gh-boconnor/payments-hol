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
- Notebook `da2_feedback_analysis` with the whole analysis and a sentiment-by-sector chart

## Steps
### Open the DA2 starter notebook
Where: the **payments-hol** Workspace (not My Workspace) > file explorer > `notebooks/da2_feedback_analysis.ipynb`
Open the starter notebook `da2_feedback_analysis`: it has the title and one numbered heading per step, so Cortex Code puts each cell in the right place. If you can't see the `notebooks/` and `vignettes/` folders in the file explorer, you're in the wrong Workspace: switch to **payments-hol** from the Workspace dropdown (top left) before you go on. (No starter? Use **+ > Notebook** in payments-hol and name it `da2_feedback_analysis`.) When it asks for compute, choose the compute pool **NOTEBOOK_POOL** and the warehouse **BARCLAYS_WH** (SQL cells run on the warehouse; Python and charts run on the pool). The first start can take a minute or two while the pool resumes. You'll build this whole module as cells in this notebook: Cortex Code adds them for you, and you run each one.
Expect: the starter notebook open in payments-hol, with its numbered headings and a connected kernel

### Score sentiment by aspect
Where: the Cortex Code sidebar, with `da2_feedback_analysis` open
```prompt
In the open notebook da2_feedback_analysis, put each cell I ask for under its matching numbered heading. Under heading 1, add a SQL cell named aspect_sentiment that uses AI_SENTIMENT to score 5 rows of FEEDBACK_TEXT from BARCLAYS_HOL.ANALYTICS.STG_FEEDBACK overall and for the aspects speed, communication and fees. Run it and explain the output.
```
Expect: the cell's result shows an overall sentiment plus a separate one for each aspect (positive, negative, neutral, mixed or unknown)

### Enrich all feedback once
```prompt
Add a SQL cell named enrich that creates the table BARCLAYS_HOL.ANALYTICS.FEEDBACK_ENRICHED from STG_FEEDBACK left-joined to STG_CUSTOMERS. Keep the feedback columns plus CUSTOMER_NAME, CUSTOMER_SECTOR and RM_NAME. Add SENTIMENT_SCORE from AI_SENTIMENT's overall sentiment (positive = 1, negative = -1, neutral or mixed = 0; don't use the legacy SNOWFLAKE.CORTEX.SENTIMENT, which is blocked on new accounts), SENTIMENT_LABEL (POSITIVE above 0.3, NEGATIVE below -0.3, otherwise NEUTRAL) and TOPIC_CATEGORY from AI_CLASSIFY into one of: Performance Issue, Service Quality, Technical Problem, Positive Experience, Feature Request. Then add a SQL cell named by_scheme showing average sentiment and % negative by PAYMENT_TYPE, and run both.
```
Expect: about 2,000 scored rows, every one with a topic, and a per-scheme summary. Score once, query many times.
Check: da2_enriched

### Find churn risk in plain English
```prompt
Add a SQL cell named churn_risk that uses AI_FILTER on BARCLAYS_HOL.ANALYTICS.FEEDBACK_ENRICHED with exactly this question: 'Does the client in this feedback explicitly state that they will or may leave the bank, move their business to another bank, review other banking providers, or tender their banking? Complaints without a stated intention to leave do not count. Feedback: {0}'. Show customer, payment type and the first 120 characters of the feedback, grouped by distinct feedback text with a count. Run it.
```
Expect: a short list - three distinct churn statements (reviewing other providers, moving to another bank, tendering their banking) - found by meaning rather than keywords. Ordinary complaints about delays or outages are left out. That's the difference between AI_FILTER and a sentiment score. They all come from Logistics clients, which the next step explains

### Chart sentiment by sector
```prompt
Add a SQL cell named sector_trend with one row per complete month and customer sector from BARCLAYS_HOL.ANALYTICS.FEEDBACK_ENRICHED: MONTH, CUSTOMER_SECTOR, AVG_SENTIMENT and FEEDBACK_COUNT, excluding the current partial month. Then add a Python cell that plots sector_trend as an altair line chart (MONTH on x, AVG_SENTIMENT on y, one line per CUSTOMER_SECTOR, tooltip with the count). Run both and tell me which sectors are getting worse.
```
Expect: a line chart under the Python cell, one line per sector. Logistics falls clearly over the last four months (the same clients who talk about leaving), while Pharmaceuticals improves; other sectors move around without a trend. Hover over a point to see its feedback count.

### Summarise complaint themes per RM
```prompt
Add a SQL cell named rm_themes that creates the table BARCLAYS_HOL.ANALYTICS.RM_FEEDBACK_THEMES with one row per RM_NAME from the NEGATIVE rows of FEEDBACK_ENRICHED: NEGATIVE_FEEDBACK (count) and TOP_THEMES using AI_AGG with the instruction "You are briefing a corporate banking relationship manager. List the top 3 recurring complaint themes in this client feedback, each with a one-line recommended action. Be concise." Run it and show the results.
```
Expect: one row per RM with three themes and actions
Check: da2_rm_themes

### Draft a client reply
```prompt
Add a SQL cell named draft_reply that uses AI_COMPLETE to draft a short, professional reply from a UK corporate bank to the most negative item in FEEDBACK_ENRICHED: acknowledge the issue, avoid admitting liability and offer a follow-up call. Run it.
```
Expect: a client-ready draft for a human to review. The notebook is now a complete, re-runnable analysis you could share or schedule.

## Check your work
`RM_FEEDBACK_THEMES` has one row per RM with three themes and actions.

## Barclayflake note
AI functions run inside Snowflake's security boundary - no data leaves the platform and nothing is vectorised or stored by the model.
