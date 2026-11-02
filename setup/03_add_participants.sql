-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - FACILITATOR SETUP
-- STEP 03: ADD ATTENDEES (optional - shared-account events)
-- For one-account-per-attendee events, 00 already grants HOL_ADMIN to you;
-- simply grant HOL_PARTICIPANT to the attendee user instead.
-- =====================================================

USE ROLE ACCOUNTADMIN;

-- Repeat per attendee (or generate from a list)
SET ATTENDEE = 'HOL_USER_01';

CREATE USER IF NOT EXISTS IDENTIFIER($ATTENDEE)
    DEFAULT_ROLE = HOL_PARTICIPANT
    DEFAULT_WAREHOUSE = BARCLAYS_WH
    MUST_CHANGE_PASSWORD = TRUE
    COMMENT = 'Barclays HOL attendee';
GRANT ROLE HOL_PARTICIPANT TO USER IDENTIFIER($ATTENDEE);

-- Then set an initial password in Snowsight (Admin > Users) and share it out-of-band.
