-- =====================================================
-- VIGNETTE DA3: BRANCH NETWORK AND CATCHMENT ANALYSIS   (~45 min)
-- Persona:  Data Analyst (Retail Banking)
-- Question: "Which branches could we consolidate, who absorbs their
--            customers, and how much longer would those customers travel?"
-- Prereq:   C1 only. Uses BARCLAYS_HOL.RETAIL (setup/07_retail_geo_seed.sql),
--           including real road-network travel times and catchments that were
--           precomputed with OpenRouteService on Snowpark Container Services.
-- In the lab you build this in a Workspace Notebook (da3_branch_network)
-- with Cortex Code; this file is the reference SQL for each cell.
-- =====================================================

USE ROLE HOL_PARTICIPANT;
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.ANALYTICS;

-- -----------------------------------------------------
-- DA3.1 Map the network (notebook: SQL cell + altair map of LON/LAT)
-- -----------------------------------------------------
SELECT 'BRANCH' AS KIND, BRANCH_NAME AS NAME, CITY, LAT, LON FROM BARCLAYS_HOL.RETAIL.BRANCHES
UNION ALL
SELECT 'ATM', ATM_ID, NULL, LAT, LON FROM BARCLAYS_HOL.RETAIL.ATMS WHERE SITE_TYPE = 'STANDALONE';

-- -----------------------------------------------------
-- DA3.2 Drive-time catchments: who lives within a 10 and 20 minute drive
-- of each branch (ORS isochrones + ST_WITHIN)
-- -----------------------------------------------------
SELECT b.BRANCH_NAME, b.CITY, i.MINUTES,
       ROUND(ANY_VALUE(ST_AREA(i.CATCHMENT)) / 1e6, 1) AS CATCHMENT_KM2,
       COUNT(c.CUSTOMER_ID) AS CUSTOMERS_IN_CATCHMENT
FROM BARCLAYS_HOL.RETAIL.BRANCH_ISOCHRONES i
JOIN BARCLAYS_HOL.RETAIL.BRANCHES b USING (BRANCH_ID)
LEFT JOIN BARCLAYS_HOL.RETAIL.RETAIL_CUSTOMERS c
  ON c.CITY = b.CITY AND ST_WITHIN(c.HOME_LOCATION, i.CATCHMENT)
WHERE i.PROFILE = 'driving-car'
GROUP BY 1, 2, 3
ORDER BY b.CITY, b.BRANCH_NAME, i.MINUTES;

-- -----------------------------------------------------
-- DA3.3 Nearest branch by real drive time: each customer's fastest and
-- second-fastest branch from the ORS matrix (by the customer's H3 cell)
-- -----------------------------------------------------
CREATE OR REPLACE TABLE CUSTOMER_NEAREST_BRANCH AS
WITH ranked AS (
    SELECT c.CUSTOMER_ID, t.BRANCH_ID, t.DURATION_S / 60 AS DRIVE_MIN, t.DISTANCE_M / 1000 AS DRIVE_KM,
           ROW_NUMBER() OVER (PARTITION BY c.CUSTOMER_ID ORDER BY t.DURATION_S) AS RN
    FROM BARCLAYS_HOL.RETAIL.RETAIL_CUSTOMERS c
    JOIN BARCLAYS_HOL.RETAIL.BRANCH_CELL_TRAVEL t
      ON t.H3_CELL = c.HOME_H3_CELL AND t.PROFILE = 'driving-car'
    JOIN BARCLAYS_HOL.RETAIL.BRANCHES b ON b.BRANCH_ID = t.BRANCH_ID AND b.CITY = c.CITY
    QUALIFY RN <= 2
),
walk AS (
    SELECT c.CUSTOMER_ID, MIN(t.DURATION_S) / 60 AS NEAREST_WALK_MIN
    FROM BARCLAYS_HOL.RETAIL.RETAIL_CUSTOMERS c
    JOIN BARCLAYS_HOL.RETAIL.BRANCH_CELL_TRAVEL t ON t.H3_CELL = c.HOME_H3_CELL AND t.PROFILE = 'foot-walking'
    GROUP BY 1
)
SELECT c.CUSTOMER_ID, c.CITY, c.AGE_BAND, c.SEGMENT, c.DIGITAL_ACTIVE,
       MAX(IFF(r.RN = 1, r.BRANCH_ID, NULL))          AS NEAREST_BRANCH_ID,
       ROUND(MAX(IFF(r.RN = 1, r.DRIVE_MIN, NULL)), 1) AS NEAREST_DRIVE_MIN,
       ROUND(MAX(IFF(r.RN = 1, r.DRIVE_KM, NULL)), 2)  AS NEAREST_DRIVE_KM,
       MAX(IFF(r.RN = 2, r.BRANCH_ID, NULL))          AS SECOND_BRANCH_ID,
       ROUND(MAX(IFF(r.RN = 2, r.DRIVE_MIN, NULL)), 1) AS SECOND_DRIVE_MIN,
       ROUND(ANY_VALUE(w.NEAREST_WALK_MIN), 1)        AS NEAREST_WALK_MIN
FROM BARCLAYS_HOL.RETAIL.RETAIL_CUSTOMERS c
JOIN ranked r USING (CUSTOMER_ID)
LEFT JOIN walk w USING (CUSTOMER_ID)
GROUP BY c.CUSTOMER_ID, c.CITY, c.AGE_BAND, c.SEGMENT, c.DIGITAL_ACTIVE;

-- -----------------------------------------------------
-- DA3.4 Overlapping catchments: branch pairs whose 10 minute drive
-- catchments overlap most (ST_INTERSECTION of the isochrones)
-- -----------------------------------------------------
SELECT * FROM (
SELECT a.CITY, a.BRANCH_NAME AS BRANCH_A, b.BRANCH_NAME AS BRANCH_B,
       ROUND(ST_DISTANCE(a.LOCATION, b.LOCATION) / 1000, 2) AS STRAIGHT_LINE_KM,
       ROUND(ST_AREA(ST_INTERSECTION(ia.CATCHMENT, ib.CATCHMENT)) / LEAST(ST_AREA(ia.CATCHMENT), ST_AREA(ib.CATCHMENT)) * 100) AS OVERLAP_PCT
FROM BARCLAYS_HOL.RETAIL.BRANCHES a
JOIN BARCLAYS_HOL.RETAIL.BRANCHES b ON a.CITY = b.CITY AND a.BRANCH_ID < b.BRANCH_ID
JOIN BARCLAYS_HOL.RETAIL.BRANCH_ISOCHRONES ia ON ia.BRANCH_ID = a.BRANCH_ID AND ia.PROFILE = 'driving-car' AND ia.MINUTES = 10
JOIN BARCLAYS_HOL.RETAIL.BRANCH_ISOCHRONES ib ON ib.BRANCH_ID = b.BRANCH_ID AND ib.PROFILE = 'driving-car' AND ib.MINUTES = 10
) WHERE OVERLAP_PCT >= 80
ORDER BY OVERLAP_PCT DESC, STRAIGHT_LINE_KM;

-- -----------------------------------------------------
-- DA3.5 Customer density with H3 (resolution 8, ~0.7 km2 cells)
-- notebook: altair heat map of cells (H3_CELL_TO_POINT gives the centre)
-- -----------------------------------------------------
SELECT HOME_H3_CELL AS H3_CELL,
       ST_Y(H3_CELL_TO_POINT(HOME_H3_CELL)) AS LAT, ST_X(H3_CELL_TO_POINT(HOME_H3_CELL)) AS LON,
       ANY_VALUE(CITY) AS CITY, COUNT(*) AS CUSTOMERS
FROM BARCLAYS_HOL.RETAIL.RETAIL_CUSTOMERS
GROUP BY 1, 2, 3
ORDER BY CUSTOMERS DESC;

-- -----------------------------------------------------
-- DA3.6 Closure impact: if a branch closes, its customers move to their
-- second-fastest branch. Added drive time, lost walk-in access, cost saved.
-- -----------------------------------------------------
CREATE OR REPLACE TABLE BRANCH_CLOSURE_IMPACT AS
WITH visits AS (
    SELECT BRANCH_ID, COUNT(*) AS VISITS_12M FROM BARCLAYS_HOL.RETAIL.BRANCH_VISITS GROUP BY 1
),
walk_after AS (
    -- walking time to the receiving branch for each customer
    SELECT n.CUSTOMER_ID, t.DURATION_S / 60 AS WALK_MIN_AFTER
    FROM CUSTOMER_NEAREST_BRANCH n
    JOIN BARCLAYS_HOL.RETAIL.RETAIL_CUSTOMERS c USING (CUSTOMER_ID)
    JOIN BARCLAYS_HOL.RETAIL.BRANCH_CELL_TRAVEL t
      ON t.H3_CELL = c.HOME_H3_CELL AND t.BRANCH_ID = n.SECOND_BRANCH_ID AND t.PROFILE = 'foot-walking'
),
moved AS (
    SELECT n.NEAREST_BRANCH_ID AS BRANCH_ID,
           COUNT(*) AS CUSTOMERS,
           ROUND(AVG(n.SECOND_DRIVE_MIN - n.NEAREST_DRIVE_MIN), 1) AS AVG_ADDED_DRIVE_MIN,
           ROUND(APPROX_PERCENTILE(n.SECOND_DRIVE_MIN - n.NEAREST_DRIVE_MIN, 0.9), 1) AS P90_ADDED_DRIVE_MIN,
           COUNT_IF(n.NEAREST_WALK_MIN <= 15 AND COALESCE(w.WALK_MIN_AFTER, 999) > 15) AS LOSE_WALK_IN_ACCESS,
           COUNT_IF(NOT n.DIGITAL_ACTIVE OR n.AGE_BAND = '75+') AS VULNERABLE_CUSTOMERS,
           MODE(n.SECOND_BRANCH_ID) AS MAIN_RECEIVING_BRANCH_ID
    FROM CUSTOMER_NEAREST_BRANCH n
    LEFT JOIN walk_after w USING (CUSTOMER_ID)
    GROUP BY 1
)
SELECT b.BRANCH_ID, b.BRANCH_NAME, b.CITY, b.FORMAT, b.ANNUAL_COST_GBP AS ANNUAL_SAVING_GBP,
       COALESCE(v.VISITS_12M, 0) AS VISITS_12M,
       ROUND(b.ANNUAL_COST_GBP / NULLIF(v.VISITS_12M, 0), 2) AS COST_PER_VISIT_GBP,
       m.CUSTOMERS AS CUSTOMERS_AFFECTED, m.AVG_ADDED_DRIVE_MIN, m.P90_ADDED_DRIVE_MIN,
       m.LOSE_WALK_IN_ACCESS, m.VULNERABLE_CUSTOMERS, r.BRANCH_NAME AS MAIN_RECEIVING_BRANCH,
       CASE WHEN m.P90_ADDED_DRIVE_MIN >= 10 OR m.VULNERABLE_CUSTOMERS >= 200 THEN 'HIGH'
            WHEN m.P90_ADDED_DRIVE_MIN >= 4 OR m.LOSE_WALK_IN_ACCESS >= 100 THEN 'MEDIUM' ELSE 'LOW' END AS DISRUPTION_RISK
FROM BARCLAYS_HOL.RETAIL.BRANCHES b
JOIN moved m ON m.BRANCH_ID = b.BRANCH_ID
LEFT JOIN visits v ON v.BRANCH_ID = b.BRANCH_ID
LEFT JOIN BARCLAYS_HOL.RETAIL.BRANCHES r ON r.BRANCH_ID = m.MAIN_RECEIVING_BRANCH_ID;

SELECT BRANCH_NAME, CITY, ANNUAL_SAVING_GBP, COST_PER_VISIT_GBP, AVG_ADDED_DRIVE_MIN, P90_ADDED_DRIVE_MIN,
       LOSE_WALK_IN_ACCESS, VULNERABLE_CUSTOMERS, DISRUPTION_RISK, MAIN_RECEIVING_BRANCH
FROM BRANCH_CLOSURE_IMPACT
ORDER BY DISRUPTION_RISK = 'LOW' DESC, COST_PER_VISIT_GBP DESC
LIMIT 10;

-- -----------------------------------------------------
-- DA3.7 Semantic view for Cortex Analyst (drive minutes, no GEOGRAPHY)
-- -----------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW SV_BRANCH_NETWORK
  TABLES (
    closures AS BARCLAYS_HOL.ANALYTICS.BRANCH_CLOSURE_IMPACT
      PRIMARY KEY (BRANCH_ID)
      WITH SYNONYMS = ('branches', 'branch closures', 'consolidation candidates')
      COMMENT = 'One row per branch: what happens if it closes',
    customers AS BARCLAYS_HOL.ANALYTICS.CUSTOMER_NEAREST_BRANCH
      PRIMARY KEY (CUSTOMER_ID)
      WITH SYNONYMS = ('retail customers', 'catchment')
      COMMENT = 'Each retail customer with their fastest and second-fastest branch by drive time'
  )
  RELATIONSHIPS (
    customers (NEAREST_BRANCH_ID) REFERENCES closures
  )
  FACTS (
    closures.annual_saving_gbp AS ANNUAL_SAVING_GBP COMMENT = 'Annual running cost saved if the branch closes (GBP)',
    closures.visits_12m AS VISITS_12M COMMENT = 'Branch visits in the last 12 months',
    closures.cost_per_visit_gbp AS COST_PER_VISIT_GBP COMMENT = 'Annual cost divided by visits',
    closures.avg_added_drive_min AS AVG_ADDED_DRIVE_MIN WITH SYNONYMS = ('extra travel time') COMMENT = 'Average extra drive minutes to the next-fastest branch (OpenRouteService)',
    closures.p90_added_drive_min AS P90_ADDED_DRIVE_MIN COMMENT = '90th percentile extra drive minutes',
    closures.lose_walk_in_access AS LOSE_WALK_IN_ACCESS COMMENT = 'Customers who lose a branch within a 15 minute walk',
    closures.vulnerable_customers AS VULNERABLE_CUSTOMERS COMMENT = 'Affected customers who are 75+ or not digitally active',
    customers.nearest_drive_min AS NEAREST_DRIVE_MIN COMMENT = 'Drive minutes from home to the fastest branch',
    customers.nearest_walk_min AS NEAREST_WALK_MIN COMMENT = 'Walking minutes from home to the nearest branch'
  )
  DIMENSIONS (
    closures.branch_name AS BRANCH_NAME WITH SYNONYMS = ('branch') COMMENT = 'Branch name',
    closures.city AS CITY COMMENT = 'City',
    closures.format AS FORMAT COMMENT = 'FULL or EXPRESS branch',
    closures.disruption_risk AS DISRUPTION_RISK COMMENT = 'LOW, MEDIUM or HIGH service disruption if closed',
    closures.main_receiving_branch AS MAIN_RECEIVING_BRANCH COMMENT = 'Branch that absorbs most customers',
    customers.age_band AS AGE_BAND COMMENT = 'Customer age band',
    customers.segment AS SEGMENT COMMENT = 'MASS, AFFLUENT or SMALL_BUSINESS',
    customers.digital_active AS DIGITAL_ACTIVE COMMENT = 'Customer uses digital banking'
  )
  METRICS (
    closures.total_saving_gbp AS SUM(closures.annual_saving_gbp) COMMENT = 'Total annual saving (GBP)',
    closures.branch_count AS COUNT(closures.branch_name) COMMENT = 'Number of branches',
    customers.customer_count AS COUNT(customers.customer_id) COMMENT = 'Number of customers',
    customers.avg_drive_min AS ROUND(AVG(customers.nearest_drive_min), 1) COMMENT = 'Average drive minutes to the fastest branch'
  )
  COMMENT = 'DA3 retail branch network and consolidation impact (OpenRouteService travel times)';

SELECT * FROM SEMANTIC_VIEW(SV_BRANCH_NETWORK
  METRICS closures.total_saving_gbp, closures.branch_count
  DIMENSIONS closures.city, closures.disruption_risk)
ORDER BY CITY, DISRUPTION_RISK;

-- -----------------------------------------------------
-- DA3.8 Branch network agent (in the lab: + > Agent > Create with CoCo)
-- -----------------------------------------------------
CREATE OR REPLACE AGENT BARCLAYS_HOL.ANALYTICS.BRANCH_NETWORK_ADVISOR
  COMMENT = 'DA3: retail branch consolidation advisor'
  PROFILE = '{"display_name": "Branch Network Advisor", "color": "orange"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto
  instructions:
    response: >
      You advise a UK retail bank on its branch network. For a consolidation question, return:
      a ranked list of candidate branches with annual saving and cost per visit, the branch that
      absorbs their customers and the added drive time (average and p90 minutes), customers who
      lose walk-in access, the disruption risk and vulnerable customers affected, and a short
      90-day transition plan. Never recommend closing a HIGH disruption-risk branch without
      saying why and what mitigation is needed.
    orchestration: "Use the Analyst tool for every question about branches, closures, catchments, travel time and customers."
    sample_questions:
      - question: "What is the consolidation opportunity in Leeds?"
      - question: "Which 3 branches could close with the least added travel time?"
      - question: "Which branch would be hardest to close, and why?"
  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "Analyst"
        description: "Retail branch network: closure impact per branch (saving, visits, added drive time, lost walk-in access, disruption risk) and customer catchments."
  tool_resources:
    Analyst:
      semantic_view: "BARCLAYS_HOL.ANALYTICS.SV_BRANCH_NETWORK"
      execution_environment:
        type: "warehouse"
        warehouse: "BARCLAYS_WH"
  $$;

SELECT 'DA3 complete' AS STATUS;
