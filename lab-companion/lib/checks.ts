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
  /** Run with the attendee's own rights, for objects in their personal USER$ database. */
  asCaller?: boolean
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
      hint: "In the dbt tab of the bottom panel, click the arrow next to Run > Build > Execute. Or run the reference SQL.",
    },
    {
      id: "de1_kpi_mart",
      label: "MART_PAYMENT_KPIS has data",
      sql: rows("BARCLAYS_HOL.ANALYTICS.MART_PAYMENT_KPIS", 1000),
      hint: "Re-run dbt build and check for errors in the output.",
    },
    {
      id: "de1_coco_marts",
      label: "MART_RM_PERFORMANCE built and tested",
      sql: exists("ANALYTICS", "MART_RM_PERFORMANCE"),
      hint: "The table only exists after a build. In the dbt pane click the arrow next to Run > Build > Execute.",
    },
    {
      id: "de1_task",
      label: "Nightly dbt build task scheduled (suspended)",
      sql: `SHOW TASKS LIKE 'TSK_DBT_NIGHTLY_BUILD' IN SCHEMA BARCLAYS_HOL.ANALYTICS ->> SELECT COUNT(*) > 0 AS OK, COALESCE(MAX("state") || ', ' || MAX("schedule"), 'TSK_DBT_NIGHTLY_BUILD not found') AS DETAIL FROM $1`,
      hint: "Paste the schedule prompt into Cortex Code. The task must be TSK_DBT_NIGHTLY_BUILD in BARCLAYS_HOL.ANALYTICS.",
    },
    {
      id: "de1_iceberg_product",
      label: "DP_SLA_COMPLIANCE published back to the lake as Iceberg",
      sql: exists("ANALYTICS", "DP_SLA_COMPLIANCE", "AND IS_ICEBERG = 'YES'"),
      hint: "Paste the Iceberg data product prompt into Cortex Code.",
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
      hint: "Paste the dynamic table prompts into Cortex Code, using these exact names. Prereq: setup/catchup/core_analytics.sql.",
    },
    {
      id: "de2_dt_refreshed",
      label: "DT_RETRYABLE_SUMMARY has refreshed with data",
      sql: rows("BARCLAYS_HOL.ANALYTICS.DT_RETRYABLE_SUMMARY"),
      hint: "Wait a minute for the first refresh, or ask Cortex Code to refresh DT_RETRYABLE_SUMMARY.",
    },
    {
      id: "de2_dmfs",
      label: "Data metric functions attached to MART_CUSTOMER_PAYMENTS",
      sql: `SELECT COUNT(*) >= 3 AS OK, COUNT(*) || ' DMFs attached' AS DETAIL
            FROM TABLE(BARCLAYS_HOL.INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
              REF_ENTITY_NAME => 'BARCLAYS_HOL.ANALYTICS.MART_CUSTOMER_PAYMENTS', REF_ENTITY_DOMAIN => 'TABLE'))`,
      hint: "Paste the data quality prompt into Cortex Code. MART_CUSTOMER_PAYMENTS must exist (DE1 or the catch-up).",
    },
    {
      id: "de2_pipeline",
      label: "Pipeline Builder project created in ANALYTICS",
      sql: `SHOW DCM PROJECTS IN SCHEMA BARCLAYS_HOL.ANALYTICS ->> SELECT COUNT(*) > 0 AS OK, COALESCE(NULLIF(LISTAGG("name", ', '), ''), 'no Pipeline Builder project in ANALYTICS') AS DETAIL FROM $1`,
      hint: "+ > Pipeline Builder, schema BARCLAYS_HOL.ANALYTICS (not RAW_DATA), then Deploy.",
    },
  ],
  DA1: [
    {
      id: "da1_semantic_view",
      label: "Semantic view SV_CLIENT_360 created",
      sql: show("SHOW SEMANTIC VIEWS LIKE 'SV_CLIENT_360' IN SCHEMA BARCLAYS_HOL.ANALYTICS", "SV_CLIENT_360"),
      hint: "Create SV_CLIENT_360 with the semantic view prompt. Prereq: setup/catchup/core_analytics.sql.",
    },
    {
      id: "da1_semantic_query",
      label: "SV_CLIENT_360 answers a metrics query",
      sql: `SELECT COUNT(*) >= 5 AS OK, COUNT(*) || ' RMs returned' AS DETAIL FROM SEMANTIC_VIEW(
              BARCLAYS_HOL.ANALYTICS.SV_CLIENT_360 DIMENSIONS clients.rm_name METRICS payments.payment_volume)`,
      hint: "Keep the logical names from the prompt: tables clients and payments, dimension rm_name, metric payment_volume.",
    },
  ],
  DA2: [
    {
      id: "da2_enriched",
      label: "FEEDBACK_ENRICHED scored with sentiment and topic",
      sql: `SELECT COUNT(*) >= 1000 AND COUNT_IF(TOPIC_CATEGORY IS NULL) = 0 AS OK,
                   COUNT(*) || ' rows, ' || COUNT(DISTINCT TOPIC_CATEGORY) || ' topics' AS DETAIL
            FROM BARCLAYS_HOL.ANALYTICS.FEEDBACK_ENRICHED`,
      hint: "Paste the enrichment prompt into Cortex Code.",
    },
    {
      id: "da2_rm_themes",
      label: "AI_AGG complaint themes generated per RM",
      sql: `SELECT COUNT(*) >= 5 AND COUNT_IF(LENGTH(TOP_THEMES) > 50) = COUNT(*) AS OK, COUNT(*) || ' RMs with themes' AS DETAIL
            FROM BARCLAYS_HOL.ANALYTICS.RM_FEEDBACK_THEMES`,
      hint: "Paste the AI_AGG themes prompt into Cortex Code.",
    },
  ],
  DA3: [
    {
      id: "da3_catchment",
      label: "Every retail customer has a fastest and second-fastest branch by drive time",
      sql: `SELECT COUNT(*) >= 19000 AND COUNT(SECOND_BRANCH_ID) >= COUNT(*) * 0.95 AS OK,
                   COUNT(*) || ' customers, median ' || ROUND(MEDIAN(NEAREST_DRIVE_MIN), 1) || ' min drive to fastest branch' AS DETAIL
            FROM BARCLAYS_HOL.ANALYTICS.CUSTOMER_NEAREST_BRANCH`,
      hint: "Paste the fastest-branch prompt into Cortex Code (it must include the second-fastest branch and NEAREST_DRIVE_MIN).",
    },
    {
      id: "da3_closure_impact",
      label: "BRANCH_CLOSURE_IMPACT models every branch",
      sql: `SELECT COUNT(*) >= 50 AND COUNT_IF(DISRUPTION_RISK = 'HIGH') > 0 AS OK,
                   COUNT(*) || ' branches, ' || COUNT_IF(DISRUPTION_RISK = 'LOW') || ' LOW risk' AS DETAIL
            FROM BARCLAYS_HOL.ANALYTICS.BRANCH_CLOSURE_IMPACT`,
      hint: "Paste the closure-impact prompt into Cortex Code.",
    },
    {
      id: "da3_semantic_view",
      label: "SV_BRANCH_NETWORK semantic view exists",
      sql: show("SHOW SEMANTIC VIEWS LIKE 'SV_BRANCH_NETWORK' IN SCHEMA BARCLAYS_HOL.ANALYTICS", "SV_BRANCH_NETWORK"),
      hint: "Paste the semantic view prompt into Cortex Code.",
    },
    {
      id: "da3_agent",
      label: "BRANCH_NETWORK_ADVISOR agent exists",
      sql: show("SHOW AGENTS LIKE 'BRANCH_NETWORK_ADVISOR' IN SCHEMA BARCLAYS_HOL.ANALYTICS", "BRANCH_NETWORK_ADVISOR"),
      hint: "Create the agent with + > Agent > Create with CoCo, using the prompt in this step.",
    },
    {
      id: "da3_map_app",
      label: "BRANCH_NETWORK_MAP Streamlit app exists",
      sql: show("SHOW STREAMLITS LIKE 'BRANCH_NETWORK_MAP' IN SCHEMA BARCLAYS_HOL.ANALYTICS", "BRANCH_NETWORK_MAP"),
      hint: "Ask Cortex Code to build the app from + > Streamlit App, using the prompt in this step.",
    },
  ],
  OPS1: [
    {
      id: "ops1_agent",
      label: "Corporate Payments 360 agent published",
      sql: show("SHOW AGENTS LIKE 'CORPORATE_PAYMENTS_360' IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS", "Agent"),
      hint: "+ > Agent > Create with CoCo, using the exact name CORPORATE_PAYMENTS_360 in SNOWFLAKE_INTELLIGENCE.AGENTS. Prereqs: DA1 and setup/catchup/semantic_view_and_agent.sql.",
    },
  ],
  OPS2: [
    {
      id: "ops2_queue",
      label: "Prioritised triage queue built",
      sql: rows("BARCLAYS_HOL.ANALYTICS.V_ALERT_TRIAGE_QUEUE", 10),
      hint: "Paste the feed and triage queue prompts into Cortex Code.",
    },
    {
      id: "ops2_recommendations",
      label: "AI recommendations generated for the top alerts",
      sql: rows("BARCLAYS_HOL.ANALYTICS.ALERT_RECOMMENDATIONS", 5),
      hint: "Paste the AI next actions prompt into Cortex Code.",
    },
  ],
  AI1: [
    {
      id: "ai1_tool",
      label: "SCHEME_RULES tool returns CHAPS rules",
      sql: `SELECT BARCLAYS_HOL.AGENTS.SCHEME_RULES('CHAPS'):cutoff_time_uk::STRING = '15:45:00' AS OK,
                   'CHAPS cutoff ' || BARCLAYS_HOL.AGENTS.SCHEME_RULES('CHAPS'):cutoff_time_uk::STRING AS DETAIL`,
      hint: "Paste the scheme rules prompt into Cortex Code.",
    },
    {
      id: "ai1_agent",
      label: "PAYMENTS_INVESTIGATOR agent created",
      sql: show("SHOW AGENTS LIKE 'PAYMENTS_INVESTIGATOR' IN SCHEMA BARCLAYS_HOL.AGENTS", "Agent"),
      hint: "+ > Agent > Create with CoCo, using the exact name PAYMENTS_INVESTIGATOR in BARCLAYS_HOL.AGENTS.",
    },
  ],
  AI2: [
    {
      id: "ai2_mcp",
      label: "PAYMENTS_MCP server created",
      sql: show("SHOW MCP SERVERS LIKE 'PAYMENTS_MCP' IN SCHEMA BARCLAYS_HOL.AGENTS", "MCP server"),
      hint: "Paste the MCP server prompt into Cortex Code. Prereqs: DA1, OPS1 and AI1.",
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
      hint: "+ > Agent > Create with CoCo, using the exact name PAYMENTS_PLATFORM_COPILOT in SNOWFLAKE_INTELLIGENCE.AGENTS.",
    },
  ],
  GOV1: [
    {
      id: "gov1_tagged",
      label: "IBAN tagged RESTRICTED",
      sql: `SELECT COUNT(*) > 0 AS OK, COALESCE(MAX(TAG_VALUE), 'no DATA_SENSITIVITY tag') AS DETAIL
            FROM TABLE(BARCLAYS_HOL.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('BARCLAYS_HOL.GOVERNANCE.ACCOUNT_REGISTER', 'table'))
            WHERE COLUMN_NAME = 'IBAN' AND TAG_NAME = 'DATA_SENSITIVITY' AND TAG_VALUE = 'RESTRICTED'`,
      hint: "Paste the classify and tag prompts into Cortex Code.",
    },
    {
      id: "gov1_policies",
      label: "Masking (via tag) and row access policies protect ACCOUNT_REGISTER",
      sql: `SELECT COUNT_IF(POLICY_KIND = 'MASKING_POLICY') > 0 AND COUNT_IF(POLICY_KIND = 'ROW_ACCESS_POLICY') > 0 AS OK,
                   LISTAGG(DISTINCT POLICY_KIND, ', ') AS DETAIL
            FROM TABLE(BARCLAYS_HOL.INFORMATION_SCHEMA.POLICY_REFERENCES(
              REF_ENTITY_NAME => 'BARCLAYS_HOL.GOVERNANCE.ACCOUNT_REGISTER', REF_ENTITY_DOMAIN => 'TABLE'))`,
      hint: "Paste the masking and row access prompts into Cortex Code.",
    },
  ],
  GOV2: [
    {
      id: "gov2_documented",
      label: "PAYMENT_SLA_DAILY documented for consumers",
      sql: `SELECT COUNT_IF(COMMENT ILIKE '%Owner:%') > 0 AS OK, COALESCE(LEFT(MAX(COMMENT), 80), 'no comment') AS DETAIL
            FROM BARCLAYS_HOL.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'AUDIT_PACK' AND TABLE_NAME = 'PAYMENT_SLA_DAILY'`,
      hint: "Paste the documentation prompt into Cortex Code (the comment must include \"Owner:\").",
    },
    {
      id: "gov2_automation",
      label: "Daily Cortex Code automation watches restricted-column access",
      sql: `SHOW AGENT TASKS LIKE 'COCO_ROUTINE_%' IN SCHEMA "USER$".PUBLIC ->> SELECT COUNT(*) > 0 AS OK, COALESCE(NULLIF(LISTAGG("name" || ' (' || "state" || ')', ', '), ''), 'no Cortex Code automation yet') AS DETAIL FROM $1`,
      hint: "Ask Cortex Code to set up the daily automation, and say yes when it offers to create it.",
      asCaller: true,
    },
  ],
  DE3: [
    {
      id: "de3_events",
      label: "Payment events streamed into REALTIME.PAYMENT_EVENTS",
      sql: `SELECT COUNT(*) >= 1000 AS OK, COUNT(*) || ' events, ' || COUNT_IF(STATUS = 'FAILED') || ' failed' AS DETAIL FROM BARCLAYS_HOL.REALTIME.PAYMENT_EVENTS`,
      hint: "Run the stream cell in de3_realtime_payments (it needs HOL_NOTEBOOK_ACCESS_INTEGRATION in the notebook settings).",
    },
    {
      id: "de3_incidents",
      label: "DT_PAYMENT_INCIDENTS flags failing payment clusters",
      sql: show("SHOW DYNAMIC TABLES LIKE 'DT_PAYMENT_INCIDENTS' IN SCHEMA BARCLAYS_HOL.REALTIME", "DT_PAYMENT_INCIDENTS"),
      hint: "Paste the incidents prompt into Cortex Code with the notebook open.",
    },
  ],
  GOV3: [
    {
      id: "gov3_traces",
      label: "Cortex AI Gateway recorded your requests today",
      // The app's role has MONITOR on the gateway, so it sees every user's spans; leave out admin and service users
      sql: `SELECT COUNT(*) >= 2 AS OK, COUNT(*) || ' requests via ' || COALESCE(LISTAGG(DISTINCT record_attributes:"gen_ai.request.model"::STRING, ', '), 'no model yet') AS DETAIL
            FROM TABLE(AGENT_TRACE_TABLE('SNOWFLAKE'))
            WHERE timestamp >= DATEADD('day', -1, CURRENT_TIMESTAMP())
              AND record_attributes:"gen_ai.operation.name"::STRING = 'chat'
              AND resource_attributes:"user"::STRING NOT IN ('EMERGENCY_SERVICE_USER', 'DATAOPS_SERVICE_ADMIN', 'SYSTEM', 'ADMIN')`,
      hint: "Run the gateway_calls cell in gov3_ai_gateway (it needs HOL_NOTEBOOK_ACCESS_INTEGRATION in the notebook settings).",
    },
  ],
}

export const ALL_CHECK_IDS = Object.values(CHECKS).flat().map((c) => c.id)

// Prerequisites: what a module needs before you start it. Run live from the module
// page and never recorded as progress, so they don't count towards completion.
const views = (names: string[]) =>
  `SELECT COUNT(*) = ${names.length} AS OK, COUNT(*) || ' of ${names.length} found: ' || COALESCE(LISTAGG(TABLE_NAME, ', ') WITHIN GROUP (ORDER BY TABLE_NAME), 'none') AS DETAIL
     FROM BARCLAYS_HOL.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'ANALYTICS' AND TABLE_NAME IN (${names.map((n) => `'${n}'`).join(", ")})`

const columns = (table: string, cols: string[]) =>
  `SELECT COUNT(*) = ${cols.length} AS OK, COUNT(*) || ' of ${cols.length} columns: ' || COALESCE(LISTAGG(COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY COLUMN_NAME), 'table not found') AS DETAIL
     FROM BARCLAYS_HOL.INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'ANALYTICS' AND TABLE_NAME = '${table}' AND COLUMN_NAME IN (${cols.map((c) => `'${c}'`).join(", ")})`

const CATCHUP = "Or run setup/catchup/core_analytics.sql (Lab Companion > this module > catch-up script)."
const STAGING = ["STG_ACCOUNTS", "STG_CUSTOMERS", "STG_FEEDBACK", "STG_PAYMENTS"]

const pre = {
  staging: { id: "pre_staging", label: "dbt staging views exist", sql: views(STAGING), hint: `Run Build from the dbt pane (DE1). ${CATCHUP}` },
  slaMart: { id: "pre_sla_mart", label: "MART_SLA_COMPLIANCE has data", sql: rows("BARCLAYS_HOL.ANALYTICS.MART_SLA_COMPLIANCE"), hint: `Run Build from the dbt pane (DE1). ${CATCHUP}` },
  customerMart: {
    id: "pre_customer_mart",
    label: "MART_CUSTOMER_PAYMENTS has the columns DE2 needs",
    sql: columns("MART_CUSTOMER_PAYMENTS", ["CUSTOMER_ID", "RM_NAME", "SUCCESS_RATE_PCT"]),
    hint: `Finish DE1's mart and Build steps (keep the column names in the prompt). ${CATCHUP}`,
  },
  feedback: { id: "pre_feedback", label: "FEEDBACK_ENRICHED exists (sentiment and topics)", sql: views(["FEEDBACK_ENRICHED"]), hint: `Run DA2's enrichment step. ${CATCHUP}` },
  svPayments: {
    id: "pre_sv_payments",
    label: "Worked-example semantic view SV_PAYMENTS exists",
    sql: show("SHOW SEMANTIC VIEWS LIKE 'SV_PAYMENTS' IN SCHEMA BARCLAYS_HOL.ANALYTICS", "SV_PAYMENTS"),
    hint: "Run setup/catchup/semantic_view_and_agent.sql (Lab Companion > this module > catch-up script).",
  },
  retailGeo: {
    id: "pre_retail_geo",
    label: "Retail branch network and travel times ready (BARCLAYS_HOL.RETAIL)",
    sql: `SELECT COUNT(*) > 0 AS OK, COUNT(*) || ' branch-to-cell travel times' AS DETAIL FROM BARCLAYS_HOL.RETAIL.BRANCH_CELL_TRAVEL`,
    hint: "The retail data is built at provisioning. Ask your facilitator to run setup/07_retail_geo_seed.sql.",
  },
  auditPack: {
    id: "pre_audit_pack",
    label: "GOV2 audit pack ready (PAYMENTS_AUDIT_AGENT)",
    sql: show("SHOW AGENTS LIKE 'PAYMENTS_AUDIT_AGENT' IN SCHEMA BARCLAYS_HOL.AUDIT_PACK", "PAYMENTS_AUDIT_AGENT"),
    hint: "The audit pack is built at provisioning. Ask your facilitator to run setup/06_audit_pack.sql.",
  },
  svClient360: {
    id: "pre_sv_client_360",
    label: "SV_CLIENT_360 exists (DA1)",
    sql: show("SHOW SEMANTIC VIEWS LIKE 'SV_CLIENT_360' IN SCHEMA BARCLAYS_HOL.ANALYTICS", "SV_CLIENT_360"),
    hint: "Create SV_CLIENT_360 in DA1, or run the DA1 reference SQL.",
  },
  agent360: {
    id: "pre_agent_360",
    label: "CORPORATE_PAYMENTS_360 agent exists (OPS1)",
    sql: show("SHOW AGENTS LIKE 'CORPORATE_PAYMENTS_360' IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS", "Agent"),
    hint: "Create the agent in OPS1, or run the OPS1 reference SQL.",
  },
  lookup: {
    id: "pre_payment_lookup",
    label: "PAYMENT_LOOKUP tool exists (AI1)",
    sql: show("SHOW USER FUNCTIONS LIKE 'PAYMENT_LOOKUP' IN SCHEMA BARCLAYS_HOL.AGENTS", "PAYMENT_LOOKUP"),
    hint: "Build the payment lookup tool in AI1, or run the AI1 reference SQL.",
  },
  cke: {
    id: "pre_cke",
    label: "Marketplace knowledge extension installed",
    sql: show("SHOW CORTEX SEARCH SERVICES IN DATABASE SNOWFLAKE_DOCS_CKE", "Knowledge extension"),
    hint: "Ask the facilitator - setup/00 installs SNOWFLAKE_DOCS_CKE from the Marketplace.",
  },
  realtime: {
    id: "pre_realtime",
    label: "Shared interactive warehouse HOL_INTERACTIVE_WH exists",
    sql: show("SHOW WAREHOUSES LIKE 'HOL_INTERACTIVE_WH'", "HOL_INTERACTIVE_WH"),
    hint: "Created by setup/00_admin_provision.sql. Ask the facilitator to resume it for the session.",
  },
  gateway: {
    id: "pre_gateway",
    label: "Cortex AI Gateway SNOWFLAKE available",
    sql: show("SHOW AI GATEWAYS", "Gateway"),
    hint: "Cortex AI Gateway is in preview: ask the facilitator whether it's available in this region.",
  },
  notebookAccess: {
    id: "pre_notebook_access",
    label: "External access integration HOL_NOTEBOOK_ACCESS_INTEGRATION exists",
    sql: show("SHOW INTEGRATIONS LIKE 'HOL_NOTEBOOK_ACCESS_INTEGRATION'", "HOL_NOTEBOOK_ACCESS_INTEGRATION"),
    hint: "Created by setup/00_admin_provision.sql. Ask the facilitator to run it.",
  },
} satisfies Record<string, Check>

export const PREREQS: Record<string, Check[]> = {
  DE1: [CHECKS.C1[0]],
  DE2: [pre.staging, pre.slaMart, pre.customerMart],
  DA1: [pre.staging, pre.feedback, pre.svPayments],
  DA2: [pre.staging],
  DA3: [pre.retailGeo],
  OPS1: [pre.svClient360, pre.svPayments],
  OPS2: [pre.staging, pre.feedback],
  AI1: [pre.staging, pre.svPayments],
  AI2: [pre.svClient360, pre.agent360, pre.lookup, pre.cke],
  AI3: [pre.cke, pre.svClient360],
  GOV1: [pre.staging],
  GOV2: [pre.auditPack],
  DE3: [pre.realtime, pre.notebookAccess],
  GOV3: [pre.gateway, pre.notebookAccess],
}
