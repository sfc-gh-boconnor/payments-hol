-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - FACILITATOR SETUP
-- STEP 07: RETAIL BANKING GEOSPATIAL DATA (used by DA3)
--
-- Synthetic UK retail network in BARCLAYS_HOL.RETAIL, read-only to attendees:
--   BRANCHES          57 branches on real high streets in 8 UK cities (GEOGRAPHY points)
--   ATMS              one per branch plus standalone ATMs
--   RETAIL_CUSTOMERS  20,000 customers with a home location and nearest branch
--   BRANCH_VISITS     ~150,000 branch visits over the last 12 months
--   BRANCH_CELL_TRAVEL  real road-network drive and walk times from every branch to
--                       every H3 res-8 cell around it (OpenRouteService MATRIX)
--   BRANCH_ISOCHRONES   10/20 min drive and 15 min walk catchments per branch (ORS ISOCHRONES)
-- The two ORS tables are precomputed once with OpenRouteService on SPCS
-- (setup/tools/ors_precompute.py) and loaded from data/retail/, so accounts
-- don't need ORS. Their files must be on @BARCLAYS_HOL.RETAIL.ORS_SEED first:
-- provision_account.sh PUTs them, INSTALL.sql copies them from the Git repo.
-- Branches sit on real local high streets (fixed coordinates), so the layout is the
-- same on every run. Planted patterns give DA3 real answers:
--   * overlapping pairs <1 km apart in Manchester, Leeds and Glasgow
--   * high-cost, low-footfall branches (Manchester King Street, Leeds Boar Lane)
--   * Barry: the only branch for ~8 km, serving older, less digital
--     customers - the costliest branch to close for service disruption
-- =====================================================

USE ROLE HOL_ADMIN;
USE WAREHOUSE BARCLAYS_WH;
CREATE SCHEMA IF NOT EXISTS BARCLAYS_HOL.RETAIL COMMENT = 'Retail banking branch network (DA3 geospatial)';
USE SCHEMA BARCLAYS_HOL.RETAIL;

-- City centres and each city's share of customers
CREATE OR REPLACE TEMPORARY TABLE CITY_CENTRES AS
SELECT * FROM VALUES
  ('LON', 'London',     51.5074, -0.1278, 0.24),
  ('MAN', 'Manchester', 53.4808, -2.2426, 0.13),
  ('BHM', 'Birmingham', 52.4862, -1.8904, 0.13),
  ('LDS', 'Leeds',      53.8008, -1.5491, 0.10),
  ('GLA', 'Glasgow',    55.8642, -4.2518, 0.10),
  ('BRS', 'Bristol',    51.4545, -2.5879, 0.10),
  ('CDF', 'Cardiff',    51.4816, -3.1791, 0.10),
  ('EDI', 'Edinburgh',  55.9533, -3.1883, 0.10)
  AS t(CITY_CODE, CITY, LAT, LON, CUSTOMER_SHARE);

-- -----------------------------------------------------
-- BRANCHES: a city-centre branch, branches on real local high streets, plus planted branches
-- -----------------------------------------------------
CREATE OR REPLACE TABLE BRANCHES AS
WITH local_branches AS (
    -- (city code, n, high street, lat, lon); n = 0 is the city centre, n % 3 = 1 is a FULL branch
    SELECT * FROM VALUES
      ('LON', 0, 'City Centre', 51.5074, -0.1278),
      ('LON', 1, 'Camden Town', 51.5390, -0.1426), ('LON', 2, 'Islington', 51.5362, -0.1033),
      ('LON', 3, 'Stratford', 51.5416, -0.0034),   ('LON', 4, 'Canary Wharf', 51.5054, -0.0235),
      ('LON', 5, 'Brixton', 51.4626, -0.1145),     ('LON', 6, 'Clapham Junction', 51.4643, -0.1704),
      ('LON', 7, 'Hammersmith', 51.4927, -0.2240), ('LON', 8, 'Kensington High Street', 51.5009, -0.1925),
      ('LON', 9, 'Ealing Broadway', 51.5130, -0.3017), ('LON', 10, 'Wimbledon', 51.4214, -0.2064),
      ('LON', 11, 'Croydon', 51.3762, -0.0982),
      ('MAN', 0, 'City Centre', 53.4808, -2.2426),
      ('MAN', 1, 'Salford Quays', 53.4710, -2.2960), ('MAN', 2, 'Didsbury', 53.4166, -2.2310),
      ('MAN', 3, 'Stockport', 53.4106, -2.1575),     ('MAN', 4, 'Altrincham', 53.3872, -2.3490),
      ('MAN', 5, 'Oldham', 53.5409, -2.1114),        ('MAN', 6, 'Prestwich', 53.5330, -2.2840),
      ('BHM', 0, 'City Centre', 52.4862, -1.8904),
      ('BHM', 1, 'Selly Oak', 52.4400, -1.9380),     ('BHM', 2, 'Erdington', 52.5230, -1.8390),
      ('BHM', 3, 'Harborne', 52.4600, -1.9520),      ('BHM', 4, 'Solihull', 52.4130, -1.7780),
      ('BHM', 5, 'Sutton Coldfield', 52.5640, -1.8250), ('BHM', 6, 'West Bromwich', 52.5190, -1.9950),
      ('LDS', 0, 'City Centre', 53.8008, -1.5491),
      ('LDS', 1, 'Headingley', 53.8190, -1.5770),    ('LDS', 2, 'Horsforth', 53.8410, -1.6380),
      ('LDS', 3, 'Roundhay', 53.8350, -1.4990),      ('LDS', 4, 'Morley', 53.7440, -1.6000),
      ('LDS', 5, 'Pudsey', 53.7960, -1.6610),
      ('GLA', 0, 'City Centre', 55.8642, -4.2518),
      ('GLA', 1, 'Partick', 55.8700, -4.3080),       ('GLA', 2, 'Shawlands', 55.8290, -4.2880),
      ('GLA', 3, 'Dennistoun', 55.8590, -4.2140),    ('GLA', 4, 'Bearsden', 55.9180, -4.3330),
      ('GLA', 5, 'Rutherglen', 55.8290, -4.2140),
      ('BRS', 0, 'City Centre', 51.4545, -2.5879),
      ('BRS', 1, 'Clifton', 51.4560, -2.6200),       ('BRS', 2, 'Gloucester Road', 51.4720, -2.5900),
      ('BRS', 3, 'Bedminster', 51.4400, -2.6010),    ('BRS', 4, 'Kingswood', 51.4580, -2.5050),
      ('CDF', 0, 'City Centre', 51.4816, -3.1791),
      ('CDF', 1, 'Canton', 51.4820, -3.2050),        ('CDF', 2, 'Roath', 51.4930, -3.1630),
      ('CDF', 3, 'Llandaff', 51.4950, -3.2180),      ('CDF', 4, 'Whitchurch', 51.5150, -3.2210),
      ('EDI', 0, 'City Centre', 55.9533, -3.1883),
      ('EDI', 1, 'Leith', 55.9700, -3.1720),         ('EDI', 2, 'Morningside', 55.9290, -3.2100),
      ('EDI', 3, 'Corstorphine', 55.9410, -3.2810),  ('EDI', 4, 'Portobello', 55.9530, -3.1150)
      AS t(CITY_CODE, N, STREET, LAT, LON)
),
generated AS (
    SELECT 'BR-' || l.CITY_CODE || '-' || LPAD(l.N, 2, '0') AS BRANCH_ID,
           c.CITY || ' ' || l.STREET AS BRANCH_NAME,
           c.CITY, l.LAT, l.LON,
           IFF(l.N = 0 OR l.N % 3 = 1, 'FULL', 'EXPRESS') AS FORMAT
    FROM local_branches l JOIN CITY_CENTRES c USING (CITY_CODE)
),
planted AS (
    SELECT * FROM VALUES
      -- overlapping pairs: a second branch ~0.4-0.6 km from the city-centre branch
      ('BR-MAN-90', 'Manchester King Street', 'Manchester', 53.4818, -2.2470, 'FULL'),
      ('BR-LDS-90', 'Leeds Boar Lane',        'Leeds',      53.7962, -1.5467, 'FULL'),
      ('BR-GLA-90', 'Glasgow Buchanan Street','Glasgow',    55.8612, -4.2535, 'EXPRESS'),
      -- isolated branch ~10 km from the nearest other branch
      ('BR-CDF-90', 'Barry',                  'Cardiff',    51.4050, -3.2700, 'FULL')
      AS t(BRANCH_ID, BRANCH_NAME, CITY, LAT, LON, FORMAT)
)
SELECT BRANCH_ID, BRANCH_NAME, CITY, ROUND(LAT, 6) AS LAT, ROUND(LON, 6) AS LON,
       ST_MAKEPOINT(ROUND(LON, 6), ROUND(LAT, 6)) AS LOCATION,
       FORMAT,
       CASE WHEN BRANCH_ID IN ('BR-MAN-90', 'BR-LDS-90') THEN 690000
            WHEN FORMAT = 'FULL' THEN 420000 + ABS(HASH(BRANCH_ID)) % 180000
            ELSE 170000 + ABS(HASH(BRANCH_ID)) % 70000 END AS ANNUAL_COST_GBP,
       IFF(FORMAT = 'FULL', 9 + ABS(HASH(BRANCH_ID)) % 6, 3 + ABS(HASH(BRANCH_ID)) % 3) AS STAFF,
       DATEADD('year', -(5 + ABS(HASH(BRANCH_ID)) % 40), '2026-01-01'::DATE) AS OPENED_DATE
FROM (SELECT * FROM generated UNION ALL SELECT * FROM planted);

-- -----------------------------------------------------
-- ATMS: one at each branch plus standalone ATMs near city centres
-- -----------------------------------------------------
CREATE OR REPLACE TABLE ATMS AS
SELECT 'ATM-' || BRANCH_ID AS ATM_ID, BRANCH_ID, LAT, LON, LOCATION, 'BRANCH' AS SITE_TYPE FROM BRANCHES
UNION ALL
SELECT 'ATM-S' || LPAD(SEQ4(), 3, '0') AS ATM_ID, NULL AS BRANCH_ID, LAT, LON, ST_MAKEPOINT(LON, LAT), 'STANDALONE'
FROM (
    SELECT ROUND(c.LAT + NORMAL(0, 0.02, RANDOM()), 6) AS LAT, ROUND(c.LON + NORMAL(0, 0.03, RANDOM()), 6) AS LON
    FROM TABLE(GENERATOR(ROWCOUNT => 90)) g
    JOIN CITY_CENTRES c ON c.CITY_CODE = ARRAY_CONSTRUCT('LON','LON','LON','MAN','BHM','LDS','GLA','BRS','CDF','EDI')[UNIFORM(0, 9, RANDOM())]::STRING
);

-- -----------------------------------------------------
-- ORS travel times and catchments (precomputed, loaded from the stage)
-- -----------------------------------------------------
CREATE STAGE IF NOT EXISTS ORS_SEED COMMENT = 'Precomputed OpenRouteService results for DA3';
CREATE OR REPLACE FILE FORMAT ORS_CSV TYPE = CSV SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"' COMPRESSION = GZIP;

CREATE OR REPLACE TABLE BRANCH_CELL_TRAVEL (
    BRANCH_ID VARCHAR, H3_CELL VARCHAR, PROFILE VARCHAR, DURATION_S NUMBER, DISTANCE_M NUMBER
) COMMENT = 'OpenRouteService travel time and distance from each branch to each H3 res-8 cell (driving-car, foot-walking)';
COPY INTO BRANCH_CELL_TRAVEL FROM @ORS_SEED/branch_cell_travel.csv.gz FILE_FORMAT = (FORMAT_NAME = ORS_CSV);

CREATE OR REPLACE TABLE BRANCH_ISOCHRONES (
    BRANCH_ID VARCHAR, PROFILE VARCHAR, MINUTES NUMBER, CATCHMENT GEOGRAPHY
) COMMENT = 'OpenRouteService isochrones: area reachable from each branch within MINUTES by PROFILE';
COPY INTO BRANCH_ISOCHRONES FROM (
    SELECT $1, $2, $3::NUMBER, TO_GEOGRAPHY($4) FROM @ORS_SEED/branch_isochrones.csv.gz
) FILE_FORMAT = (FORMAT_NAME = ORS_CSV);

-- -----------------------------------------------------
-- RETAIL_CUSTOMERS: 19,400 around city centres and local high streets + 600 around Barry.
-- Homes are drawn generously, then only cells ORS can drive to are kept (no homes in the sea).
-- -----------------------------------------------------
CREATE OR REPLACE TABLE RETAIL_CUSTOMERS AS
WITH city_pick AS (
    -- cumulative shares to pick a city per customer
    SELECT CITY, LAT, LON,
           SUM(CUSTOMER_SHARE) OVER (ORDER BY CITY_CODE) - CUSTOMER_SHARE AS LO,
           SUM(CUSTOMER_SHARE) OVER (ORDER BY CITY_CODE) AS HI
    FROM CITY_CENTRES
),
anchors AS (
    -- the city's own branches (not the planted ones) as neighbourhood centres
    SELECT CITY, LAT, LON,
           ROW_NUMBER() OVER (PARTITION BY CITY ORDER BY BRANCH_ID) - 1 AS IX,
           COUNT(*) OVER (PARTITION BY CITY) AS NB
    FROM BRANCHES WHERE BRANCH_ID NOT LIKE '%-90'
),
routable AS (
    SELECT DISTINCT H3_CELL FROM BRANCH_CELL_TRAVEL WHERE PROFILE = 'driving-car'
),
draws AS (
    SELECT c.CITY, c.LAT AS C_LAT, c.LON AS C_LON,
           UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS A, UNIFORM(1, 100, RANDOM()) AS SPREAD
    FROM (SELECT UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) AS P FROM TABLE(GENERATOR(ROWCOUNT => 30000))) r
    JOIN city_pick c ON r.P >= c.LO AND r.P < c.HI
),
urban AS (
    -- half live in a local neighbourhood (~1.5 km spread), half anywhere across the city
    SELECT d.CITY,
           IFF(d.SPREAD <= 50, a.LAT + NORMAL(0, 0.013, RANDOM()), d.C_LAT + NORMAL(0, 0.030, RANDOM())) AS HOME_LAT,
           IFF(d.SPREAD <= 50, a.LON + NORMAL(0, 0.021, RANDOM()), d.C_LON + NORMAL(0, 0.048, RANDOM())) AS HOME_LON,
           ARRAY_CONSTRUCT('18-34','18-34','35-54','35-54','35-54','55-74','55-74','75+')[UNIFORM(0, 7, RANDOM())]::STRING AS AGE_BAND,
           UNIFORM(1, 100, RANDOM()) <= 78 AS DIGITAL_ACTIVE
    FROM draws d
    JOIN anchors a ON a.CITY = d.CITY AND a.IX = FLOOR(d.A * a.NB)
),
urban_kept AS (
    SELECT u.* FROM urban u
    JOIN routable r ON r.H3_CELL = H3_LATLNG_TO_CELL_STRING(u.HOME_LAT, u.HOME_LON, 8)
    QUALIFY ROW_NUMBER() OVER (ORDER BY RANDOM()) <= 19400
),
barry AS (
    SELECT b.* FROM (
        SELECT 'Cardiff' AS CITY,
               51.4050 + NORMAL(0, 0.012, RANDOM()) AS HOME_LAT,
               -3.2700 + NORMAL(0, 0.018, RANDOM()) AS HOME_LON,
               ARRAY_CONSTRUCT('35-54','55-74','55-74','75+','75+')[UNIFORM(0, 4, RANDOM())]::STRING AS AGE_BAND,
               UNIFORM(1, 100, RANDOM()) <= 35 AS DIGITAL_ACTIVE
        FROM TABLE(GENERATOR(ROWCOUNT => 1200))
    ) b
    JOIN routable r ON r.H3_CELL = H3_LATLNG_TO_CELL_STRING(b.HOME_LAT, b.HOME_LON, 8)
    QUALIFY ROW_NUMBER() OVER (ORDER BY RANDOM()) <= 600
),
people AS (
    SELECT 'RC' || LPAD(ROW_NUMBER() OVER (ORDER BY RANDOM()), 6, '0') AS CUSTOMER_ID,
           CITY, ROUND(HOME_LAT, 6) AS HOME_LAT, ROUND(HOME_LON, 6) AS HOME_LON, AGE_BAND, DIGITAL_ACTIVE,
           ARRAY_CONSTRUCT('MASS','MASS','MASS','MASS','AFFLUENT','SMALL_BUSINESS')[UNIFORM(0, 5, RANDOM())]::STRING AS SEGMENT
    FROM (SELECT * FROM urban_kept UNION ALL SELECT * FROM barry)
)
-- home branch = the branch with the shortest ORS drive time from the customer's H3 cell
-- (straight-line distance breaks ties and covers any cell without a route)
SELECT p.CUSTOMER_ID, p.CITY, p.HOME_LAT, p.HOME_LON, ST_MAKEPOINT(p.HOME_LON, p.HOME_LAT) AS HOME_LOCATION,
       H3_LATLNG_TO_CELL_STRING(p.HOME_LAT, p.HOME_LON, 8) AS HOME_H3_CELL,
       p.AGE_BAND, p.SEGMENT, p.DIGITAL_ACTIVE, b.BRANCH_ID AS HOME_BRANCH_ID
FROM people p
JOIN BRANCHES b ON b.CITY = p.CITY
LEFT JOIN BRANCH_CELL_TRAVEL t
  ON t.BRANCH_ID = b.BRANCH_ID AND t.PROFILE = 'driving-car'
 AND t.H3_CELL = H3_LATLNG_TO_CELL_STRING(p.HOME_LAT, p.HOME_LON, 8)
QUALIFY ROW_NUMBER() OVER (PARTITION BY p.CUSTOMER_ID
    ORDER BY t.DURATION_S NULLS LAST, ST_DISTANCE(ST_MAKEPOINT(p.HOME_LON, p.HOME_LAT), b.LOCATION)) = 1;

-- -----------------------------------------------------
-- BRANCH_VISITS: ~150,000 visits over 12 months, mostly to the home branch.
-- King Street and Boar Lane get few visits (high cost, low footfall).
-- -----------------------------------------------------
CREATE OR REPLACE TABLE BRANCH_VISITS AS
WITH numbered AS (
    SELECT CUSTOMER_ID, HOME_BRANCH_ID, DIGITAL_ACTIVE, ROW_NUMBER() OVER (ORDER BY CUSTOMER_ID) AS RN
    FROM RETAIL_CUSTOMERS
),
draws AS (
    SELECT UNIFORM(1, 20000, RANDOM()) AS RN,
           DATEADD('day', -UNIFORM(0, 364, RANDOM()), CURRENT_DATE()) AS VISIT_DATE,
           ARRAY_CONSTRUCT('CASH','CASH','CASH','ADVICE','MORTGAGE','ACCOUNT_OPENING','CARD_ISSUE')[UNIFORM(0, 6, RANDOM())]::STRING AS VISIT_TYPE,
           UNIFORM(1, 100, RANDOM()) AS KEEP
    FROM TABLE(GENERATOR(ROWCOUNT => 175000))
)
SELECT 'VS' || LPAD(ROW_NUMBER() OVER (ORDER BY d.VISIT_DATE), 7, '0') AS VISIT_ID,
       n.CUSTOMER_ID, n.HOME_BRANCH_ID AS BRANCH_ID, d.VISIT_DATE, d.VISIT_TYPE
FROM draws d
JOIN numbered n ON n.RN = d.RN
-- less digital customers visit more; the two planted branches keep 25% of visits
WHERE d.KEEP <= IFF(n.DIGITAL_ACTIVE, 80, 100)
  AND (n.HOME_BRANCH_ID NOT IN ('BR-MAN-90', 'BR-LDS-90') OR d.KEEP <= 25);

-- Attendees: read-only
GRANT USAGE ON SCHEMA BARCLAYS_HOL.RETAIL TO ROLE HOL_PARTICIPANT;
GRANT SELECT ON ALL TABLES IN SCHEMA BARCLAYS_HOL.RETAIL TO ROLE HOL_PARTICIPANT;

-- Verify
SELECT 'BRANCHES' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM BRANCHES
UNION ALL SELECT 'ATMS', COUNT(*) FROM ATMS
UNION ALL SELECT 'RETAIL_CUSTOMERS', COUNT(*) FROM RETAIL_CUSTOMERS
UNION ALL SELECT 'BRANCH_VISITS', COUNT(*) FROM BRANCH_VISITS
UNION ALL SELECT 'BRANCH_CELL_TRAVEL', COUNT(*) FROM BRANCH_CELL_TRAVEL
UNION ALL SELECT 'BRANCH_ISOCHRONES', COUNT(*) FROM BRANCH_ISOCHRONES;
