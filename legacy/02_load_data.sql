-- =====================================================
-- BARCLAYS HANDS-ON LAB
-- STEP 2: LOAD PAYMENTS DATA
-- Generates synthetic data across 9 tables
-- =====================================================

USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.RAW_DATA;

-- =====================================================
-- 2.1: REFERENCE DATA
-- =====================================================

-- Payment Schemes (source: payments product configuration)
CREATE OR REPLACE TABLE PAYMENT_SCHEMES (
    SCHEME_CODE        VARCHAR(30),
    SCHEME_NAME        VARCHAR(100),
    SETTLEMENT_CYCLE   VARCHAR(20),
    IS_DOMESTIC        BOOLEAN,
    MAX_VALUE_GBP      NUMBER(15,2),
    CUTOFF_TIME        TIME,
    OPERATING_CURRENCY VARCHAR(5)
);

INSERT INTO PAYMENT_SCHEMES VALUES
('CHAPS',            'Clearing House Automated Payment System', 'SAME_DAY',   TRUE,  NULL,      '15:45', 'GBP'),
('FASTER_PAYMENTS',  'Faster Payments Service',                 'REAL_TIME',  TRUE,  250000.00, NULL,    'GBP'),
('BACS',             'Bankers Automated Clearing Services',     'T_PLUS_2',   TRUE,  NULL,      '22:00', 'GBP'),
('SWIFT',            'Society for Worldwide Interbank Financial Telecommunication', 'T_PLUS_2', FALSE, NULL, '16:00', 'MULTI'),
('SEPA',             'Single Euro Payments Area',               'T_PLUS_1',   FALSE, NULL,      '14:00', 'EUR'),
('WIRE_TRANSFER',    'Domestic Wire Transfer',                  'SAME_DAY',   TRUE,  NULL,      '16:30', 'GBP');

SELECT * FROM PAYMENT_SCHEMES;

-- Error Codes (source: payments gateway)
CREATE OR REPLACE TABLE ERROR_CODES (
    ERROR_CODE        VARCHAR(10),
    ERROR_DESCRIPTION VARCHAR(200),
    ERROR_CATEGORY    VARCHAR(50),
    IS_RETRYABLE      BOOLEAN
);

INSERT INTO ERROR_CODES VALUES
('ERR001', 'Beneficiary account closed',                  'VALIDATION',   FALSE),
('ERR002', 'Insufficient funds in originator account',    'VALIDATION',   TRUE),
('ERR003', 'Invalid sort code',                           'ROUTING',      FALSE),
('ERR004', 'Invalid IBAN format',                         'ROUTING',      FALSE),
('ERR005', 'BIC not recognised by SWIFT network',         'ROUTING',      FALSE),
('ERR006', 'Payment exceeds scheme value limit',          'VALIDATION',   FALSE),
('ERR007', 'Duplicate payment reference detected',        'VALIDATION',   TRUE),
('ERR008', 'Sanctions screening hold',                    'COMPLIANCE',   FALSE),
('ERR009', 'Beneficiary name mismatch (CoP failure)',     'VALIDATION',   TRUE),
('ERR010', 'Clearing house connectivity timeout',         'CONNECTIVITY', TRUE),
('ERR011', 'Settlement file rejected by scheme',          'ROUTING',      TRUE),
('ERR012', 'Cutoff time exceeded for scheme',             'TIMEOUT',      TRUE),
('ERR013', 'Currency conversion service unavailable',     'CONNECTIVITY', TRUE),
('ERR014', 'Originator account frozen — compliance hold', 'COMPLIANCE',   FALSE),
('ERR015', 'Beneficiary bank rejected — account dormant', 'VALIDATION',   FALSE),
('ERR016', 'Message format validation failure (MT103)',   'VALIDATION',   TRUE),
('ERR017', 'Nostro account balance insufficient',         'VALIDATION',   TRUE),
('ERR018', 'Payment recalled by originator',              'VALIDATION',   FALSE),
('ERR019', 'Rate limit exceeded on API channel',          'CONNECTIVITY', TRUE),
('ERR020', 'Internal processing timeout',                 'TIMEOUT',      TRUE);

SELECT * FROM ERROR_CODES;

-- =====================================================
-- 2.2: ENTITY DATA
-- =====================================================

-- Relationship Managers (source: HR / CRM)
CREATE OR REPLACE TABLE RELATIONSHIP_MANAGERS (
    RM_ID       VARCHAR(10),
    RM_NAME     VARCHAR(200),
    RM_EMAIL    VARCHAR(200),
    TEAM        VARCHAR(50),
    REGION      VARCHAR(30),
    START_DATE  DATE
);

INSERT INTO RELATIONSHIP_MANAGERS VALUES
('RM001', 'Sarah Mitchell',    'sarah.mitchell@barclays.co.uk',    'Corporate Banking',    'UK',       '2018-03-15'),
('RM002', 'James Worthington', 'james.worthington@barclays.co.uk', 'Corporate Banking',    'UK',       '2016-09-01'),
('RM003', 'Priya Sharma',      'priya.sharma@barclays.co.uk',      'Institutional Banking','UK',       '2019-07-22'),
('RM004', 'Thomas Adebayo',    'thomas.adebayo@barclays.co.uk',    'Corporate Banking',    'EMEA',     '2020-01-10'),
('RM005', 'Elena Vasquez',     'elena.vasquez@barclays.co.uk',     'SME Banking',          'UK',       '2021-04-05'),
('RM006', 'David Chen',        'david.chen@barclays.co.uk',        'Institutional Banking','APAC',     '2017-11-18'),
('RM007', 'Fiona MacLeod',     'fiona.macleod@barclays.co.uk',     'Corporate Banking',    'UK',       '2019-02-28'),
('RM008', 'Raj Patel',         'raj.patel@barclays.co.uk',         'SME Banking',          'UK',       '2022-06-14'),
('RM009', 'Catherine Dubois',  'catherine.dubois@barclays.co.uk',  'Corporate Banking',    'EMEA',     '2020-08-03'),
('RM010', 'Michael O''Brien',  'michael.obrien@barclays.co.uk',    'Corporate Banking',    'Americas', '2018-12-01');

SELECT * FROM RELATIONSHIP_MANAGERS;

-- Customers (source: core banking / KYC)
CREATE OR REPLACE TABLE CUSTOMERS (
    CUSTOMER_ID     VARCHAR(15),
    CUSTOMER_NAME   VARCHAR(200),
    SECTOR          VARCHAR(50),
    COUNTRY         VARCHAR(3),
    ONBOARDING_DATE DATE,
    KYC_STATUS      VARCHAR(20),
    RM_ID           VARCHAR(10)
);

INSERT INTO CUSTOMERS VALUES
('CUST00001', 'Acme Corp',                'Manufacturing',      'GBR', '2015-06-12', 'APPROVED',       'RM001'),
('CUST00002', 'Global Trading Ltd',       'Trading',            'GBR', '2017-03-22', 'APPROVED',       'RM001'),
('CUST00003', 'Smith & Partners',         'Legal Services',     'GBR', '2019-01-08', 'APPROVED',       'RM002'),
('CUST00004', 'Northern Industries',      'Manufacturing',      'GBR', '2016-11-30', 'APPROVED',       'RM002'),
('CUST00005', 'Atlantic Shipping Co',     'Logistics',          'GBR', '2018-04-15', 'APPROVED',       'RM003'),
('CUST00006', 'EuroTech GmbH',           'Technology',          'DEU', '2020-02-20', 'APPROVED',       'RM004'),
('CUST00007', 'Pacific Holdings',         'Financial Services', 'SGP', '2019-08-11', 'APPROVED',       'RM006'),
('CUST00008', 'Delta Manufacturing',      'Manufacturing',      'GBR', '2021-05-03', 'APPROVED',       'RM005'),
('CUST00009', 'Royal Trust PLC',          'Financial Services', 'GBR', '2014-09-28', 'APPROVED',       'RM003'),
('CUST00010', 'Metro Services Ltd',       'Professional Services','GBR','2018-07-17', 'APPROVED',       'RM007'),
('CUST00011', 'Crown Logistics',          'Logistics',          'GBR', '2020-10-05', 'APPROVED',       'RM005'),
('CUST00012', 'Harbour Finance',          'Financial Services', 'GBR', '2016-01-19', 'APPROVED',       'RM003'),
('CUST00013', 'Sterling Solutions',       'Consulting',         'GBR', '2019-12-02', 'APPROVED',       'RM007'),
('CUST00014', 'Thames Trading',           'Trading',            'GBR', '2017-06-25', 'APPROVED',       'RM001'),
('CUST00015', 'Oxford Investments',       'Financial Services', 'GBR', '2015-03-14', 'APPROVED',       'RM002'),
('CUST00016', 'Cambridge Consulting',     'Consulting',         'GBR', '2020-04-08', 'APPROVED',       'RM008'),
('CUST00017', 'Frankfurt Industriebank',  'Financial Services', 'DEU', '2018-11-22', 'APPROVED',       'RM004'),
('CUST00018', 'Marseille Logistics SAS',  'Logistics',          'FRA', '2021-01-15', 'APPROVED',       'RM009'),
('CUST00019', 'New York Capital Partners','Financial Services',  'USA', '2019-05-30', 'APPROVED',       'RM010'),
('CUST00020', 'Dublin Tech Holdings',     'Technology',          'IRL', '2022-02-14', 'APPROVED',       'RM009'),
('CUST00021', 'Manchester Textiles',      'Manufacturing',       'GBR', '2016-08-09', 'APPROVED',       'RM005'),
('CUST00022', 'Edinburgh Capital',        'Financial Services',  'GBR', '2017-04-18', 'APPROVED',       'RM007'),
('CUST00023', 'Birmingham Motors',        'Automotive',          'GBR', '2019-09-23', 'APPROVED',       'RM008'),
('CUST00024', 'Liverpool Freight',        'Logistics',           'GBR', '2020-06-11', 'APPROVED',       'RM005'),
('CUST00025', 'Singapore Commodities Pte','Trading',             'SGP', '2018-02-07', 'APPROVED',       'RM006'),
('CUST00026', 'Brussels Pharma NV',       'Pharmaceuticals',     'BEL', '2021-07-19', 'APPROVED',       'RM009'),
('CUST00027', 'Tokyo Electronics KK',     'Technology',          'JPN', '2019-11-04', 'APPROVED',       'RM006'),
('CUST00028', 'Midlands Engineering',     'Manufacturing',       'GBR', '2015-12-30', 'PENDING_REVIEW', 'RM002'),
('CUST00029', 'Geneva Wealth SA',         'Financial Services',  'CHE', '2020-03-25', 'APPROVED',       'RM004'),
('CUST00030', 'Leeds Property Group',     'Real Estate',         'GBR', '2022-01-08', 'APPROVED',       'RM008');

SELECT SECTOR, COUNT(*) AS CUSTOMER_COUNT FROM CUSTOMERS GROUP BY SECTOR ORDER BY CUSTOMER_COUNT DESC;

-- Accounts (source: core banking / account ledger)
CREATE OR REPLACE TABLE ACCOUNTS (
    ACCOUNT_ID     VARCHAR(15),
    CUSTOMER_ID    VARCHAR(15),
    SORT_CODE      VARCHAR(8),
    ACCOUNT_NUMBER VARCHAR(10),
    IBAN           VARCHAR(34),
    BIC            VARCHAR(11),
    CURRENCY       VARCHAR(3),
    ACCOUNT_TYPE   VARCHAR(30),
    STATUS         VARCHAR(20),
    OPENED_DATE    DATE
);

-- Domestic GBP accounts (sort code + account number)
INSERT INTO ACCOUNTS VALUES
('ACC00001', 'CUST00001', '20-00-00', '41234567', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2015-06-12'),
('ACC00002', 'CUST00001', '20-00-00', '41234590', NULL, NULL, 'GBP', 'SETTLEMENT', 'ACTIVE', '2016-01-10'),
('ACC00003', 'CUST00002', '20-00-01', '52345678', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2017-03-22'),
('ACC00004', 'CUST00003', '20-11-00', '63456789', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2019-01-08'),
('ACC00005', 'CUST00004', '20-11-01', '74567890', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2016-11-30'),
('ACC00006', 'CUST00004', '20-11-01', '74567891', NULL, NULL, 'GBP', 'SETTLEMENT', 'ACTIVE', '2017-03-15'),
('ACC00007', 'CUST00005', '20-22-00', '85678901', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2018-04-15'),
('ACC00008', 'CUST00008', '20-22-01', '91234567', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2021-05-03'),
('ACC00009', 'CUST00009', '20-33-00', '12345678', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2014-09-28'),
('ACC00010', 'CUST00009', '20-33-00', '12345680', NULL, NULL, 'GBP', 'SETTLEMENT', 'ACTIVE', '2015-02-01'),
('ACC00011', 'CUST00010', '20-33-01', '23456789', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2018-07-17'),
('ACC00012', 'CUST00011', '20-44-00', '34567890', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2020-10-05'),
('ACC00013', 'CUST00012', '20-44-01', '45678901', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2016-01-19'),
('ACC00014', 'CUST00013', '20-55-00', '56789012', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2019-12-02'),
('ACC00015', 'CUST00014', '20-55-01', '67890123', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2017-06-25'),
('ACC00016', 'CUST00015', '20-66-00', '78901234', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2015-03-14'),
('ACC00017', 'CUST00016', '20-66-01', '89012345', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2020-04-08'),
('ACC00018', 'CUST00021', '20-77-00', '90123456', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2016-08-09'),
('ACC00019', 'CUST00022', '20-77-01', '01234567', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2017-04-18'),
('ACC00020', 'CUST00023', '20-88-00', '11223344', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2019-09-23'),
('ACC00021', 'CUST00024', '20-88-01', '22334455', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2020-06-11'),
('ACC00022', 'CUST00028', '20-99-00', '33445566', NULL, NULL, 'GBP', 'CURRENT',    'DORMANT','2015-12-30'),
('ACC00023', 'CUST00030', '20-99-01', '44556677', NULL, NULL, 'GBP', 'CURRENT',    'ACTIVE', '2022-01-08');

-- International accounts (IBAN + BIC)
INSERT INTO ACCOUNTS VALUES
('ACC00030', 'CUST00006', NULL, NULL, 'DE89370400440532013000',     'COBADEFFXXX', 'EUR', 'CURRENT',   'ACTIVE', '2020-02-20'),
('ACC00031', 'CUST00006', NULL, NULL, 'DE89370400440532013001',     'COBADEFFXXX', 'EUR', 'SETTLEMENT','ACTIVE', '2020-06-01'),
('ACC00032', 'CUST00007', NULL, NULL, 'SG53OCBC0000012345678',      'OCBCSGSGXXX', 'USD', 'CURRENT',   'ACTIVE', '2019-08-11'),
('ACC00033', 'CUST00017', NULL, NULL, 'DE44500105175407324931',     'INGDDEFFXXX', 'EUR', 'CURRENT',   'ACTIVE', '2018-11-22'),
('ACC00034', 'CUST00018', NULL, NULL, 'FR7630006000011234567890189','BNPAFRPPXXX', 'EUR', 'CURRENT',   'ACTIVE', '2021-01-15'),
('ACC00035', 'CUST00019', NULL, NULL, 'US33100060001234567891',     'CHABORJXXX',  'USD', 'CURRENT',   'ACTIVE', '2019-05-30'),
('ACC00036', 'CUST00020', NULL, NULL, 'IE29AIBK93115212345678',     'AABORIEJXXX', 'EUR', 'CURRENT',   'ACTIVE', '2022-02-14'),
('ACC00037', 'CUST00025', NULL, NULL, 'SG53OCBC0000098765432',      'OCBCSGSGXXX', 'USD', 'CURRENT',   'ACTIVE', '2018-02-07'),
('ACC00038', 'CUST00026', NULL, NULL, 'BE68539007547034',           'BABORBBXXX',  'EUR', 'CURRENT',   'ACTIVE', '2021-07-19'),
('ACC00039', 'CUST00027', NULL, NULL, 'JP9876543210987654321',      'BOABORJTXXX', 'USD', 'CURRENT',   'ACTIVE', '2019-11-04'),
('ACC00040', 'CUST00029', NULL, NULL, 'CH9300762011623852957',      'UBABORSWXXX', 'EUR', 'CURRENT',   'ACTIVE', '2020-03-25');

-- Nostro accounts
INSERT INTO ACCOUNTS VALUES
('ACC00050', 'CUST00009', NULL, NULL, 'GB29NWBK60161331926819', 'BABORGLGXXX', 'EUR', 'NOSTRO', 'ACTIVE', '2014-09-28'),
('ACC00051', 'CUST00009', NULL, NULL, 'GB82WEST12345698765432', 'BABORGLGXXX', 'USD', 'NOSTRO', 'ACTIVE', '2014-09-28');

SELECT CURRENCY, ACCOUNT_TYPE, COUNT(*) AS ACCOUNT_COUNT
FROM ACCOUNTS GROUP BY CURRENCY, ACCOUNT_TYPE ORDER BY CURRENCY, ACCOUNT_TYPE;

-- =====================================================
-- 2.3: PAYMENTS (50,000 transactions)
-- =====================================================

CREATE OR REPLACE TABLE PAYMENTS (
    PAYMENT_ID             VARCHAR(20),
    PAYMENT_DATE           TIMESTAMP,
    ORIGINATOR_ACCOUNT_ID  VARCHAR(15),
    BENEFICIARY_ACCOUNT_ID VARCHAR(15),
    PAYMENT_TYPE           VARCHAR(30),
    CHANNEL                VARCHAR(20),
    CURRENCY               VARCHAR(3),
    AMOUNT                 NUMBER(15,2),
    FX_RATE                NUMBER(10,6),
    STATUS                 VARCHAR(20),
    PROCESSING_TIME_MS     NUMBER,
    ERROR_CODE             VARCHAR(10),
    REGION                 VARCHAR(30),
    SETTLEMENT_DATE        DATE
);

INSERT INTO PAYMENTS
WITH domestic_accounts AS (
    SELECT ACCOUNT_ID, ROW_NUMBER() OVER (ORDER BY ACCOUNT_ID) - 1 AS IDX, COUNT(*) OVER () AS CNT
    FROM ACCOUNTS WHERE CURRENCY = 'GBP'
),
intl_accounts AS (
    SELECT ACCOUNT_ID, ROW_NUMBER() OVER (ORDER BY ACCOUNT_ID) - 1 AS IDX, COUNT(*) OVER () AS CNT
    FROM ACCOUNTS WHERE CURRENCY IN ('EUR','USD')
),
domestic_arr AS (
    SELECT ARRAY_AGG(ACCOUNT_ID) WITHIN GROUP (ORDER BY IDX) AS IDS, MAX(CNT) AS CNT FROM domestic_accounts
),
intl_arr AS (
    SELECT ARRAY_AGG(ACCOUNT_ID) WITHIN GROUP (ORDER BY IDX) AS IDS, MAX(CNT) AS CNT FROM intl_accounts
),
base AS (
    SELECT
        SEQ4() AS RN,
        -- ~70% domestic, ~30% international
        CASE WHEN UNIFORM(1, 10, RANDOM()) <= 7
             THEN ARRAY_CONSTRUCT('CHAPS','FASTER_PAYMENTS','BACS','WIRE_TRANSFER')[UNIFORM(0,3,RANDOM())]::VARCHAR
             ELSE ARRAY_CONSTRUCT('SWIFT','SEPA')[UNIFORM(0,1,RANDOM())]::VARCHAR
        END AS PAYMENT_TYPE,
        DATEADD('minute', -UNIFORM(1, 525600, RANDOM()), CURRENT_TIMESTAMP()) AS PAYMENT_DATE,
        ARRAY_CONSTRUCT('API','Online Banking','Branch','File Upload','Mobile')[UNIFORM(0,4,RANDOM())]::VARCHAR AS CHANNEL,
        -- ~96% completed, ~2% pending, ~1% failed, ~1% returned
        CASE WHEN UNIFORM(1,1000,RANDOM()) <= 960 THEN 'COMPLETED'
             WHEN UNIFORM(1,1000,RANDOM()) <= 625 THEN 'PENDING'
             WHEN UNIFORM(1,1000,RANDOM()) <= 600 THEN 'FAILED'
             ELSE 'RETURNED'
        END AS STATUS,
        UNIFORM(1, 1000, RANDOM()) AS PROC_RAND,
        ARRAY_CONSTRUCT('UK','UK','UK','EMEA','APAC','Americas')[UNIFORM(0,5,RANDOM())]::VARCHAR AS REGION,
        UNIFORM(0, 99999, RANDOM()) AS ORIG_RAND,
        UNIFORM(0, 99999, RANDOM()) AS BENE_RAND
    FROM TABLE(GENERATOR(ROWCOUNT => 50000))
)
SELECT
    'PAY' || LPAD(b.RN::VARCHAR, 10, '0') AS PAYMENT_ID,
    b.PAYMENT_DATE,
    CASE WHEN b.PAYMENT_TYPE IN ('CHAPS','FASTER_PAYMENTS','BACS','WIRE_TRANSFER')
         THEN d.IDS[MOD(b.ORIG_RAND, d.CNT)]::VARCHAR
         ELSE i.IDS[MOD(b.ORIG_RAND, i.CNT)]::VARCHAR
    END AS ORIGINATOR_ACCOUNT_ID,
    CASE WHEN b.PAYMENT_TYPE IN ('CHAPS','FASTER_PAYMENTS','BACS','WIRE_TRANSFER')
         THEN d.IDS[MOD(b.BENE_RAND, d.CNT)]::VARCHAR
         ELSE i.IDS[MOD(b.BENE_RAND, i.CNT)]::VARCHAR
    END AS BENEFICIARY_ACCOUNT_ID,
    b.PAYMENT_TYPE,
    b.CHANNEL,
    CASE WHEN b.PAYMENT_TYPE = 'SEPA' THEN 'EUR'
         WHEN b.PAYMENT_TYPE = 'SWIFT' THEN ARRAY_CONSTRUCT('GBP','EUR','USD')[UNIFORM(0,2,RANDOM())]::VARCHAR
         ELSE 'GBP'
    END AS CURRENCY,
    ROUND(UNIFORM(100, 5000000, RANDOM())::FLOAT, 2) AS AMOUNT,
    CASE WHEN b.PAYMENT_TYPE = 'SEPA'  THEN ROUND(0.85 + UNIFORM(-500, 500, RANDOM())::FLOAT / 10000, 6)
         WHEN b.PAYMENT_TYPE = 'SWIFT' THEN ROUND(1.0 + UNIFORM(-2000, 2000, RANDOM())::FLOAT / 10000, 6)
         ELSE NULL
    END AS FX_RATE,
    b.STATUS,
    -- Scheme-specific processing times (squared random = realistic long tail)
    CASE WHEN b.PAYMENT_TYPE = 'FASTER_PAYMENTS' THEN  50 + ROUND(POW(b.PROC_RAND / 1000.0, 2) * 1500)
         WHEN b.PAYMENT_TYPE = 'CHAPS'            THEN 200 + ROUND(POW(b.PROC_RAND / 1000.0, 2) * 4000)
         WHEN b.PAYMENT_TYPE = 'BACS'             THEN 100 + ROUND(POW(b.PROC_RAND / 1000.0, 2) * 2000)
         WHEN b.PAYMENT_TYPE = 'WIRE_TRANSFER'    THEN 300 + ROUND(POW(b.PROC_RAND / 1000.0, 2) * 5000)
         WHEN b.PAYMENT_TYPE = 'SEPA'             THEN 150 + ROUND(POW(b.PROC_RAND / 1000.0, 2) * 3000)
         WHEN b.PAYMENT_TYPE = 'SWIFT'            THEN 500 + ROUND(POW(b.PROC_RAND / 1000.0, 2) * 25000)
    END AS PROCESSING_TIME_MS,
    -- Error codes: FAILED/RETURNED always have one; COMPLETED/PENDING never do
    CASE WHEN b.STATUS IN ('FAILED','RETURNED')
              THEN 'ERR' || LPAD(UNIFORM(1,20,RANDOM())::VARCHAR, 3, '0')
         ELSE NULL
    END AS ERROR_CODE,
    b.REGION,
    CASE WHEN b.PAYMENT_TYPE IN ('FASTER_PAYMENTS')    THEN b.PAYMENT_DATE::DATE
         WHEN b.PAYMENT_TYPE IN ('CHAPS','WIRE_TRANSFER') THEN b.PAYMENT_DATE::DATE
         WHEN b.PAYMENT_TYPE IN ('SEPA')               THEN DATEADD('day', 1, b.PAYMENT_DATE::DATE)
         WHEN b.PAYMENT_TYPE IN ('BACS','SWIFT')       THEN DATEADD('day', 2, b.PAYMENT_DATE::DATE)
    END AS SETTLEMENT_DATE
FROM base b
CROSS JOIN domestic_arr d
CROSS JOIN intl_arr i;

SELECT PAYMENT_TYPE, COUNT(*) AS TXN_COUNT, ROUND(AVG(AMOUNT),2) AS AVG_AMOUNT
FROM PAYMENTS GROUP BY PAYMENT_TYPE ORDER BY TXN_COUNT DESC;

-- =====================================================
-- 2.4: CUSTOMER FEEDBACK (2,000 rows)
-- =====================================================

CREATE OR REPLACE TABLE CUSTOMER_FEEDBACK (
    FEEDBACK_ID      VARCHAR(15),
    FEEDBACK_DATE    TIMESTAMP,
    CUSTOMER_ID      VARCHAR(15),
    PAYMENT_ID       VARCHAR(20),
    FEEDBACK_CHANNEL VARCHAR(30),
    FEEDBACK_TEXT    VARCHAR(1000),
    PAYMENT_TYPE     VARCHAR(30),
    RATING           NUMBER(1)
);

INSERT INTO CUSTOMER_FEEDBACK
WITH cust_arr AS (
    SELECT ARRAY_AGG(CUSTOMER_ID) WITHIN GROUP (ORDER BY CUSTOMER_ID) AS IDS,
           COUNT(*) AS CNT
    FROM CUSTOMERS
),
pay_arr AS (
    SELECT ARRAY_AGG(PAYMENT_ID) AS IDS, COUNT(*) AS CNT
    FROM (SELECT PAYMENT_ID FROM PAYMENTS WHERE STATUS IN ('COMPLETED','FAILED','RETURNED') ORDER BY RANDOM() LIMIT 1200)
)
SELECT
    'FB' || LPAD(SEQ4()::VARCHAR, 8, '0'),
    DATEADD('hour', -UNIFORM(1, 8760, RANDOM()), CURRENT_TIMESTAMP()),
    c.IDS[MOD(UNIFORM(0,99999,RANDOM()), c.CNT)]::VARCHAR AS CUSTOMER_ID,
    CASE WHEN UNIFORM(1,10,RANDOM()) <= 6
         THEN p.IDS[MOD(UNIFORM(0,99999,RANDOM()), p.CNT)]::VARCHAR
         ELSE NULL
    END AS PAYMENT_ID,
    ARRAY_CONSTRUCT('Email','Phone','Portal','Survey','Chat')[UNIFORM(0,4,RANDOM())]::VARCHAR,
    ARRAY_CONSTRUCT(
        'The SWIFT payment was processed very quickly today. Excellent service as always from the team.',
        'Our BACS payment was delayed by 3 hours which caused issues with our supplier. Very disappointing.',
        'The new API integration for Faster Payments is brilliant. Reduced our processing time significantly.',
        'We experienced an outage during peak hours which resulted in 15 failed payments. This is unacceptable.',
        'The payment tracking dashboard is very helpful. We can now see real-time status of all our transfers.',
        'Customer service was unhelpful when we called about a returned CHAPS payment. Took 45 minutes.',
        'Smooth onboarding for the new payment file format. The documentation was clear and comprehensive.',
        'Multiple payments stuck in pending status for over 24 hours. Our treasury team is extremely frustrated.',
        'The fraud detection system flagged a legitimate payment causing a 2-day delay.',
        'Impressed with the new same-day settlement capability. This has transformed our cash management.',
        'The mobile banking app crashes frequently when approving high-value payments. Needs urgent fix.',
        'Excellent support from the relationship manager. They proactively informed us about the maintenance window.'
    )[UNIFORM(0,11,RANDOM())]::VARCHAR,
    ARRAY_CONSTRUCT('SWIFT','BACS','CHAPS','FASTER_PAYMENTS','SEPA')[UNIFORM(0,4,RANDOM())]::VARCHAR,
    UNIFORM(1, 5, RANDOM())
FROM TABLE(GENERATOR(ROWCOUNT => 2000))
CROSS JOIN cust_arr c
CROSS JOIN pay_arr p;

SELECT COUNT(*) AS TOTAL_FEEDBACK,
       COUNT(PAYMENT_ID) AS LINKED_TO_PAYMENT,
       ROUND(COUNT(PAYMENT_ID)::FLOAT / COUNT(*) * 100, 1) AS LINKED_PCT
FROM CUSTOMER_FEEDBACK;

-- =====================================================
-- 2.5: SLA DEFINITIONS
-- =====================================================

CREATE OR REPLACE TABLE SLA_DEFINITIONS (
    SLA_ID                  VARCHAR(10),
    SLA_NAME                VARCHAR(100),
    PAYMENT_TYPE            VARCHAR(30),
    MAX_PROCESSING_TIME_MS  NUMBER,
    TARGET_SUCCESS_RATE     NUMBER(5,2),
    MEASUREMENT_WINDOW      VARCHAR(20)
);

INSERT INTO SLA_DEFINITIONS VALUES
('SLA001','CHAPS Same-Day Processing',       'CHAPS',            5000,     99.95, 'DAILY'),
('SLA002','Faster Payments Real-Time',       'FASTER_PAYMENTS',  2000,     99.99, 'HOURLY'),
('SLA003','BACS Next-Day Settlement',        'BACS',             86400000, 99.90, 'DAILY'),
('SLA004','SWIFT International Transfer',    'SWIFT',            60000,    99.50, 'DAILY'),
('SLA005','SEPA Euro Transfers',             'SEPA',             30000,    99.80, 'DAILY'),
('SLA006','Wire Transfer Same-Day',          'WIRE_TRANSFER',    10000,    99.90, 'DAILY');

SELECT * FROM SLA_DEFINITIONS;

-- =====================================================
-- 2.6: OPERATIONAL ALERTS (1,500 rows)
-- Every alert links to a specific problem payment
-- =====================================================

CREATE OR REPLACE TABLE OPERATIONAL_ALERTS (
    ALERT_ID            VARCHAR(15),
    ALERT_TIME          TIMESTAMP,
    SEVERITY            VARCHAR(10),
    PAYMENT_TYPE        VARCHAR(30),
    PAYMENT_ID          VARCHAR(20),
    ALERT_DESCRIPTION   VARCHAR(500),
    STATUS              VARCHAR(20),
    ASSIGNED_TO         VARCHAR(100),
    RESOLUTION_TIME_MIN NUMBER
);

INSERT INTO OPERATIONAL_ALERTS
WITH problem_payments AS (
    SELECT PAYMENT_ID, PAYMENT_TYPE,
           ROW_NUMBER() OVER (ORDER BY RANDOM()) AS RN
    FROM PAYMENTS
    WHERE STATUS IN ('FAILED','RETURNED','PENDING')
),
pp_arr AS (
    SELECT ARRAY_AGG(PAYMENT_ID) AS IDS,
           ARRAY_AGG(PAYMENT_TYPE) AS TYPES,
           COUNT(*) AS CNT
    FROM problem_payments
)
SELECT
    'ALT' || LPAD(SEQ4()::VARCHAR, 8, '0'),
    DATEADD('minute', -UNIFORM(1, 43200, RANDOM()), CURRENT_TIMESTAMP()),
    ARRAY_CONSTRUCT('LOW','MEDIUM','MEDIUM','HIGH','CRITICAL')[UNIFORM(0,4,RANDOM())]::VARCHAR,
    pp.TYPES[MOD(UNIFORM(0,99999,RANDOM()), pp.CNT)]::VARCHAR AS PAYMENT_TYPE,
    pp.IDS[MOD(UNIFORM(0,99999,RANDOM()), pp.CNT)]::VARCHAR AS PAYMENT_ID,
    ARRAY_CONSTRUCT(
        'Processing time exceeded SLA threshold',
        'Elevated failure rate detected',
        'Connectivity issue with clearing house',
        'Unusual transaction volume spike',
        'Settlement file delivery delayed',
        'Duplicate payment detection triggered',
        'Beneficiary validation timeout'
    )[UNIFORM(0,6,RANDOM())]::VARCHAR,
    ARRAY_CONSTRUCT('OPEN','OPEN','ACKNOWLEDGED','INVESTIGATING','RESOLVED','RESOLVED')[UNIFORM(0,5,RANDOM())]::VARCHAR,
    'Ops Team ' || ARRAY_CONSTRUCT('Alpha','Beta','Gamma')[UNIFORM(0,2,RANDOM())]::VARCHAR,
    CASE WHEN UNIFORM(1,3,RANDOM()) != 1 THEN UNIFORM(5,480,RANDOM()) ELSE NULL END
FROM TABLE(GENERATOR(ROWCOUNT => 1500))
CROSS JOIN pp_arr pp;

SELECT COUNT(*) AS TOTAL_ALERTS,
       COUNT(PAYMENT_ID) AS LINKED_TO_PAYMENT
FROM OPERATIONAL_ALERTS;

-- =====================================================
-- 2.7: SUMMARY
-- =====================================================

SELECT 'RELATIONSHIP_MANAGERS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM RELATIONSHIP_MANAGERS UNION ALL
SELECT 'CUSTOMERS',                           COUNT(*)              FROM CUSTOMERS             UNION ALL
SELECT 'ACCOUNTS',                            COUNT(*)              FROM ACCOUNTS              UNION ALL
SELECT 'PAYMENT_SCHEMES',                     COUNT(*)              FROM PAYMENT_SCHEMES       UNION ALL
SELECT 'ERROR_CODES',                         COUNT(*)              FROM ERROR_CODES           UNION ALL
SELECT 'PAYMENTS',                            COUNT(*)              FROM PAYMENTS              UNION ALL
SELECT 'CUSTOMER_FEEDBACK',                   COUNT(*)              FROM CUSTOMER_FEEDBACK     UNION ALL
SELECT 'SLA_DEFINITIONS',                     COUNT(*)              FROM SLA_DEFINITIONS       UNION ALL
SELECT 'OPERATIONAL_ALERTS',                  COUNT(*)              FROM OPERATIONAL_ALERTS
ORDER BY ROW_COUNT DESC;

-- =====================================================
-- 2.8: ENRICH WITH MARKETPLACE DATA
-- Snowflake Marketplace provides free, ready-to-query datasets.
-- We'll add real FX rates to replace our synthetic ones.
--
-- SNOWSIGHT UI STEPS:
--   1. Click the Marketplace icon in the left nav (or Data Products → Marketplace)
--   2. Search for "Foreign Exchange Rates"
--   3. Find "Snowflake Public Data: Foreign Exchange Rates" by Snowflake Public Data Products
--   4. Click "Get" → accept terms → name the database (default is fine)
--   5. Click "Get" again — the shared database appears instantly
--
-- Once installed, run the queries below to explore and join.
-- =====================================================

-- Explore what's in the FX dataset
SELECT * FROM SNOWFLAKE_PUBLIC_DATA_FOREIGN_EXCHANGE_RATES.PUBLIC_DATA.FX_RATES_TIMESERIES LIMIT 10;

-- Preview GBP/EUR and GBP/USD rates for the last 30 days
SELECT
    DATE,
    QUOTE_CURRENCY_ID,
    VALUE AS FX_RATE
FROM SNOWFLAKE_PUBLIC_DATA_FOREIGN_EXCHANGE_RATES.PUBLIC_DATA.FX_RATES_TIMESERIES
WHERE BASE_CURRENCY_ID = 'GBP'
  AND QUOTE_CURRENCY_ID IN ('EUR', 'USD')
  AND DATE >= DATEADD('day', -30, CURRENT_DATE())
ORDER BY DATE DESC, QUOTE_CURRENCY_ID;

-- Join real FX rates to our cross-currency payments
SELECT
    p.PAYMENT_ID,
    p.PAYMENT_DATE::DATE AS PAYMENT_DATE,
    p.PAYMENT_TYPE,
    p.CURRENCY,
    p.AMOUNT,
    p.FX_RATE AS SYNTHETIC_FX_RATE,
    fx.VALUE AS REAL_FX_RATE,
    ROUND(p.AMOUNT * fx.VALUE, 2) AS AMOUNT_IN_GBP
FROM BARCLAYS_HOL.RAW_DATA.PAYMENTS p
LEFT JOIN SNOWFLAKE_PUBLIC_DATA_FOREIGN_EXCHANGE_RATES.PUBLIC_DATA.FX_RATES_TIMESERIES fx
    ON fx.BASE_CURRENCY_ID = 'GBP'
   AND fx.QUOTE_CURRENCY_ID = p.CURRENCY
   AND fx.DATE = p.PAYMENT_DATE::DATE
WHERE p.PAYMENT_TYPE IN ('SWIFT', 'SEPA')
  AND p.CURRENCY != 'GBP'
LIMIT 20;
