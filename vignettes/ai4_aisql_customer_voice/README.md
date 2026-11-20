# AI4: AI SQL on the voice of the customer and financial crime evidence

| | |
|---|---|
| **Persona** | AI Builder |
| **Time** | ~40 min |
| **Prerequisites** | None. Uses the retail text and evidence in `BARCLAYS_HOL.RAW_DATA` and `@RETAIL.FINCRIME_EVIDENCE`, built at provisioning |

## Business question
> What are retail customers telling us on calls and in complaints before they leave, and can AI read a fraud case file (notes, phishing screenshots, police reports) so an investigator can decide faster?

## What you'll build
- Table `ANALYTICS.RB_CALL_INSIGHTS`: sentiment, call reason and vulnerability cues for recent calls, joined to who left
- Structured fields pulled out of complaints and police report PDFs with AI_EXTRACT
- A "why they left" summary from leavers' calls with AI_AGG
- Phishing screenshot analysis and a fraud case decision draft with AI_COMPLETE

## Steps
### Open Cortex Code
Where: the **CoCo** tab, **New session**
1. At the top left of Snowsight, switch the toggle from **Home** to **CoCo**.
2. Press **New session**.
3. Paste each prompt in this module into the **How can I help?** box, and **Allow** the queries.
**Tip:** every function in this module is an approved AI SQL function, governed by the account's AI gateway. Nothing leaves Snowflake.
Expect: the Cortex Code screen with a **How can I help?** box

### Meet the unstructured data
```prompt
Show me the unstructured retail data in BARCLAYS_HOL.RAW_DATA: RB_CALL_TRANSCRIPTS, RB_EMAILS, RB_COMPLAINTS, RB_FRAUD_CASES, RB_SAR_NARRATIVES, RB_DISPUTES and RB_EVIDENCE_FILES, plus the files on stage @BARCLAYS_HOL.RETAIL.FINCRIME_EVIDENCE. Give row counts, how each links to RB_CUSTOMERS and RB_TRANSACTIONS, and show one call transcript in full.
```
Expect: 1,000 call transcripts (each with start and end times), 300 emails, 200 complaints, 300 fraud cases, 60 SAR narratives, 120 disputes and 150 evidence files. Every row links to a retail customer, and fraud calls, cases and disputes link to the actual transaction.
**Tip:** the people and the text are synthetic, written to match each customer's records: leavers call before they leave, fraud victims call about their own fraud.

### Enrich call transcripts
```prompt
Create the table BARCLAYS_HOL.ANALYTICS.RB_CALL_INSIGHTS from the 300 most recent calls in RB_CALL_TRANSCRIPTS (since 1 Aug 2026), with AI_SENTIMENT's overall sentiment, a CALL_REASON from AI_CLASSIFY (savings rates, branch access, service complaint, fraud or scam, financial difficulty, card or app problem, product question, account admin), and VULNERABILITY_CUES from AI_CLASSIFY in multi-label mode (mentions health or disability, bereavement, money worries, none). Join RB_CUSTOMERS for CHURNED and AFFORDABILITY_BAND. Then show, by call reason, the call count, the share negative and the share of callers who later left.
```
**Tip:** score once into a table, then query it as often as you like. Re-running AI functions on the same text spends credits again.
Expect: about 300 enriched calls. Service complaints and savings-rate calls are the most negative, and those callers are the most likely to have left.
Check: ai4_call_insights

### Pull fields out of complaints
```prompt
For 10 complaints in RB_COMPLAINTS, use AI_EXTRACT to pull out the product, any amount in pounds and the customer's requested outcome, as columns next to CATEGORY and STATUS.
```
Expect: one row per complaint with product, amount and requested outcome filled in from the free text

### Find out why customers left
```prompt
Use AI_AGG over every call transcript from customers who churned, in the 3 months before their CHURN_DATE, to list the top 5 reasons they gave, how often each came up, and one action the bank could take for each.
```
Expect: one summary naming reasons such as low savings rates, branch closures, unresolved complaints and switching offers, each with an action

### Read the fraud evidence
```prompt
Using RB_EVIDENCE_FILES and the stage @BARCLAYS_HOL.RETAIL.FINCRIME_EVIDENCE: for 5 police report PDFs, use AI_EXTRACT with TO_FILE to pull the crime reference number, date reported and amount lost, and compare the amount with LOSS_GBP in RB_FRAUD_CASES. Then for 3 phishing screenshots, use AI_COMPLETE with the image to say which organisation the message impersonates and list its red flags.
```
Expect: crime references starting NFRC, amounts that match the case losses, and screenshots identified as fake parcel-delivery, HMRC refund or bank "new payee" messages, each with red flags such as a lookalike web address
Check: ai4_evidence_read

### Draft a fraud case decision
```prompt
For one APP scam case in RB_FRAUD_CASES, combine the investigator notes, the customer's fraud call transcript and the recorded decision, and use AI_COMPLETE to draft a 150-word case summary with a reimbursement recommendation that cites the evidence. Then use AI_CLASSIFY to check 10 SAR narratives in RB_SAR_NARRATIVES against a simple standard: complete, missing the reason for suspicion, missing dates or amounts, or missing the action taken.
```
**Important:** AI drafts, people decide. The investigator still owns the reimbursement decision and the SAR.
Expect: a decision draft that quotes the amounts and dates from the case, and a quality label for each SAR narrative

## Check your work
The call insights table exists, and you have read the financial crime evidence with AI SQL.

## Barclayflake note
At Barclays, AI SQL functions are approved and run through the AI gateway, so this is work a fraud or complaints team could do today. Search over these documents is the next step (AI5, optional, as Cortex Search isn't approved yet).
