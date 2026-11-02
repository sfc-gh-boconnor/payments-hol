# Data Model & Layers

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                        CONSUMPTION LAYER                             │
│                                                                      │
│  Streamlit Dashboard    Semantic Views / CoWork    Dynamic Tables     │
│  (payments-dashboard)   (SV_PAYMENTS_BARCLAYS)    (DT_NEGATIVE_...)  │
└──────────────┬──────────────────┬──────────────────────┬─────────────┘
               │                  │                      │
┌──────────────┴──────────────────┴──────────────────────┴─────────────┐
│                         ANALYTICS LAYER                              │
│                     BARCLAYS_HOL.ANALYTICS                           │
│                                                                      │
│  Views (built by dbt)                                                │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐            │
│  │ V_PAYMENTS_    │ │ V_CUSTOMER_    │ │ FEEDBACK_      │            │
│  │ ANALYSIS       │ │ ANALYSIS       │ │ ENRICHED       │            │
│  └───────┬────────┘ └───────┬────────┘ └───────┬────────┘            │
│          │                  │              (Cortex AI)                │
│  Mart Tables (built by dbt)                                          │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐            │
│  │ MART_PAYMENT_  │ │ MART_SLA_      │ │ MART_CUSTOMER_ │            │
│  │ KPIS           │ │ COMPLIANCE     │ │ PAYMENTS *     │            │
│  └───────┬────────┘ └───────┬────────┘ └───────┬────────┘            │
│          │                  │                  │                      │
│  ┌────────────────┐                     ┌────────────────┐           │
│  │ MART_RM_       │                     │                │           │
│  │ PERFORMANCE *  │                     │                │           │
│  └───────┬────────┘                     │                │           │
│          │                              │                │           │
│  Staging Views (built by dbt)           │                │           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐                │
│  │stg_      │ │stg_      │ │stg_      │ │stg_      │                │
│  │payments  │ │feedback  │ │customers │ │accounts  │                │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘                │
└───────┼─────────────┼────────────┼─────────────┼─────────────────────┘
        │             │            │             │
┌───────┴─────────────┴────────────┴─────────────┴─────────────────────┐
│                          RAW DATA LAYER                              │
│                      BARCLAYS_HOL.RAW_DATA                           │
│                                                                      │
│  PAYMENTS  CUSTOMER_FEEDBACK  CUSTOMERS  ACCOUNTS                    │
│  RELATIONSHIP_MANAGERS  PAYMENT_SCHEMES  ERROR_CODES                 │
│  SLA_DEFINITIONS  OPERATIONAL_ALERTS                                 │
└──────────────────────────────────────────────────────────────────────┘

│  MARKETPLACE DATA (external)                                         │
│  SNOWFLAKE_PUBLIC_DATA_FOREIGN_EXCHANGE_RATES.PUBLIC_DATA             │
│  └── FX_RATES_TIMESERIES                                             │
└──────────────────────────────────────────────────────────────────────┘

* Built by participants using Cortex Code in Step 3b
```

## Layers

### Raw Data (`BARCLAYS_HOL.RAW_DATA`)

Source tables loaded in Step 2. No transformations — this is the data as it arrives from source systems. See [data_sources.md](data_sources.md) for the full ERD, source system inventory, and column dictionary.

| Table | Rows | Source system |
|---|---|---|
| PAYMENTS | 50,000 | Payments processing engine |
| CUSTOMER_FEEDBACK | 2,000 | CRM / feedback platform |
| OPERATIONAL_ALERTS | 1,500 | Monitoring platform |
| ACCOUNTS | 36 | Core banking / account ledger |
| CUSTOMERS | 30 | Core banking / KYC system |
| ERROR_CODES | 20 | Payments gateway |
| RELATIONSHIP_MANAGERS | 10 | HR / CRM |
| PAYMENT_SCHEMES | 6 | Payments product config |
| SLA_DEFINITIONS | 6 | Service management |

### Staging (`BARCLAYS_HOL.ANALYTICS` — dbt views)

Staging models clean, cast, and denormalise raw data. Materialised as **views** so they always reflect the latest raw data with no refresh lag.

| Model | What it does | Sources |
|---|---|---|
| `stg_payments` | Type casts, adds `IS_SUCCESSFUL` / `IS_FAILED` / `HAS_ERROR` flags, derives `PAYMENT_DAY` | PAYMENTS |
| `stg_feedback` | Filters empty text, adds `SATISFACTION_TIER` from rating | CUSTOMER_FEEDBACK |
| `stg_customers` | Denormalises RM_NAME, RM_TEAM, RM_REGION from RELATIONSHIP_MANAGERS into each customer row | CUSTOMERS + RELATIONSHIP_MANAGERS |
| `stg_accounts` | Denormalises CUSTOMER_NAME, CUSTOMER_SECTOR from CUSTOMERS into each account row | ACCOUNTS + CUSTOMERS |

### Marts (`BARCLAYS_HOL.ANALYTICS` — dbt tables)

Mart models aggregate and join staging models into business-ready datasets. Materialised as **tables** for query performance.

#### Pre-built (Step 3a walkthrough)

**`mart_payment_kpis`** — Daily payment KPIs

| Aspect | Detail |
|---|---|
| Grain | One row per day × payment type × region × channel × customer sector × RM |
| Join chain | stg_payments → stg_accounts → stg_customers |
| Key metrics | TOTAL_PAYMENTS, TOTAL_VOLUME_GBP, SUCCESS_RATE_PCT, AVG_PROCESSING_TIME_MS, P95_PROCESSING_TIME_MS |
| Dimensions | PAYMENT_DAY, PAYMENT_TYPE, REGION, CHANNEL, CUSTOMER_SECTOR, RM_NAME, RM_TEAM |

**`mart_sla_compliance`** — Daily SLA compliance per scheme

| Aspect | Detail |
|---|---|
| Grain | One row per day × payment type |
| Join chain | mart_payment_kpis (reaggregated to day × type) → SLA_DEFINITIONS |
| Key metrics | ACTUAL_SUCCESS_RATE, ACTUAL_P95_MS, RATE_GAP_PCT, TIME_GAP_MS |
| Business logic | Compares actuals against SLA thresholds → SLA_STATUS (COMPLIANT / AT RISK / BREACH) |

#### CoCo-built (Step 3b — participants prompt Cortex Code)

**`mart_customer_payments`** — Customer-level payment summary

| Aspect | Detail |
|---|---|
| Grain | One row per customer |
| Join chain | stg_payments → stg_accounts → stg_customers |
| Expected metrics | Total volume, success rate, most-used scheme |
| Prompt | *"Build a dbt mart that summarises payment activity per customer, including total volume, success rate, and their most-used payment scheme"* |

**`mart_rm_performance`** — RM portfolio performance

| Aspect | Detail |
|---|---|
| Grain | One row per relationship manager |
| Join chain | stg_payments → stg_accounts → stg_customers (RM denormalised) |
| Expected metrics | Client count, total volume, average success rate, weakest client |
| Prompt | *"Build a dbt mart showing each relationship manager's portfolio — number of clients, total payment volume, average success rate, and their client with the lowest success rate"* |

### AI Enrichment (`BARCLAYS_HOL.ANALYTICS` — Step 4)

**`FEEDBACK_ENRICHED`** — Customer feedback enriched with Cortex AI

| Aspect | Detail |
|---|---|
| Source | stg_feedback + stg_customers |
| AI functions | `SENTIMENT()` → SENTIMENT_SCORE + SENTIMENT_LABEL; `CLASSIFY_TEXT()` → TOPIC_CATEGORY + CLASSIFICATION_CONFIDENCE |
| Denormalised | CUSTOMER_NAME, CUSTOMER_SECTOR, RM_NAME from stg_customers |

### Dynamic Tables (`BARCLAYS_HOL.ANALYTICS` — Step 4)

Auto-refreshing views for operational monitoring. No orchestration — Snowflake handles refresh.

| Dynamic Table | Source | Refresh | Purpose |
|---|---|---|---|
| `DT_NEGATIVE_SENTIMENT_FEED` | FEEDBACK_ENRICHED | Downstream | Negative feedback triage for CX ops |
| `DT_SENTIMENT_OPS_SUMMARY` | FEEDBACK_ENRICHED | Downstream | Sentiment summary by payment type |
| `DT_LIVE_SLA_BREACHES` | MART_SLA_COMPLIANCE | 1 minute | Live breach volume per scheme |

### Analytics Views (`BARCLAYS_HOL.ANALYTICS` — Step 5)

Stable interfaces for Semantic Views and Cortex Analyst.

| View | Source | Purpose |
|---|---|---|
| `V_PAYMENTS_ANALYSIS` | MART_PAYMENT_KPIS | Payments-focused Semantic View (time, scheme, region dimensions) |
| `V_CUSTOMER_ANALYSIS` | stg_payments + stg_accounts + stg_customers | Customer-focused Semantic View (customer, sector, RM dimensions) |

### Marketplace Data (Step 2.8)

External dataset installed from the Snowflake Marketplace. Joins to PAYMENTS on currency + date.

| Object | Database | Schema | Purpose |
|---|---|---|---|
| `FX_RATES_TIMESERIES` | SNOWFLAKE_PUBLIC_DATA_FOREIGN_EXCHANGE_RATES | PUBLIC_DATA | Real GBP/EUR and GBP/USD exchange rates — replaces synthetic FX_RATE on cross-currency payments |

## dbt Dependency Graph

```
sources (RAW_DATA)
  ├── payments ──────────► stg_payments ──┐
  ├── customer_feedback ─► stg_feedback   │
  ├── customers ─┬───────► stg_customers ─┤
  ├── relationship_managers ┘              │
  ├── accounts ──┬───────► stg_accounts ──┤
  ├── customers ─┘                        │
  │                                       ▼
  │                              mart_payment_kpis ──┐
  │                                       │          │
  │                                       ▼          │
  ├── sla_definitions ──────────► mart_sla_compliance│
  │                                                  │
  │  (CoCo-built)                                    │
  │  stg_payments ─┐                                 │
  │  stg_accounts ─┼────────► mart_customer_payments │
  │  stg_customers ┘                                 │
  │                                                  │
  │  stg_payments ─┐                                 │
  │  stg_accounts ─┼────────► mart_rm_performance    │
  │  stg_customers ┘                                 │
  └──────────────────────────────────────────────────┘
```

## Key Design Decisions

**Denormalised marts, not star schema.** Marts are wide, flat tables with dimensions baked in — not fact + dimension tables. This is simpler for a 90-minute lab, directly queryable in dashboards and Semantic Views, and avoids join complexity for participants.

**Staging views, mart tables.** Staging models are views (always fresh, no storage cost). Marts are tables (fast to query, pre-computed aggregates with PERCENTILE_CONT which can't be incrementally maintained).

**LEFT JOINs in mart_payment_kpis.** The join from payments → accounts → customers uses LEFT JOINs so payments from accounts not in our ACCOUNTS reference table (if any) still appear — they just have NULL sector/RM. This prevents silent data loss.

**SLA compliance reaggregates.** Since mart_payment_kpis has a finer grain (includes channel, sector, RM), mart_sla_compliance first rolls up to day × scheme before comparing against SLA thresholds. SLA targets are defined at the scheme level, not the customer level.

**CoCo marts are not pre-built.** `mart_customer_payments` and `mart_rm_performance` are absent from the repo. Participants prompt Cortex Code to generate them in Step 3b, demonstrating AI-assisted development. The schema.yml already defines their tests so `dbt test` works once CoCo creates them.
