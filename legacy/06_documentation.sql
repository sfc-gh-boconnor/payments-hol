-- =====================================================
-- BARCLAYS HANDS-ON LAB
-- STEP 6: DOCUMENT & DESCRIBE
-- Add metadata so objects are discoverable in the
-- Snowflake Data Catalog / Snowsight
-- =====================================================

USE WAREHOUSE BARCLAYS_WH;
USE DATABASE BARCLAYS_HOL;

-- =====================================================
-- 6.1: Document raw tables
-- =====================================================

COMMENT ON TABLE RAW_DATA.RELATIONSHIP_MANAGERS IS
    'Relationship managers assigned to corporate clients. Source: HR / CRM (Salesforce). Refreshed on staff changes. Owner: HR Operations.';

COMMENT ON TABLE RAW_DATA.CUSTOMERS IS
    'Corporate client entities with KYC status and sector classification. Source: Core Banking / KYC System. Refreshed daily. Owner: Client Onboarding.';

COMMENT ON TABLE RAW_DATA.ACCOUNTS IS
    'Bank accounts: domestic (sort code) and international (IBAN/BIC). Source: Core Banking / Account Ledger. Real-time refresh. Owner: Account Services.';

COMMENT ON TABLE RAW_DATA.PAYMENT_SCHEMES IS
    'Payment scheme reference data: settlement cycles, value limits, cutoff times. Source: Payments Product Configuration. Owner: Payments Product.';

COMMENT ON TABLE RAW_DATA.ERROR_CODES IS
    'Payment error code catalog with categories (routing, validation, compliance, connectivity, timeout) and retry eligibility. Source: Payments Gateway. Owner: Payments Engineering.';

COMMENT ON TABLE RAW_DATA.PAYMENTS IS
    'Raw inbound payment transactions with account-level originator/beneficiary references. Source: Payments Processing Engine. Refreshed real-time. Owner: Payments Operations.';

COMMENT ON TABLE RAW_DATA.CUSTOMER_FEEDBACK IS
    'Customer feedback on payment services with optional payment transaction link. Source: CRM / Qualtrics. Refreshed hourly. Owner: Customer Experience.';

COMMENT ON TABLE RAW_DATA.SLA_DEFINITIONS IS
    'Service Level Agreement thresholds per payment scheme. Source: Service Management / SLA Register. Reviewed quarterly. Owner: Payments Operations.';

COMMENT ON TABLE RAW_DATA.OPERATIONAL_ALERTS IS
    'Operational alerts from payments monitoring with optional payment transaction link. Source: Monitoring Platform (Splunk/Dynatrace). Real-time. Owner: Payments Operations.';

-- =====================================================
-- 6.2: Document key columns on PAYMENTS
-- =====================================================

COMMENT ON COLUMN RAW_DATA.PAYMENTS.PAYMENT_ID              IS 'Unique identifier for each payment transaction.';
COMMENT ON COLUMN RAW_DATA.PAYMENTS.ORIGINATOR_ACCOUNT_ID   IS 'FK to ACCOUNTS. The account that initiated the payment.';
COMMENT ON COLUMN RAW_DATA.PAYMENTS.BENEFICIARY_ACCOUNT_ID  IS 'FK to ACCOUNTS. The account that receives the payment.';
COMMENT ON COLUMN RAW_DATA.PAYMENTS.PAYMENT_TYPE            IS 'Payment scheme: SWIFT, BACS, CHAPS, FASTER_PAYMENTS, SEPA, WIRE_TRANSFER. FK to PAYMENT_SCHEMES.';
COMMENT ON COLUMN RAW_DATA.PAYMENTS.STATUS                  IS 'Current payment status: COMPLETED, PENDING, FAILED, RETURNED.';
COMMENT ON COLUMN RAW_DATA.PAYMENTS.PROCESSING_TIME_MS      IS 'End-to-end processing time in milliseconds. Used for SLA compliance measurement.';
COMMENT ON COLUMN RAW_DATA.PAYMENTS.AMOUNT                  IS 'Payment amount in the transaction currency.';
COMMENT ON COLUMN RAW_DATA.PAYMENTS.FX_RATE                 IS 'Exchange rate for cross-currency payments (SWIFT, SEPA). NULL for domestic GBP payments.';
COMMENT ON COLUMN RAW_DATA.PAYMENTS.ERROR_CODE              IS 'FK to ERROR_CODES. Populated on ~5% of payments that encountered errors.';
COMMENT ON COLUMN RAW_DATA.PAYMENTS.SETTLEMENT_DATE         IS 'Expected settlement date based on scheme settlement cycle.';

-- =====================================================
-- 6.3: Document key columns on CUSTOMERS
-- =====================================================

COMMENT ON COLUMN RAW_DATA.CUSTOMERS.CUSTOMER_ID   IS 'Unique corporate client identifier.';
COMMENT ON COLUMN RAW_DATA.CUSTOMERS.SECTOR         IS 'Industry sector: Manufacturing, Financial Services, Trading, Logistics, etc.';
COMMENT ON COLUMN RAW_DATA.CUSTOMERS.KYC_STATUS     IS 'Know Your Customer status: APPROVED, PENDING_REVIEW, EXPIRED.';
COMMENT ON COLUMN RAW_DATA.CUSTOMERS.RM_ID          IS 'FK to RELATIONSHIP_MANAGERS. Assigned relationship manager.';

-- =====================================================
-- 6.4: Document key columns on ACCOUNTS
-- =====================================================

COMMENT ON COLUMN RAW_DATA.ACCOUNTS.SORT_CODE       IS 'UK sort code. Populated for domestic GBP accounts only.';
COMMENT ON COLUMN RAW_DATA.ACCOUNTS.IBAN            IS 'International Bank Account Number. Populated for international accounts.';
COMMENT ON COLUMN RAW_DATA.ACCOUNTS.ACCOUNT_TYPE    IS 'Account type: CURRENT, SETTLEMENT, NOSTRO, VOSTRO.';

-- =====================================================
-- 6.5: Document dbt mart tables
-- =====================================================

COMMENT ON TABLE ANALYTICS.MART_PAYMENT_KPIS IS
    'dbt mart: daily payment KPIs aggregated by payment type and region. Includes success rates, volumes, and processing time percentiles.';

COMMENT ON TABLE ANALYTICS.MART_SLA_COMPLIANCE IS
    'dbt mart: daily SLA compliance status per payment type. Joins KPIs against SLA_DEFINITIONS thresholds. Flags COMPLIANT, AT RISK, or BREACH.';

-- =====================================================
-- 6.6: Document AI-enriched table
-- =====================================================

COMMENT ON TABLE ANALYTICS.FEEDBACK_ENRICHED IS
    'Cortex AI-enriched customer feedback. Includes sentiment scores (SNOWFLAKE.CORTEX.SENTIMENT), topic classification (SNOWFLAKE.CORTEX.CLASSIFY_TEXT), and customer/RM context from the entity model.';

-- =====================================================
-- 6.7: Document Semantic View
-- =====================================================

COMMENT ON SEMANTIC VIEW ANALYTICS.SV_PAYMENTS IS
    'Production Semantic View for payments operations. 3 logical tables, 1 relationship, 16 facts, 12 dimensions, 7 metrics, 8 verified queries. Used by PAYMENTS_ASSISTANT agent in CoWork.';

-- =====================================================
-- 6.8: Verify all comments are visible
-- =====================================================

SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE,
    COMMENT
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN ('RAW_DATA','ANALYTICS')
  AND COMMENT IS NOT NULL
ORDER BY TABLE_SCHEMA, TABLE_NAME;

-- Column comments on PAYMENTS
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    COMMENT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'RAW_DATA'
  AND TABLE_NAME   = 'PAYMENTS'
  AND COMMENT IS NOT NULL
ORDER BY ORDINAL_POSITION;

SELECT '✅ Documentation complete — objects now discoverable in Snowsight Data Catalog' AS STATUS;
