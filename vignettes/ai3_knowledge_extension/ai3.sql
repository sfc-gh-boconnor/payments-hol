-- =====================================================
-- VIGNETTE AI3: MARKETPLACE KNOWLEDGE EXTENSION (instead of Cortex Search)   (~30 min)
-- Persona: AI Builder
-- Question: "Our agents need trusted unstructured knowledge, but we are not
--            allowed to vectorise internal (PII) data yet. What can we do?"
-- Prereq:   Facilitator setup 00 (installs SNOWFLAKE_DOCS_CKE), DA1 (SV_CLIENT_360)
--
-- A Cortex Knowledge Extension (CKE) is a search service that a Marketplace
-- provider builds, hosts and refreshes. You query it through a share - no
-- internal data is embedded, indexed or sent to the provider.
-- =====================================================

USE ROLE HOL_PARTICIPANT;
USE SECONDARY ROLES NONE;   -- see exactly what an attendee sees
USE WAREHOUSE BARCLAYS_WH;

-- -----------------------------------------------------
-- AI3.1 What did we get from the Marketplace?
-- Snowsight: Data Products > Marketplace > search "Cortex Knowledge Extension"
-- (Finance publishers such as Investopedia are listed; personalised listings
--  must be requested by the account admin.)
-- -----------------------------------------------------
SHOW CORTEX SEARCH SERVICES IN DATABASE SNOWFLAKE_DOCS_CKE;
-- Note: we did not create this service, we cannot see its source table,
-- and we pay only for the queries we run.

-- -----------------------------------------------------
-- AI3.2 Query it directly
-- -----------------------------------------------------
SELECT r.value:DOCUMENT_TITLE::STRING AS TITLE,
       r.value:SOURCE_URL::STRING     AS URL,
       LEFT(r.value:CHUNK::STRING, 200) AS EXCERPT
FROM TABLE(FLATTEN(PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'SNOWFLAKE_DOCS_CKE.SHARED.CKE_SNOWFLAKE_DOCS_SERVICE',
        '{"query": "How do I apply a masking policy to a column?",
          "columns": ["DOCUMENT_TITLE", "SOURCE_URL", "CHUNK"],
          "limit": 3}')):results)) r;

-- -----------------------------------------------------
-- AI3.3 Combine governed internal data + external knowledge in one agent
-- -----------------------------------------------------
CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.PAYMENTS_PLATFORM_COPILOT
  COMMENT = 'Barclays HOL - client data (semantic view) + Snowflake docs (Marketplace knowledge extension)'
  PROFILE = '{"display_name": "Payments Platform Copilot", "color": "orange"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  instructions:
    response: >
      Be concise. When you use documentation, cite the source URL.
      Never present documentation content as if it were bank data.
    orchestration: >
      Use Client360 for any question about our clients, payments, alerts or feedback.
      Use PlatformDocs for how-to questions about Snowflake features
      (Iceberg, dynamic tables, policies, semantic views, agents).
      A question may need both, e.g. "which clients have X, and how do I monitor that?"
  tools:
    - tool_spec:
        type: cortex_analyst_text_to_sql
        name: Client360
        description: Corporate client payments health, alerts and feedback sentiment.
    - tool_spec:
        type: cortex_search
        name: PlatformDocs
        description: Official Snowflake documentation from a Marketplace Cortex Knowledge Extension.
  tool_resources:
    Client360:
      semantic_view: BARCLAYS_HOL.ANALYTICS.SV_CLIENT_360
      execution_environment:
        type: warehouse
        warehouse: BARCLAYS_WH
    PlatformDocs:
      name: SNOWFLAKE_DOCS_CKE.SHARED.CKE_SNOWFLAKE_DOCS_SERVICE
      max_results: 4
      title_column: DOCUMENT_TITLE
      id_column: SOURCE_URL
  $$;

-- -----------------------------------------------------
-- AI3.4 Try it in Snowflake CoWork ("Payments Platform Copilot"):
--   "Which 3 clients have the most open critical alerts, and how could I build
--    a dynamic table that keeps that list up to date?"
--   "How do Snowflake-managed Iceberg tables differ from ones using an external volume?"
-- Or from SQL:
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'SNOWFLAKE_INTELLIGENCE.AGENTS.PAYMENTS_PLATFORM_COPILOT',
  $${"messages":[{"role":"user","content":[{"type":"text","text":"Which 3 clients have the most open critical alerts, and how could I build a dynamic table to keep that list up to date?"}]}]}$$
) AS RESPONSE;
-- -----------------------------------------------------

-- Discussion: the same pattern works for licensed external content already
-- used by the investment bank (LSEG, FactSet, S&P - several publish CKEs),
-- giving retail and corporate banking AI over trusted text with no PII risk.

SELECT 'AI3 complete' AS STATUS;
