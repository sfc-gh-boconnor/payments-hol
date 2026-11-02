# GOV1: Classify, tag, mask and filter PII

| | |
|---|---|
| **Persona** | Governance / Risk |
| **Time** | ~45 min |
| **Prerequisites** | `setup/catchup/core_analytics.sql` |
| **Script** | [`gov1.sql`](gov1.sql) |

## Business question
> Prove account identifiers are protected wherever they flow - dashboards, semantic views, agents - and that people only see clients in their region.

## What you'll build
- `GOVERNANCE.ACCOUNT_REGISTER`
- Tag `DATA_SENSITIVITY` with tag-based masking policy
- Row access policy `RAP_ACCOUNT_REGION`

## Steps
1. Auto-classify with `SYSTEM$CLASSIFY`.
2. Apply the bank's sensitivity tags.
3. Attach a masking policy to the tag (protects every tagged column).
4. Add a row access policy by currency/region.
5. Query as builder, restricted UK desk and data owner.

## Cortex Code prompts
- *"Show me every column in BARCLAYS_HOL tagged DATA_SENSITIVITY and the masking policy protecting it."*

## Check your work
Builder sees 36 masked rows; `HOL_RESTRICTED` sees 23 GBP-only masked rows; `HOL_ADMIN` sees full IBANs.

## Barclayflake note
In production, central governance applies tags and policies to the Iceberg source tables so every downstream object and agent inherits them.
