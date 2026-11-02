# Data Sources & Model Documentation

## Entity-Relationship Diagram

```
┌─────────────────────┐
│ RELATIONSHIP_MANAGERS│
│─────────────────────│
│ PK: RM_ID           │
│    RM_NAME           │
│    RM_EMAIL          │
│    TEAM              │
│    REGION            │
│    START_DATE        │
└────────┬────────────┘
         │ 1
         │
         │ M
┌────────┴────────────┐        ┌──────────────────────┐
│ CUSTOMERS            │        │ PAYMENT_SCHEMES      │
│──────────────────────│        │──────────────────────│
│ PK: CUSTOMER_ID      │        │ PK: SCHEME_CODE      │
│ FK: RM_ID            │        │    SCHEME_NAME        │
│    CUSTOMER_NAME     │        │    SETTLEMENT_CYCLE   │
│    SECTOR            │        │    IS_DOMESTIC        │
│    COUNTRY           │        │    MAX_VALUE_GBP      │
│    ONBOARDING_DATE   │        │    CUTOFF_TIME        │
│    KYC_STATUS        │        │    OPERATING_CURRENCY │
└───┬──────────┬──────┘        └──────────┬───────────┘
    │ 1        │ 1                        │ 1
    │          │                          │
    │ M        │ M                        │ M
┌───┴──────┐  ┌┴──────────────────────────┴────────────────────┐
│ ACCOUNTS │  │ CUSTOMER_FEEDBACK         │ PAYMENTS            │
│──────────│  │───────────────────        │─────────────────────│
│PK:ACCT_ID│  │ PK: FEEDBACK_ID          │ PK: PAYMENT_ID      │
│FK:CUST_ID│  │ FK: CUSTOMER_ID          │ FK: ORIG_ACCOUNT_ID │◄──┐
│  SORT_CODE│  │ FK: PAYMENT_ID (opt)     │ FK: BENE_ACCOUNT_ID │◄──┤
│  ACCT_NUM │  │    FEEDBACK_DATE         │ FK: PAYMENT_TYPE    │   │
│  IBAN     │  │    FEEDBACK_CHANNEL      │ FK: ERROR_CODE(opt) │   │
│  BIC      │  │    FEEDBACK_TEXT         │    PAYMENT_DATE     │   │
│  CURRENCY │  │    PAYMENT_TYPE          │    CHANNEL          │   │
│  ACCT_TYPE│  │    RATING                │    CURRENCY         │   │
│  STATUS   │  │                          │    AMOUNT           │   │
│  OPENED   │  └──────────────────────────│    FX_RATE          │   │
└───┬───────┘                             │    STATUS           │   │
    │ 1                                   │    PROCESSING_MS    │   │
    │                                     │    REGION           │   │
    │ M (originator or beneficiary)       │    SETTLEMENT_DATE  │   │
    └─────────────────────────────────────┘                     │   │
                                           │                    │   │
              ┌────────────────────────────┘                    │   │
              │ 1                                               │   │
              │ M (optional)                          ACCOUNTS ─┘   │
    ┌─────────┴───────────┐                           (via FKs)     │
    │ OPERATIONAL_ALERTS   │                                        │
    │──────────────────────│        ┌──────────────────────┐        │
    │ PK: ALERT_ID         │        │ ERROR_CODES          │        │
    │ FK: PAYMENT_ID (opt) │        │──────────────────────│        │
    │    ALERT_TIME        │        │ PK: ERROR_CODE       │────────┘
    │    SEVERITY          │        │    ERROR_DESCRIPTION  │  1:M (nullable)
    │    PAYMENT_TYPE      │        │    ERROR_CATEGORY     │
    │    ALERT_DESCRIPTION │        │    IS_RETRYABLE       │
    │    STATUS            │        └──────────────────────┘
    │    ASSIGNED_TO       │
    │    RESOLUTION_TIME   │        ┌──────────────────────┐
    └──────────────────────┘        │ SLA_DEFINITIONS      │
                                    │──────────────────────│
                                    │ PK: SLA_ID           │
                                    │ FK: PAYMENT_TYPE     │
                                    │    SLA_NAME          │
                                    │    MAX_PROC_TIME_MS  │
                                    │    TARGET_SUCCESS_RT │
                                    │    MEASUREMENT_WINDOW│
                                    └──────────────────────┘
```

## Source System Inventory

| Table | Source System | Refresh Cadence | Data Owner | Description |
|---|---|---|---|---|
| RELATIONSHIP_MANAGERS | HR / CRM (Salesforce) | Event-driven (staff changes) | HR Operations | Relationship managers assigned to corporate clients |
| CUSTOMERS | Core Banking / KYC System (FIS Profile) | Daily | Client Onboarding | Corporate client entities with KYC and sector classification |
| ACCOUNTS | Core Banking / Account Ledger | Real-time (event-driven) | Account Services | Bank accounts: domestic (sort code) and international (IBAN/BIC) |
| PAYMENT_SCHEMES | Payments Product Configuration | On change (infrequent) | Payments Product | Scheme properties: settlement cycles, value limits, cutoffs |
| ERROR_CODES | Payments Gateway / Middleware | On change (infrequent) | Payments Engineering | Error code catalog with categories and retry eligibility |
| PAYMENTS | Payments Processing Engine | Real-time / micro-batch | Payments Operations | Core transaction fact table (50,000 synthetic rows) |
| CUSTOMER_FEEDBACK | CRM / Feedback Platform (Qualtrics) | Hourly | Customer Experience | Customer feedback submissions across all channels |
| SLA_DEFINITIONS | Service Management / SLA Register | Quarterly (contract reviews) | Payments Operations | Contractual SLA thresholds per payment scheme |
| OPERATIONAL_ALERTS | Monitoring Platform (Splunk/Dynatrace) | Real-time | Payments Operations | Operational alerts from payments monitoring |

## Key Relationships

| Relationship | Cardinality | Join Key | Notes |
|---|---|---|---|
| RELATIONSHIP_MANAGERS → CUSTOMERS | 1:M | RM_ID | One RM manages multiple clients |
| CUSTOMERS → ACCOUNTS | 1:M | CUSTOMER_ID | Each customer has 1–3 accounts |
| ACCOUNTS → PAYMENTS (originator) | 1:M | ORIGINATOR_ACCOUNT_ID | Account that initiates the payment |
| ACCOUNTS → PAYMENTS (beneficiary) | 1:M | BENEFICIARY_ACCOUNT_ID | Account that receives the payment |
| PAYMENT_SCHEMES → PAYMENTS | 1:M | PAYMENT_TYPE = SCHEME_CODE | Scheme properties for each payment |
| PAYMENT_SCHEMES → SLA_DEFINITIONS | 1:M | PAYMENT_TYPE | SLA thresholds per scheme |
| ERROR_CODES → PAYMENTS | 1:M | ERROR_CODE | Nullable — only populated on errors (~5%) |
| CUSTOMERS → CUSTOMER_FEEDBACK | 1:M | CUSTOMER_ID | Feedback submitted by a customer |
| PAYMENTS → CUSTOMER_FEEDBACK | 1:M | PAYMENT_ID | Nullable — ~60% of feedback links to a specific payment |
| PAYMENTS → OPERATIONAL_ALERTS | 1:M | PAYMENT_ID | Nullable — ~40% of alerts link to a specific payment |

## Grain Definitions

| Table | Grain | Typical Row Count |
|---|---|---|
| RELATIONSHIP_MANAGERS | One row per RM | 10 |
| CUSTOMERS | One row per corporate client | 30 |
| ACCOUNTS | One row per bank account | ~36 |
| PAYMENT_SCHEMES | One row per payment scheme | 6 |
| ERROR_CODES | One row per error code | 20 |
| PAYMENTS | One row per payment transaction | 50,000 |
| CUSTOMER_FEEDBACK | One row per feedback submission | 2,000 |
| SLA_DEFINITIONS | One row per scheme SLA | 6 |
| OPERATIONAL_ALERTS | One row per alert event | 1,500 |

## Data Generation Notes

All data is **entirely synthetic** — no real customer, transaction, or Barclays data is used.

### Realistic distributions applied

- **Payments:** ~70% domestic schemes (BACS, CHAPS, Faster Payments, Wire Transfer), ~30% international (SWIFT, SEPA). This reflects a UK-domiciled bank's typical mix.
- **Account routing:** Domestic schemes route through GBP accounts with sort codes; international schemes route through IBAN/BIC accounts. This ensures joins to ACCOUNTS produce realistic results.
- **Currencies:** SEPA always EUR, SWIFT mixed (GBP/EUR/USD), domestic always GBP.
- **FX rates:** Only populated on cross-currency payments (SWIFT, SEPA). Centred around realistic GBP/EUR (~0.85) and GBP/USD (~1.0) rates with small random variance.
- **Settlement dates:** Derived from PAYMENT_DATE using each scheme's settlement cycle (real-time, same-day, T+1, T+2).
- **Error codes:** All FAILED and RETURNED payments have an error code from the ERROR_CODES reference table (ERR001–ERR020). COMPLETED and PENDING payments never have error codes.
- **Feedback linkage:** ~60% of customer feedback rows link to a specific PAYMENT_ID; the rest are general feedback without a transaction reference.
- **Alert linkage:** Every operational alert links to a specific PAYMENT_ID drawn from FAILED/RETURNED/PENDING payments. The alert's PAYMENT_TYPE is derived from the linked payment.
- **Customer sectors:** Diverse mix — Manufacturing, Financial Services, Trading, Logistics, Technology, Consulting, etc.
- **Account types:** CURRENT (standard operating), SETTLEMENT (high-volume clearing), NOSTRO (correspondent banking for FX).
- **RM distribution:** 10 RMs across Corporate Banking, Institutional Banking, SME Banking teams, spread across UK, EMEA, APAC, Americas regions.

## Column Dictionary

### RELATIONSHIP_MANAGERS

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| RM_ID | VARCHAR(10) | NO | PK | Unique RM identifier (e.g. RM001) |
| RM_NAME | VARCHAR(200) | NO | — | Full name |
| RM_EMAIL | VARCHAR(200) | NO | — | Corporate email address |
| TEAM | VARCHAR(50) | NO | — | Banking team: Corporate, Institutional, SME |
| REGION | VARCHAR(30) | NO | — | Operating region: UK, EMEA, APAC, Americas |
| START_DATE | DATE | NO | — | Date RM started managing clients |

### CUSTOMERS

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| CUSTOMER_ID | VARCHAR(15) | NO | PK | Unique customer identifier (e.g. CUST00001) |
| CUSTOMER_NAME | VARCHAR(200) | NO | — | Registered legal entity name |
| SECTOR | VARCHAR(50) | NO | — | Industry sector classification |
| COUNTRY | VARCHAR(3) | NO | — | ISO 3166-1 alpha-3 country code |
| ONBOARDING_DATE | DATE | NO | — | Date client was onboarded |
| KYC_STATUS | VARCHAR(20) | NO | — | APPROVED, PENDING_REVIEW, EXPIRED |
| RM_ID | VARCHAR(10) | NO | → RELATIONSHIP_MANAGERS | Assigned relationship manager |

### ACCOUNTS

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| ACCOUNT_ID | VARCHAR(15) | NO | PK | Unique account identifier (e.g. ACC00001) |
| CUSTOMER_ID | VARCHAR(15) | NO | → CUSTOMERS | Owning customer |
| SORT_CODE | VARCHAR(8) | YES | — | UK sort code (domestic accounts only) |
| ACCOUNT_NUMBER | VARCHAR(10) | YES | — | UK account number (domestic accounts only) |
| IBAN | VARCHAR(34) | YES | — | International Bank Account Number (international accounts) |
| BIC | VARCHAR(11) | YES | — | SWIFT/BIC code (international accounts) |
| CURRENCY | VARCHAR(3) | NO | — | Account base currency (GBP, EUR, USD) |
| ACCOUNT_TYPE | VARCHAR(30) | NO | — | CURRENT, SETTLEMENT, NOSTRO, VOSTRO |
| STATUS | VARCHAR(20) | NO | — | ACTIVE, DORMANT, CLOSED |
| OPENED_DATE | DATE | NO | — | Date account was opened |

### PAYMENT_SCHEMES

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| SCHEME_CODE | VARCHAR(30) | NO | PK | Scheme identifier (e.g. CHAPS, SWIFT) |
| SCHEME_NAME | VARCHAR(100) | NO | — | Full scheme name |
| SETTLEMENT_CYCLE | VARCHAR(20) | NO | — | REAL_TIME, SAME_DAY, T_PLUS_1, T_PLUS_2 |
| IS_DOMESTIC | BOOLEAN | NO | — | Whether the scheme operates domestically |
| MAX_VALUE_GBP | NUMBER(15,2) | YES | — | Maximum single payment value (NULL = no limit) |
| CUTOFF_TIME | TIME | YES | — | Daily submission cutoff (NULL = 24/7) |
| OPERATING_CURRENCY | VARCHAR(3) | NO | — | Primary operating currency |

### ERROR_CODES

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| ERROR_CODE | VARCHAR(10) | NO | PK | Error code (e.g. ERR001) |
| ERROR_DESCRIPTION | VARCHAR(200) | NO | — | Human-readable error description |
| ERROR_CATEGORY | VARCHAR(50) | NO | — | ROUTING, VALIDATION, COMPLIANCE, CONNECTIVITY, TIMEOUT |
| IS_RETRYABLE | BOOLEAN | NO | — | Whether the payment can be resubmitted |

### PAYMENTS

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| PAYMENT_ID | VARCHAR(20) | NO | PK | Unique payment identifier (e.g. PAY0000000001) |
| PAYMENT_DATE | TIMESTAMP | NO | — | Timestamp payment was initiated |
| ORIGINATOR_ACCOUNT_ID | VARCHAR(15) | NO | → ACCOUNTS | Account that initiated the payment |
| BENEFICIARY_ACCOUNT_ID | VARCHAR(15) | NO | → ACCOUNTS | Account that receives the payment |
| PAYMENT_TYPE | VARCHAR(30) | NO | → PAYMENT_SCHEMES | Payment scheme used |
| CHANNEL | VARCHAR(20) | NO | — | Submission channel: API, Online Banking, Branch, File Upload, Mobile |
| CURRENCY | VARCHAR(3) | NO | — | Transaction currency (may differ from account currency) |
| AMOUNT | NUMBER(15,2) | NO | — | Payment amount in transaction currency |
| FX_RATE | NUMBER(10,6) | YES | — | Exchange rate (populated for cross-currency payments only) |
| STATUS | VARCHAR(20) | NO | — | COMPLETED, PENDING, FAILED, RETURNED |
| PROCESSING_TIME_MS | NUMBER | NO | — | End-to-end processing time in milliseconds |
| ERROR_CODE | VARCHAR(10) | YES | → ERROR_CODES | Error code — always populated on FAILED/RETURNED, NULL otherwise |
| REGION | VARCHAR(30) | NO | — | Processing region: UK, EMEA, APAC, Americas |
| SETTLEMENT_DATE | DATE | YES | — | Expected settlement date based on scheme cycle |

### CUSTOMER_FEEDBACK

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| FEEDBACK_ID | VARCHAR(15) | NO | PK | Unique feedback identifier (e.g. FB00000001) |
| FEEDBACK_DATE | TIMESTAMP | NO | — | When feedback was submitted |
| CUSTOMER_ID | VARCHAR(15) | NO | → CUSTOMERS | Customer who submitted feedback |
| PAYMENT_ID | VARCHAR(20) | YES | → PAYMENTS | Specific payment referenced (~60% populated) |
| FEEDBACK_CHANNEL | VARCHAR(30) | NO | — | Email, Phone, Portal, Survey, Chat |
| FEEDBACK_TEXT | VARCHAR(1000) | NO | — | Free-text feedback content |
| PAYMENT_TYPE | VARCHAR(30) | NO | — | Payment scheme referenced (denormalised) |
| RATING | NUMBER(1) | NO | — | 1–5 satisfaction rating |

### SLA_DEFINITIONS

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| SLA_ID | VARCHAR(10) | NO | PK | Unique SLA identifier |
| SLA_NAME | VARCHAR(100) | NO | — | Descriptive SLA name |
| PAYMENT_TYPE | VARCHAR(30) | NO | → PAYMENT_SCHEMES | Scheme this SLA applies to |
| MAX_PROCESSING_TIME_MS | NUMBER | NO | — | Maximum allowed P95 processing time |
| TARGET_SUCCESS_RATE | NUMBER(5,2) | NO | — | Minimum success rate percentage |
| MEASUREMENT_WINDOW | VARCHAR(20) | NO | — | HOURLY or DAILY |

### OPERATIONAL_ALERTS

| Column | Type | Nullable | FK | Description |
|---|---|---|---|---|
| ALERT_ID | VARCHAR(15) | NO | PK | Unique alert identifier |
| ALERT_TIME | TIMESTAMP | NO | — | When the alert was raised |
| SEVERITY | VARCHAR(10) | NO | — | LOW, MEDIUM, HIGH, CRITICAL |
| PAYMENT_TYPE | VARCHAR(30) | NO | — | Scheme associated with the alert |
| PAYMENT_ID | VARCHAR(20) | NO | → PAYMENTS | Every alert links to a specific problem payment |
| ALERT_DESCRIPTION | VARCHAR(500) | NO | — | Alert description text |
| STATUS | VARCHAR(20) | NO | — | OPEN, ACKNOWLEDGED, INVESTIGATING, RESOLVED |
| ASSIGNED_TO | VARCHAR(100) | NO | — | Operations team assigned |
| RESOLUTION_TIME_MIN | NUMBER | YES | — | Time to resolution in minutes (NULL if unresolved) |
