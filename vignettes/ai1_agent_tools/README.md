# AI1: Agent with custom tools

| | |
|---|---|
| **Persona** | AI Builder |
| **Time** | ~45 min |
| **Prerequisites** | `core_analytics.sql`, `semantic_view_and_agent.sql` |
| **Reference SQL** | [`ai1.sql`](ai1.sql) |

## Business question
> Ops staff ask about specific payments by ID and about scheme rules - not just aggregates. Give the agent precise tools.

## What you'll build
- UDF tools `PAYMENT_LOOKUP`, `SCHEME_RULES`
- Agent `BARCLAYS_HOL.AGENTS.PAYMENTS_INVESTIGATOR`

## Steps
### Set your context
Where: payments-hol Workspace > **+ > SQL file**
```sql
USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.AGENTS;
```

### Build the payment lookup tool
Where: the Cortex Code sidebar
Deterministic tools keep exact lookups exact: no text-to-SQL guessing.
```prompt
In BARCLAYS_HOL.AGENTS create a SQL table function GET_PAYMENT_DETAILS(PAYMENT_ID_IN VARCHAR) that returns one payment from BARCLAYS_HOL.ANALYTICS.STG_PAYMENTS (matching UPPER(TRIM(PAYMENT_ID_IN))) with its date, type, amount, currency, status, processing time, error code, error description and IS_RETRYABLE (from RAW_DATA.ERROR_CODES), customer name and RM name (via STG_ACCOUNTS and STG_CUSTOMERS), and its count of open alerts. Agent tools need a scalar return, so also create PAYMENT_LOOKUP(PAYMENT_ID VARCHAR) RETURNS VARIANT that returns that row as a JSON object, or {"error": "No payment found with ID ..."}. Test it on the first FAILED payment.
```
Expect: a JSON object for one failed payment, including its error and retryability

### Build the scheme rules tool
```prompt
In BARCLAYS_HOL.AGENTS create SCHEME_RULES(SCHEME VARCHAR) RETURNS VARIANT: look up BARCLAYS_HOL.RAW_DATA.PAYMENT_SCHEMES by SCHEME_CODE (UPPER, spaces replaced by underscores) joined to SLA_DEFINITIONS on PAYMENT_TYPE, and return a JSON object with scheme, name, settlement_cycle, domestic, max_value_gbp, cutoff_time_uk (CUTOFF_TIME as a string), currency, sla_target_success_rate and sla_max_p95_ms. For unknown schemes return an error listing the valid ones. Test it with 'chaps'.
```
Expect: CHAPS rules with `cutoff_time_uk` of `15:45:00`
Check: ai1_tool

### Create the agent with Cortex Code
Where: payments-hol Workspace > **+ > Agent** > **Create with CoCo** (recommended)
Name the new agent file `payments_investigator` straight away, then paste this brief.
```prompt
Create a Cortex Agent BARCLAYS_HOL.AGENTS.PAYMENTS_INVESTIGATOR with display name "Payments Investigator". Tools: a generic function tool PaymentLookup on BARCLAYS_HOL.AGENTS.PAYMENT_LOOKUP (input payment_id string), a generic function tool SchemeRules on BARCLAYS_HOL.AGENTS.SCHEME_RULES (input scheme string), and a Cortex Analyst tool PaymentsOps on BARCLAYS_HOL.ANALYTICS.SV_PAYMENTS, all on warehouse BARCLAYS_WH. Orchestration: for a specific payment ID call PaymentLookup; for a scheme's cutoff, limit, settlement cycle or SLA call SchemeRules; use PaymentsOps for aggregate KPI questions. Deploy it.
```
Expect: `PAYMENTS_INVESTIGATOR` deployed in `BARCLAYS_HOL.AGENTS`
Check: ai1_agent

### Test it on a real payment
Where: Snowsight > **AI & ML > Agents > PAYMENTS_INVESTIGATOR** > Playground
```prompt
Give me the ID of one failed CHAPS payment from BARCLAYS_HOL.RAW_DATA.PAYMENTS.
```
Expect: a payment ID. Ask the agent "What happened to payment <ID>, can it be retried, and can I still send a CHAPS payment today?". It should call `PaymentLookup`, then `SchemeRules`, and report retryability and the 15:45 cutoff.

### Go further
Where: the Cortex Code sidebar
```prompt
Add a third tool to PAYMENTS_INVESTIGATOR that lists open alerts for a customer name, using a new UDF in BARCLAYS_HOL.AGENTS. Redeploy the agent and test it.
```
Expect: the agent answers "What open alerts does <client> have?" with the new tool

## Check your work
Asking about a failed CHAPS payment calls `PaymentLookup` then `SchemeRules` and reports retryability and the 15:45 cutoff.

## Barclayflake note
Deterministic tools for lookups keep answers exact and auditable; text-to-SQL is reserved for analytical questions.
