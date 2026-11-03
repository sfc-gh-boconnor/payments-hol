# GOV1: PII policies

| | |
|---|---|
| **Persona** | Governance / Risk |
| **Time** | ~45 min |
| **Prerequisites** | `setup/catchup/core_analytics.sql` |
| **Reference SQL** | [`gov1.sql`](gov1.sql) |

## Business question
> Prove account identifiers are protected wherever they flow - dashboards, semantic views, agents - and that people only see clients in their region.

## What you'll build
- `GOVERNANCE.ACCOUNT_REGISTER`
- Tag `DATA_SENSITIVITY` with tag-based masking policy
- Row access policy `RAP_ACCOUNT_REGION`

## Steps
### Set your context
Where: payments-hol Workspace > **+ > SQL file**
```sql
USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.GOVERNANCE;
```

### Let Snowflake find the sensitive data
Where: the Cortex Code sidebar
```prompt
Create a table BARCLAYS_HOL.GOVERNANCE.ACCOUNT_REGISTER as a copy of BARCLAYS_HOL.ANALYTICS.STG_ACCOUNTS, run SYSTEM$CLASSIFY on it with auto_tag true, and show which columns were tagged and with what.
```
Expect: Snowflake's classifier flags identifier columns such as IBAN and account number

### Apply the bank's sensitivity tags
```prompt
In BARCLAYS_HOL.GOVERNANCE create (or replace) a tag DATA_SENSITIVITY with allowed values PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED. On ACCOUNT_REGISTER set IBAN and ACCOUNT_NUMBER to RESTRICTED, SORT_CODE to CONFIDENTIAL and BIC to INTERNAL.
```
Expect: four tagged columns, with `IBAN` = `RESTRICTED`
Check: gov1_tagged

### Mask every tagged column with one policy
```prompt
Create a masking policy BARCLAYS_HOL.GOVERNANCE.MASK_RESTRICTED_STRING for strings: HOL_ADMIN (the data owner) sees the real value; CONFIDENTIAL values (read with SYSTEM$GET_TAG_ON_CURRENT_COLUMN on BARCLAYS_HOL.GOVERNANCE.DATA_SENSITIVITY) keep their shape with digits replaced by *; everything else shows '****' plus the last 4 characters. Attach it to the DATA_SENSITIVITY tag, then remove the tag from BIC so it stays readable.
```
Expect: one policy that protects every column carrying the tag, now and in future

### Filter rows by region
```prompt
Create a mapping table BARCLAYS_HOL.GOVERNANCE.REGION_ENTITLEMENTS (ROLE_NAME, CURRENCY) with HOL_RESTRICTED mapped to GBP. Create a row access policy RAP_ACCOUNT_REGION on a currency column: HOL_PARTICIPANT sees all rows, otherwise only currencies mapped to a role in the session. Add it to ACCOUNT_REGISTER on CURRENCY and grant SELECT on ACCOUNT_REGISTER to HOL_RESTRICTED.
```
Expect: the row access policy attached to `ACCOUNT_REGISTER`
Check: gov1_policies

### Test as each persona
```prompt
Show 8 rows (ACCOUNT_ID, CUSTOMER_NAME, CURRENCY, SORT_CODE, ACCOUNT_NUMBER, IBAN) and the row count of BARCLAYS_HOL.GOVERNANCE.ACCOUNT_REGISTER, first as my current role and then as HOL_RESTRICTED, and explain the difference. Switch back to HOL_PARTICIPANT at the end.
```
Expect: as the builder, 36 rows with masked identifiers; as `HOL_RESTRICTED`, 23 GBP-only masked rows

### Policies follow the data into AI
```prompt
Show me every column in BARCLAYS_HOL tagged DATA_SENSITIVITY and the masking policy protecting it. Then tell me the IBAN for any client in ACCOUNT_REGISTER.
```
Expect: Cortex Code runs as your role, so it only ever sees and returns the masked IBAN

## Check your work
Builder sees 36 masked rows; `HOL_RESTRICTED` sees 23 GBP-only masked rows; `HOL_ADMIN` sees full IBANs.

## Barclayflake note
In production, central governance applies tags and policies to the Iceberg source tables so every downstream object and agent inherits them.
