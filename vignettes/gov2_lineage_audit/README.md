# GOV2: Lineage, audit and trust

| | |
|---|---|
| **Persona** | Governance / Risk / Audit |
| **Time** | ~30 min |
| **Prerequisites** | DE1 or catch-up, plus at least one agent run |
| **Script** | [`gov2.sql`](gov2.sql) |

## Business question
> If a source Iceberg table changes, what breaks? And who - human or agent - has been reading client data?

## What you'll build
- Lineage and access-history queries
- Business comments on the SLA data product

## Steps
1. Downstream impact of `RAW_DATA.PAYMENTS` with `GET_LINEAGE`.
2. Upstream lineage of `MART_SLA_COMPLIANCE`.
3. Access history on restricted columns.
4. Query history for semantic view / agent usage.
5. Document the data product.

## Cortex Code prompts
- *"If I drop PROCESSING_TIME_MS from RAW_DATA.PAYMENTS, which downstream objects and agents break?"*
- *"Produce a one-page data product card for MART_SLA_COMPLIANCE."*

## Check your work
Downstream lineage lists the staging views, marts, dynamic tables and `SV_CLIENT_360`.

## Barclayflake note
ACCOUNT_USAGE views have up to ~3 hours latency - run history queries at the end of the session.
