-- =====================================================
-- BARCLAYS HANDS-ON LAB
-- STEP 1: ENVIRONMENT SETUP
-- =====================================================

-- Create the lab database
CREATE OR REPLACE DATABASE BARCLAYS_HOL
    COMMENT = 'Barclays Payments Data Product - Hands-on Lab';

-- Create organised schemas
CREATE OR REPLACE SCHEMA BARCLAYS_HOL.RAW_DATA
    COMMENT = 'Raw payments and operations data';

CREATE OR REPLACE SCHEMA BARCLAYS_HOL.ANALYTICS
    COMMENT = 'dbt-transformed and AI-enriched views';

-- Create warehouse optimised for the lab
CREATE OR REPLACE WAREHOUSE BARCLAYS_WH
    WITH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for Barclays HOL';

-- Activate context
USE WAREHOUSE BARCLAYS_WH;
USE DATABASE BARCLAYS_HOL;
USE SCHEMA RAW_DATA;

-- Verify Cortex AI is available
SELECT SNOWFLAKE.CORTEX.SENTIMENT('Payment processed successfully') AS cortex_test;

-- Show available compute pools (needed for Streamlit app in Step 7)
-- Note the pool name — you'll set it in App Settings when you run the dashboard
SHOW COMPUTE POOLS;

SELECT '✅ Setup complete' AS STATUS;
