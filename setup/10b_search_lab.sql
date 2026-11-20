-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - FACILITATOR SETUP
-- STEP 10b (OPTIONAL): CORTEX SEARCH LAB FOR MODULE AI5
--
-- Cortex Search is not yet approved at Barclays, so AI5 is optional and this step is separate.
-- Skip it (provision_account.sh: HOL_ENABLE_SEARCH=0) on accounts where Search isn't allowed;
-- AI5's prerequisite check then tells attendees to skip the module.
-- =====================================================

USE ROLE HOL_ADMIN;
CREATE SCHEMA IF NOT EXISTS BARCLAYS_HOL.SEARCH_LAB COMMENT = 'AI5 (optional): attendee Cortex Search services over call transcripts and case notes';
GRANT USAGE ON SCHEMA BARCLAYS_HOL.SEARCH_LAB TO ROLE HOL_PARTICIPANT;
GRANT CREATE CORTEX SEARCH SERVICE, CREATE TABLE, CREATE VIEW ON SCHEMA BARCLAYS_HOL.SEARCH_LAB TO ROLE HOL_PARTICIPANT;
SHOW GRANTS ON SCHEMA BARCLAYS_HOL.SEARCH_LAB;
