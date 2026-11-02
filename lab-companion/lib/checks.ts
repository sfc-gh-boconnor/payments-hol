// "Check my work" definitions. Each check is ONE SQL statement returning a single
// row with OK (boolean) and DETAIL (string). Checks run with the app's own
// rights (HOL_ADMIN, which inherits HOL_PARTICIPANT), so they can see every
// object an attendee builds. Keep them read-only and fast.
//
// Tested against the reference build in demo810 (all pass except
// de1_coco_marts, which only exists once an attendee has built it with CoCo).

export type Check = {
  id: string
  label: string
  sql: string
  hint: string
}

const exists = (schema: string, name: string, extra = "") =>
  `SELECT COUNT(*) > 0 AS OK, COALESCE(MAX(TABLE_TYPE || IFF(IS_DYNAMIC = 'YES', ' (dynamic)', '') || IFF(IS_ICEBERG = 'YES', ' (iceberg)', '')), 'not found') AS DETAIL
   FROM BARCLAYS_HOL.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '${schema}' AND TABLE_NAME = '${name}' ${extra}`

const rows = (fqn: string, min = 1) =>
  `SELECT COUNT(*) >= ${min} AS OK, COUNT(*) || ' rows' AS DETAIL FROM ${fqn}`

const show = (showSql: string, what: string) =>
  `${showSql} ->> SELECT COUNT(*) > 0 AS OK, IFF(COUNT(*) > 0, '${what} found', '${what} not found') AS DETAIL FROM $1`

export const CHECKS: Record<string, Check[]> = {
  C1: [
    {
      id: "c1_iceberg_published",
      label: "Nine source tables are published as Iceberg",
      sql: `SELECT COUNT_IF(IS_ICEBERG = 'YES') = 9 AS OK, COUNT_IF(IS_ICEBERG = 'YES') || ' of 9 Iceberg tables' AS DETAIL
            FROM BARCLAYS_HOL.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'RAW_DATA'`,
      hint: "Ask the facilitator - setup/02_publish_iceberg.sql has not been run in this account.",
    },
    {
      id: "c1_payments_rows",
      label: "PAYMENTS has 50,000 synthetic transactions",
      sql: `SELECT COUNT(*) = 50000 AS OK, COUNT(*) || ' rows' AS DETAIL FROM BARCLAYS_HOL.RAW_DATA.PAYMENTS`,
      hint: "Ask the facilitator to re-run setup/01 and setup/02.",
    },
  ],
  DE1: [
    {
      id: "de1_staging",
      label: "dbt staging views built (STG_PAYMENTS)",
      sql: exists("ANALYTICS", "STG_PAYMENTS"),
      hint: "Run the dbt project: EXECUTE DBT PROJECT BARCLAYS_HOL.ANALYTICS.BARCLAYS_DBT ARGS = 'build';",
    },
    {
      id: "de1_kpi_mart",
      label: "MART_PAYMENT_KPIS has data",
      sql: rows("BARCLAYS_HOL.ANALYTICS.MART_PAYMENT_KPIS", 1000),
      hint: "Re-run dbt build and check for errors in the output.",
    },
    {
      id: "de1_coco_marts",
      label: "Cortex Code built MART_RM_PERFORMANCE",
      sql: exists("ANALYTICS", "MART_RM_PERFORMANCE"),
      hint: "Use DE1 prompt 2 in the Cortex Code panel, then run dbt build.",
    },
    {
      id: "de1_iceberg_product",
      label: "DP_SLA_COMPLIANCE published back to the lake as Iceberg",
      sql: exists("ANALYTICS", "DP_SLA_COMPLIANCE", "AND IS_ICEBERG = 'YES'"),
      hint: "Run section DE1.5 (CREATE ICEBERG TABLE DP_SLA_COMPLIANCE ...).",
    },
  ],
  DE2: [
    {
      id: "de2_dynamic_tables",
      label: "Three dynamic tables created",
      sql: `SELECT COUNT(*) >= 3 AS OK, LISTAGG(TABLE_NAME, ', ') AS DETAIL
            FROM BARCLAYS_HOL.INFORMATION_SCHEMA.TABLES
            WHERE TABLE_SCHEMA = 'ANALYTICS' AND IS_DYNAMIC = 'YES'
              AND TABLE_NAME IN ('DT_LIVE_SLA_BREACHES', 'DT_FAILED_PAYMENT_TRIAGE', 'DT_RETRYABLE_SUMMARY')`,
      hint: "Run section DE2.1. Prereq: setup/catchup/core_analytics.sql.",
    },
    {
      id: "de2_dt_refreshed",
      label: "DT_RETRYABLE_SUMMARY has refreshed with data",
      sql: rows("BARCLAYS_HOL.ANALYTICS.DT_RETRYABLE_SUMMARY"),
      hint: "Wait a minute for the first refresh, or run ALTER DYNAMIC TABLE DT_RETRYABLE_SUMMARY REFRESH;",
    },
    {
      id: "de2_dmfs",
      label: "Data metric functions attached to MART_CUSTOMER_PAYMENTS",
      sql: `SELECT COUNT(*) >= 3 AS OK, COUNT(*) || ' DMFs attached' AS DETAIL
            FROM TABLE(BARCLAYS_HOL.INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
              REF_ENTITY_NAME => 'BARCLAYS_HOL.ANALYTICS.MART_CUSTOMER_PAYMENTS', REF_ENTITY_DOMAIN => 'TABLE'))`,
      hint: "Run section DE2.2 (NULL_COUNT, DUPLICATE_COUNT and INVALID_SUCCESS_RATE_COUNT).",
    },
  ],
  DA1: [
    {
      id: "da1_semantic_view",
      label: "Semantic view SV_CLIENT_360 created",
      sql: show("SHOW SEMANTIC VIEWS LIKE 'SV_CLIENT_360' IN SCHEMA BARCLAYS_HOL.ANALYTICS", "SV_CLIENT_360"),
      hint: "Run section DA1.2. Prereq: setup/catchup/core_analytics.sql.",
    },
    {
      id: "da1_semantic_query",
      label: "SV_CLIENT_360 answers a metrics query",
      sql: `SELECT COUNT(*) >= 5 AS OK, COUNT(*) || ' RMs returned' AS DETAIL FROM SEMANTIC_VIEW(
              BARCLAYS_HOL.ANALYTICS.SV_CLIENT_360 DIMENSIONS clients.rm_name METRICS payments.payment_volume)`,
      hint: "Check the RELATIONSHIPS and METRICS blocks in your semantic view DDL.",
    },
  ],
  DA2: [
    {
      id: "da2_enriched",
      label: "FEEDBACK_ENRICHED scored with sentiment and topic",
      sql: `SELECT COUNT(*) >= 1000 AND COUNT_IF(TOPIC_CATEGORY IS NULL) = 0 AS OK,
                   COUNT(*) || ' rows, ' || COUNT(DISTINCT TOPIC_CATEGORY) || ' topics' AS DETAIL
            FROM BARCLAYS_HOL.ANALYTICS.FEEDBACK_ENRICHED`,
      hint: "Run section DA2.2.",
    },
    {
      id: "da2_rm_themes",
      label: "AI_AGG complaint themes generated per RM",
      sql: `SELECT COUNT(*) >= 5 AND COUNT_IF(LENGTH(TOP_THEMES) > 50) = COUNT(*) AS OK, COUNT(*) || ' RMs with themes' AS DETAIL
            FROM BARCLAYS_HOL.ANALYTICS.RM_FEEDBACK_THEMES`,
      hint: "Run section DA2.4 (CREATE TABLE RM_FEEDBACK_THEMES ... AI_AGG).",
    },
  ],
  OPS1: [
    {
      id: "ops1_agent",
      label: "Corporate Payments 360 agent published",
      sql: show("SHOW AGENTS LIKE 'CORPORATE_PAYMENTS_360' IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS", "Agent"),
      hint: "Run section OPS1.1. Prereqs: DA1 and setup/catchup/semantic_view_and_agent.sql.",
    },
  ],
  OPS2: [
    {
      id: "ops2_queue",
      label: "Prioritised triage queue built",
      sql: rows("BARCLAYS_HOL.ANALYTICS.V_ALERT_TRIAGE_QUEUE", 10),
      hint: "Run sections OPS2.1 and OPS2.2.",
    },
    {
      id: "ops2_recommendations",
      label: "AI recommendations generated for the top alerts",
      sql: rows("BARCLAYS_HOL.ANALYTICS.ALERT_RECOMMENDATIONS", 5),
      hint: "Run section OPS2.3.",
    },
  ],
  AI1: [
    {
      id: "ai1_tool",
      label: "SCHEME_RULES tool returns CHAPS rules",
      sql: `SELECT BARCLAYS_HOL.AGENTS.SCHEME_RULES('CHAPS'):cutoff_time_uk::STRING = '15:45:00' AS OK,
                   'CHAPS cutoff ' || BARCLAYS_HOL.AGENTS.SCHEME_RULES('CHAPS'):cutoff_time_uk::STRING AS DETAIL`,
      hint: "Run section AI1.2.",
    },
    {
      id: "ai1_agent",
      label: "PAYMENTS_INVESTIGATOR agent created",
      sql: show("SHOW AGENTS LIKE 'PAYMENTS_INVESTIGATOR' IN SCHEMA BARCLAYS_HOL.AGENTS", "Agent"),
      hint: "Run section AI1.3.",
    },
  ],
  AI2: [
    {
      id: "ai2_mcp",
      label: "PAYMENTS_MCP server created",
      sql: show("SHOW MCP SERVERS LIKE 'PAYMENTS_MCP' IN SCHEMA BARCLAYS_HOL.AGENTS", "MCP server"),
      hint: "Run section AI2.1. Prereqs: DA1, OPS1 and AI1.",
    },
  ],
  AI3: [
    {
      id: "ai3_extension",
      label: "Marketplace knowledge extension is available",
      sql: show("SHOW CORTEX SEARCH SERVICES IN DATABASE SNOWFLAKE_DOCS_CKE", "Knowledge extension"),
      hint: "Ask the facilitator - setup/00 installs SNOWFLAKE_DOCS_CKE from the Marketplace.",
    },
    {
      id: "ai3_agent",
      label: "Payments Platform Copilot agent created",
      sql: show("SHOW AGENTS LIKE 'PAYMENTS_PLATFORM_COPILOT' IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS", "Agent"),
      hint: "Run section AI3.3.",
    },
  ],
  GOV1: [
    {
      id: "gov1_tagged",
      label: "IBAN tagged RESTRICTED",
      sql: `SELECT COUNT(*) > 0 AS OK, COALESCE(MAX(TAG_VALUE), 'no DATA_SENSITIVITY tag') AS DETAIL
            FROM TABLE(BARCLAYS_HOL.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('BARCLAYS_HOL.GOVERNANCE.ACCOUNT_REGISTER', 'table'))
            WHERE COLUMN_NAME = 'IBAN' AND TAG_NAME = 'DATA_SENSITIVITY' AND TAG_VALUE = 'RESTRICTED'`,
      hint: "Run sections GOV1.1 and GOV1.2.",
    },
    {
      id: "gov1_policies",
      label: "Masking (via tag) and row access policies protect ACCOUNT_REGISTER",
      sql: `SELECT COUNT_IF(POLICY_KIND = 'MASKING_POLICY') > 0 AND COUNT_IF(POLICY_KIND = 'ROW_ACCESS_POLICY') > 0 AS OK,
                   LISTAGG(DISTINCT POLICY_KIND, ', ') AS DETAIL
            FROM TABLE(BARCLAYS_HOL.INFORMATION_SCHEMA.POLICY_REFERENCES(
              REF_ENTITY_NAME => 'BARCLAYS_HOL.GOVERNANCE.ACCOUNT_REGISTER', REF_ENTITY_DOMAIN => 'TABLE'))`,
      hint: "Run sections GOV1.3 and GOV1.4.",
    },
  ],
  GOV2: [
    {
      id: "gov2_documented",
      label: "MART_SLA_COMPLIANCE documented for consumers",
      sql: `SELECT COUNT_IF(COMMENT ILIKE '%Owner:%') > 0 AS OK, COALESCE(LEFT(MAX(COMMENT), 80), 'no comment') AS DETAIL
            FROM BARCLAYS_HOL.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'ANALYTICS' AND TABLE_NAME = 'MART_SLA_COMPLIANCE'`,
      hint: "Run section GOV2.4 (COMMENT ON TABLE ...).",
    },
  ],
}

export const ALL_CHECK_IDS = Object.values(CHECKS).flat().map((c) => c.id)
