# Retail text and financial crime evidence (synthetic)

Unstructured data for the retail banking data product, for AI4 (AI SQL) and AI5 (Cortex Search, optional). Built by `setup/tools/build_retail_text.py` and loaded by `setup/10_retail_text_seed.sql` as Iceberg tables in `BARCLAYS_HOL.RAW_DATA`, with the files on `@BARCLAYS_HOL.RETAIL.FINCRIME_EVIDENCE`.

**Everything is synthetic training data.** The people are the synthetic customers in `data/retail_bank`, the bank is only ever "the bank", and the evidence files are watermarked "SYNTHETIC - TRAINING DATA".

| File | Table | Rows |
| --- | --- | --- |
| `rb_call_transcripts.csv.gz` | `RB_CALL_TRANSCRIPTS` | 1,000 |
| `rb_emails.csv.gz` | `RB_EMAILS` | 300 |
| `rb_complaints.csv.gz` | `RB_COMPLAINTS` | 200 |
| `rb_fraud_cases.csv.gz` | `RB_FRAUD_CASES` | 300 |
| `rb_sar_narratives.csv.gz` | `RB_SAR_NARRATIVES` | 60 |
| `rb_disputes.csv.gz` | `RB_DISPUTES` | 120 |
| `rb_evidence_files.csv.gz` | `RB_EVIDENCE_FILES` | 150 |
| `evidence/` | files on `@RETAIL.FINCRIME_EVIDENCE` | 150 (1.8 MB) |

## How it links to the retail customers
- Every row carries a `CUSTOMER_ID` from `RB_CUSTOMERS`.
- Fraud calls, fraud cases and disputes carry the `TXN_ID` of the actual transaction in `RB_TRANSACTIONS`.
- Topics follow each customer's records:
  - **Leavers:** 250 retention calls in the 2 to 10 weeks before `CHURN_DATE`, about their real reason (`CHURN_REASON`): a legacy saver's actual rate and balance, their branch, their complaints.
  - **Fraud victims:** 200 calls hours after their first fraud transaction, quoting the real amounts and payees.
  - **Stretched customers:** 150 calls about repayments, using their net pay.
  - **Everyday calls:** 400 about maturing fixed rates, lost cards, app logins, overpayments and late salary from their employer.
- Emails and complaints follow the same stories a few days later. Fraud cases quote every fraud transaction, with a decision.

## Dates and times
- **Calls:** `CALL_START_TS` and `CALL_END_TS`, in contact-centre hours (08:00 to 20:00). Each transcript opens with a header line: call ID, date, start and end time, queue and agent.
- **Everything else:** `RECEIVED_TS`, `REPORTED_TS`, `FILED_TS`, `OPENED_TS` and `EVIDENCE_DATE`, consistent with the story: phishing texts arrive before the fraud, police reports the day after the report.

## How the text was written
1. A facts sheet per record is built from the RB tables (`python build_retail_text.py facts`).
2. `AI_COMPLETE` (claude-sonnet-4-5) writes the wording once in a facilitator account (`generate`). The raw output is kept in `_generated.csv.gz`, so `tables` rebuilds without calling the model again.
3. Evidence files are drawn from the facts with Pillow and reportlab (`evidence`), with no AI involved, so every detail is checkable.
4. `validate` checks that:
   - every link resolves to RB_CUSTOMERS or RB_TRANSACTIONS, and every fraud case is on a transaction labelled fraud;
   - retention calls come before the customer leaves, and fraud calls after the fraud;
   - the text names the right customer;
   - there are no real bank names, account, sort code or card numbers, phone numbers, email addresses, invented postcodes or spoken dates of birth (any that slip through are scrubbed).

## Evidence files
| Type | Files | Linked to |
| --- | --- | --- |
| Phishing text screenshots (PNG) | 40 | fraud case (APP scam, account takeover) |
| Police report confirmations (PDF) | 50 | fraud case, with crime reference and loss |
| Booking confirmations (PNG) | 31 | card dispute, travel merchants only |
| Refund policy screenshots (PNG) | 16 | card dispute |
| Damaged goods illustrations (PNG) | 13 | card dispute |

Police report PDFs are clearly marked as not real police documents. Phishing lures use invented brands and domains.
