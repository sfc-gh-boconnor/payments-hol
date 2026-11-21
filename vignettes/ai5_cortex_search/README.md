# AI5: Cortex Search over call transcripts and case notes

| | |
|---|---|
| **Persona** | AI Builder |
| **Time** | ~25 min |
| **Optional** | Cortex Search is not yet approved at Barclays. This module shows what it would unlock: skip it if your account doesn't allow it (the prerequisite check below tells you). |
| **Prerequisites** | AI4 recommended. Needs the `BARCLAYS_HOL.SEARCH_LAB` schema from `setup/10b_search_lab.sql` |

## Business question
> Can a complaints handler or fraud investigator find "every call like this one" in plain English, instead of keyword searches and spreadsheets?

## What you'll build
- Cortex Search service `SEARCH_LAB.RB_CALL_SEARCH` over all 1,000 call transcripts, filterable by queue, topic and whether the customer left
- Cortex Search service `SEARCH_LAB.RB_FINCRIME_SEARCH` over fraud case notes and SAR narratives
- Plain-English searches with filters, and a comparison with AI4's AI SQL approach

## Steps
### Open Cortex Code
Where: the **CoCo** tab, in your AI4 session or a **New session**
1. Switch the toggle at the top left from **Home** to **CoCo**.
2. Press **New session** if you aren't carrying on from AI4.
**Important:** Cortex Search is not approved at Barclays yet. Everything here is a preview of what approval would add on top of the approved AI SQL in AI4.
Expect: the Cortex Code screen with a **How can I help?** box

### Create a search service over call transcripts
```prompt
Create a Cortex Search service BARCLAYS_HOL.SEARCH_LAB.RB_CALL_SEARCH on the TRANSCRIPT column of BARCLAYS_HOL.RAW_DATA.RB_CALL_TRANSCRIPTS, joined to RB_CUSTOMERS so it carries CHURNED as 'yes' or 'no'. Return CALL_ID, CUSTOMER_ID, CALL_START_TS, QUEUE, TOPIC and CHURNED, make QUEUE, TOPIC and CHURNED filterable attributes, use warehouse BARCLAYS_WH and a target lag of 1 day. Then show the service.
```
**Tip:** the service indexes the text itself and keeps itself up to date. There's no embedding pipeline to build.
Expect: the service is created and shows as active after a minute or two
Check: ai5_search_service

### Search in plain English
```prompt
Use SNOWFLAKE.CORTEX.SEARCH_PREVIEW on RB_CALL_SEARCH to find the 5 calls most like "customer upset that their local branch is closing and they can't use the app", then the 5 most like "caller told to move money to a safe account" filtered to the FRAUD queue. Show CALL_ID, CUSTOMER_ID, the topic and whether they left.
```
Expect: the first search returns retention calls from customers who left, and the second returns fraud reports. The words in your query don't have to appear in the transcript.

### Search the financial crime narratives
```prompt
Create a second Cortex Search service BARCLAYS_HOL.SEARCH_LAB.RB_FINCRIME_SEARCH over fraud case investigator notes (RB_FRAUD_CASES) and SAR narratives (RB_SAR_NARRATIVES) together, with a DOC_TYPE attribute (FRAUD_CASE or SAR) and FRAUD_TYPE. Then search it for "money mule receiving funds and moving them on within minutes" and show the top 5 with their document type and customer.
```
Expect: SAR narratives and account takeover cases describing funds moved on quickly to new payees

### Compare search with AI SQL
```prompt
Compare Cortex Search with the approved AI SQL approach from AI4, on the same call transcripts in BARCLAYS_HOL.RAW_DATA.RB_CALL_TRANSCRIPTS. In AI4, AI_SENTIMENT and AI_CLASSIFY labelled each transcript into BARCLAYS_HOL.ANALYTICS.RB_CALL_INSIGHTS (columns SENTIMENT, CALL_REASON, VULNERABILITY_CUES), and AI_AGG summarised groups of transcripts in one paragraph. If RB_CALL_INSIGHTS doesn't exist (AI4 was skipped), don't build it: run AI_CLASSIFY on 20 transcripts instead. Answer one question both ways, "customers worried about savings rates who might leave": first with RB_CALL_SEARCH, then with AI_CLASSIFY or the RB_CALL_INSIGHTS labels plus AI_AGG over those calls. Show both results side by side, then explain when a search service is the right tool, when AI SQL is enough, and how an agent would use RB_CALL_SEARCH as a tool.
```
**Tip:** Search returns the most relevant calls in a second, without reading every row. AI SQL reads and labels every row, so it can count and summarise them all.
Expect: search finds the closest-matching calls to a plain-English question and can ground an agent; AI SQL labels, counts and summarises every call in a table

## Check your work
Your Cortex Search service over call transcripts exists in `BARCLAYS_HOL.SEARCH_LAB`.

## Barclayflake note
Until Cortex Search is approved, AI4's AI SQL covers the scoring and summarising, and AI3's knowledge extension covers documentation search. This module is the business case for approving it: plain-English retrieval over the bank's own documents, governed in the same account.
