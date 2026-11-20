/**
 * The data estate shown on the Data map page and toured in C0: data products, the end-to-end
 * architecture and the keys that join products. Row counts on the page come live from the account
 * (/api/data-map); `rows` here is the fallback when the app can't see a schema.
 */

export type DataTable = { name: string; grain: string; rows: number }
export type DataProduct = {
  id: string
  name: string
  business: string
  schema: string
  summary: string
  tables: DataTable[]
  modules: string[]
  alsoWorksFor: string
}

export const DATA_PRODUCTS: DataProduct[] = [
  {
    id: "payments",
    name: "Corporate payments",
    business: "Corporate",
    schema: "BARCLAYS_HOL.RAW_DATA",
    summary: "Corporate clients, their accounts and relationship managers, and every payment they make, with schemes, SLAs, alerts and feedback. Snowflake-managed Iceberg, read-only.",
    tables: [
      { name: "PAYMENTS", grain: "one payment", rows: 50000 },
      { name: "CUSTOMERS", grain: "one corporate client", rows: 30 },
      { name: "ACCOUNTS", grain: "one client account", rows: 36 },
      { name: "RELATIONSHIP_MANAGERS", grain: "one RM", rows: 10 },
      { name: "PAYMENT_SCHEMES", grain: "one scheme (CHAPS, BACS...)", rows: 6 },
      { name: "SLA_DEFINITIONS", grain: "one SLA per scheme", rows: 6 },
      { name: "ERROR_CODES", grain: "one failure reason", rows: 20 },
      { name: "OPERATIONAL_ALERTS", grain: "one alert", rows: 1500 },
      { name: "CUSTOMER_FEEDBACK", grain: "one piece of feedback", rows: 2000 },
    ],
    modules: ["C1", "DE1", "DE2", "DE3", "DA0", "DA1", "DA2", "OPS1", "OPS2", "OPS3"],
    alsoWorksFor: "card disputes, fraud alerts, faster-payments SLAs",
  },
  {
    id: "retail",
    name: "Retail banking",
    business: "Retail",
    schema: "BARCLAYS_HOL.RAW_DATA (RB_*)",
    summary: "20,000 retail customers on real UK geography with their products, employer and pay, affordability, monthly balances and a 90-day transaction ledger. Synthetic people; Iceberg, read-only.",
    tables: [
      { name: "RB_CUSTOMERS", grain: "one retail customer", rows: 20000 },
      { name: "RB_PRODUCTS", grain: "one product in the catalogue", rows: 25 },
      { name: "RB_ACCOUNTS", grain: "one product holding", rows: 44058 },
      { name: "RB_EMPLOYMENT", grain: "one customer's income and employer", rows: 20000 },
      { name: "RB_SALARY_HISTORY", grain: "one pay change", rows: 40246 },
      { name: "RB_MONTHLY_SNAPSHOT", grain: "one customer-month", rows: 229161 },
      { name: "RB_TRANSACTIONS", grain: "one transaction", rows: 1296242 },
    ],
    modules: ["C0", "DS0", "DS1", "DS2"],
    alsoWorksFor: "attrition, next best product, affordability, fraud detection",
  },
  {
    id: "voice",
    name: "Customer voice and financial crime",
    business: "Retail",
    schema: "BARCLAYS_HOL.RAW_DATA (RB_ text) + @RETAIL.FINCRIME_EVIDENCE",
    summary: "Call transcripts, emails, complaints, fraud case notes, SAR narratives and card disputes, plus phishing screenshots and police report PDFs. Every record links to a retail customer, and fraud records to the transaction. Synthetic.",
    tables: [
      { name: "RB_CALL_TRANSCRIPTS", grain: "one call, with start and end time", rows: 1000 },
      { name: "RB_EMAILS", grain: "one customer email", rows: 300 },
      { name: "RB_COMPLAINTS", grain: "one complaint", rows: 200 },
      { name: "RB_FRAUD_CASES", grain: "one fraud investigation", rows: 300 },
      { name: "RB_SAR_NARRATIVES", grain: "one Suspicious Activity Report", rows: 60 },
      { name: "RB_DISPUTES", grain: "one card dispute", rows: 120 },
      { name: "RB_EVIDENCE_FILES", grain: "one evidence file on the stage", rows: 150 },
    ],
    modules: ["AI4", "AI5"],
    alsoWorksFor: "complaints handling, vulnerability, APP scam reimbursement, SAR quality",
  },
  {
    id: "branches",
    name: "Branch network",
    business: "Retail",
    schema: "BARCLAYS_HOL.RETAIL",
    summary: "57 branches and their ATMs on real high streets in 8 cities, branch visits, and road-network drive and walk times from every branch to the area around it.",
    tables: [
      { name: "BRANCHES", grain: "one branch", rows: 57 },
      { name: "ATMS", grain: "one ATM", rows: 142 },
      { name: "RETAIL_CUSTOMERS", grain: "one DA3 customer", rows: 20000 },
      { name: "BRANCH_VISITS", grain: "one visit", rows: 145424 },
      { name: "BRANCH_CELL_TRAVEL", grain: "branch x H3 cell x profile", rows: 193775 },
      { name: "BRANCH_ISOCHRONES", grain: "branch x minutes x profile", rows: 171 },
    ],
    modules: ["DA3"],
    alsoWorksFor: "ATM placement, mortgage branches, SME lending reach",
  },
  {
    id: "analytics",
    name: "Client 360 and analytics",
    business: "Built in the lab",
    schema: "BARCLAYS_HOL.ANALYTICS",
    summary: "What you build: dbt staging and marts, dynamic tables, the DP_SLA_COMPLIANCE Iceberg data product, semantic views and the agents that use them.",
    tables: [
      { name: "MART_CUSTOMER_PAYMENTS", grain: "one corporate client", rows: 30 },
      { name: "MART_RM_PERFORMANCE", grain: "one RM", rows: 10 },
      { name: "DP_SLA_COMPLIANCE", grain: "day x scheme", rows: 2196 },
    ],
    modules: ["DE1", "DE2", "DA1", "OPS1", "AI1", "AI2", "AI3"],
    alsoWorksFor: "KPI data products, regulatory reporting, self-serve BI",
  },
  {
    id: "governance",
    name: "Governance packs",
    business: "Every data product",
    schema: "BARCLAYS_HOL.AUDIT_PACK, COWORK_PACK",
    summary: "A ready-made audit pack for lineage and access history, and the views behind the CoWork agent. Masking, tags and the AI gateway apply across everything.",
    tables: [
      { name: "AUDIT_PACK.PAYMENT_SLA_DAILY", grain: "day x scheme", rows: 2196 },
      { name: "AUDIT_PACK.CLIENT_ACCOUNTS", grain: "one client account (masked columns)", rows: 36 },
    ],
    modules: ["GOV1", "GOV2", "GOV3"],
    alsoWorksFor: "PII controls, audit evidence, AI model access",
  },
]

/** The few keys that join data products to each other. */
export const JOIN_KEYS = [
  { from: "PAYMENTS.ORIGINATOR_ACCOUNT_ID", to: "ACCOUNTS.ACCOUNT_ID", why: "who made a corporate payment" },
  { from: "ACCOUNTS.CUSTOMER_ID", to: "CUSTOMERS.CUSTOMER_ID", why: "corporate client for an account" },
  { from: "CUSTOMERS.RM_ID", to: "RELATIONSHIP_MANAGERS.RM_ID", why: "a client's relationship manager" },
  { from: "RB_CUSTOMERS.HOME_BRANCH_ID", to: "RETAIL.BRANCHES.BRANCH_ID", why: "a retail customer's nearest branch by drive time" },
  { from: "RB_ACCOUNTS.PRODUCT_ID", to: "RB_PRODUCTS.PRODUCT_ID", why: "which product a holding is" },
  { from: "RB_EMPLOYMENT.CUSTOMER_ID", to: "RB_CUSTOMERS.CUSTOMER_ID", why: "employer and pay for a customer" },
  { from: "RB_TRANSACTIONS.ACCOUNT_ID", to: "RB_ACCOUNTS.ACCOUNT_ID", why: "the account a transaction hit" },
]

/** End-to-end platform, left to right, with a governance band underneath. */
export const ARCHITECTURE = [
  { lane: "Sources", items: [
    { name: "Synthetic source data", detail: "corporate seed data, retail generator files", modules: ["C0"] },
    { name: "Snowflake Postgres", detail: "live payment events", modules: ["DE3"] },
    { name: "Marketplace", detail: "Snowflake Docs knowledge extension", modules: ["AI3"] },
  ] },
  { lane: "Open storage", items: [
    { name: "Iceberg in RAW_DATA", detail: "Snowflake-managed, read-only sources", modules: ["C0", "C1"] },
    { name: "Postgres mirror", detail: "PAYMENTS_MIRROR, Iceberg", modules: ["DE3"] },
  ] },
  { lane: "Transform", items: [
    { name: "dbt project", detail: "staging and marts, tests", modules: ["DE1"] },
    { name: "Dynamic tables", detail: "and Pipeline Builder", modules: ["DE2"] },
    { name: "Notebooks", detail: "Python and SQL on notebook services", modules: ["DE3", "DA2", "DA3"] },
  ] },
  { lane: "Serve", items: [
    { name: "Marts and data products", detail: "ANALYTICS, DP_SLA_COMPLIANCE", modules: ["DE1", "DE2"] },
    { name: "Interactive warehouse", detail: "low-latency serving", modules: ["DE3"] },
  ] },
  { lane: "Understand", items: [
    { name: "Semantic views", detail: "business definitions", modules: ["DA1"] },
    { name: "Cortex AI SQL", detail: "sentiment, classify, extract, images and PDFs", modules: ["DA2", "AI4"] },
    { name: "ML models", detail: "experiments and the Model Registry", modules: ["DS1", "DS2"] },
    { name: "Cortex Search (optional)", detail: "not yet approved at Barclays", modules: ["AI5"] },
  ] },
  { lane: "Act", items: [
    { name: "Cortex Agents", detail: "and the MCP server", modules: ["OPS1", "OPS2", "AI1", "AI2"] },
    { name: "CoWork", detail: "dashboards, research, automations", modules: ["OPS3"] },
    { name: "Apps and reports", detail: "Streamlit, HTML reports", modules: ["DA0", "DA3"] },
  ] },
]
export const GOVERNANCE_BAND = { name: "Govern", detail: "roles and read-only sources, masking and tags, lineage and access history, the AI gateway", modules: ["GOV1", "GOV2", "GOV3"] }
