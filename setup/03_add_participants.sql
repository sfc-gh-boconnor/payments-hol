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

-- Let the Lab Companion (owned by HOL_ADMIN, runs with restricted caller's rights)
-- see the attendee's Cortex Code automations in their personal USER$ database (GOV2 check)
-- Account-level inherited caller grants cover personal databases created after first sign-in
GRANT INHERITED CALLER USAGE ON ALL DATABASES IN ACCOUNT TO ROLE HOL_ADMIN;
GRANT INHERITED CALLER USAGE ON ALL SCHEMAS IN ACCOUNT TO ROLE HOL_ADMIN;
GRANT INHERITED CALLER MONITOR ON ALL TASKS IN ACCOUNT TO ROLE HOL_ADMIN;
SET USER_DB = 'USER$' || $ATTENDEE;
GRANT CALLER USAGE ON DATABASE IDENTIFIER($USER_DB) TO ROLE HOL_ADMIN;
GRANT INHERITED CALLER USAGE ON ALL SCHEMAS IN DATABASE IDENTIFIER($USER_DB) TO ROLE HOL_ADMIN;
GRANT INHERITED CALLER MONITOR ON ALL TASKS IN DATABASE IDENTIFIER($USER_DB) TO ROLE HOL_ADMIN;
-- GOV3/DE3 have attendees register their own key pair. Event accounts (one attendee each)
-- grant MODIFY PROGRAMMATIC AUTHENTICATION METHODS ON USER <attendee> TO ROLE HOL_PARTICIPANT.
-- Don't do that here when several attendees share an account: anyone in HOL_PARTICIPANT could
-- add keys to another attendee's user. Instead register keys for them as an admin:
--   ALTER USER <attendee> ADD KEY PAIR GOV3_KEY PUBLIC_KEY = '<their public key>'
--     ROLE_RESTRICTION = 'HOL_PARTICIPANT' DAYS_TO_EXPIRY = 1;

-- Then set an initial password in Snowsight (Admin > Users) and share it out-of-band.
