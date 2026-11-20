-- =====================================================
-- DS1: PREDICT ATTRITION - reference SQL
-- Point-in-time features for the attrition model: what we knew about each customer on
-- 31 Aug 2026, and whether they left in the 3 months after. Run as HOL_PARTICIPANT.
-- The notebook (notebooks/ds1_attrition_model.ipynb) trains on this view; this file is
-- the fallback and the answer key.
-- =====================================================
USE SECONDARY ROLES NONE;
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.ML;

CREATE OR REPLACE VIEW RB_CHURN_FEATURES COMMENT = 'DS1 point-in-time attrition features, observed 2026-08-31, label = left by 2026-11-30' AS
WITH obs AS (SELECT '2026-08-31'::DATE AS OBS_DATE),
snap AS (  -- only months up to the observation date: no peeking at the future
    SELECT s.CUSTOMER_ID,
           AVG(IFF(s.MONTH >  DATEADD(month, -3, o.OBS_DATE), s.SALARY_IN_GBP, NULL)) AS SALARY_L3M,
           AVG(IFF(s.MONTH <= DATEADD(month, -3, o.OBS_DATE), s.SALARY_IN_GBP, NULL)) AS SALARY_P3M,
           AVG(IFF(s.MONTH >  DATEADD(month, -3, o.OBS_DATE), s.APP_LOGINS, NULL))    AS LOGINS_L3M,
           AVG(IFF(s.MONTH >  DATEADD(month, -3, o.OBS_DATE), s.BRANCH_VISITS, NULL)) AS BRANCH_VISITS_L3M,
           AVG(IFF(s.MONTH >  DATEADD(month, -3, o.OBS_DATE), s.CARD_SPEND_GBP, NULL)) AS CARD_SPEND_L3M,
           MAX_BY(s.CURRENT_BALANCE_GBP, s.MONTH) AS CURRENT_BALANCE,
           MAX_BY(s.SAVINGS_BALANCE_GBP, s.MONTH) AS SAVINGS_BALANCE,
           MAX_BY(s.PRODUCTS_HELD, s.MONTH)       AS PRODUCTS_HELD,
           SUM(s.PROFIT_GBP)                      AS PROFIT_TO_DATE
    FROM BARCLAYS_HOL.RAW_DATA.RB_MONTHLY_SNAPSHOT s, obs o
    WHERE s.MONTH <= o.OBS_DATE
    GROUP BY s.CUSTOMER_ID
),
sav AS (
    SELECT a.CUSTOMER_ID, MIN(a.INTEREST_RATE_PCT) AS MIN_SAVINGS_RATE,
           MAX(IFF(p.TIER = 'LEGACY', 1, 0)) AS ON_LEGACY_SAVER
    FROM BARCLAYS_HOL.RAW_DATA.RB_ACCOUNTS a JOIN BARCLAYS_HOL.RAW_DATA.RB_PRODUCTS p ON p.PRODUCT_ID = a.PRODUCT_ID, obs o
    WHERE p.PRODUCT_FAMILY = 'SAVINGS' AND a.OPENED_DATE <= o.OBS_DATE
    GROUP BY a.CUSTOMER_ID
)
SELECT c.CUSTOMER_ID,
       DATEDIFF(month, c.CUSTOMER_SINCE, o.OBS_DATE) AS TENURE_MONTHS,
       c.AGE, c.SEGMENT, c.IMD_DECILE, c.HOUSING_TENURE, c.CREDIT_SCORE,
       IFF(c.DIGITAL_ACTIVE, 1, 0) AS DIGITAL_ACTIVE,
       IFF(c.HOME_BRANCH_ID IN ('BR-MAN-90', 'BR-LDS-90', 'BR-CDF-90'), 1, 0) AS BRANCH_AT_RISK,
       c.HOME_BRANCH_DRIVE_S / 60 AS BRANCH_DRIVE_MIN,
       s.PRODUCTS_HELD, s.CURRENT_BALANCE, s.SAVINGS_BALANCE, s.CARD_SPEND_L3M, s.LOGINS_L3M, s.BRANCH_VISITS_L3M,
       s.SALARY_L3M / NULLIF(s.SALARY_P3M, 0) AS SALARY_TREND,  -- below 1: pay starting to go elsewhere
       COALESCE(sv.MIN_SAVINGS_RATE, 0) AS MIN_SAVINGS_RATE, COALESCE(sv.ON_LEGACY_SAVER, 0) AS ON_LEGACY_SAVER,
       s.PROFIT_TO_DATE,
       -- the label: left in the 3 months after the observation date
       IFF(c.CHURN_DATE > o.OBS_DATE AND c.CHURN_DATE <= DATEADD(month, 3, o.OBS_DATE), 1, 0) AS CHURNED_NEXT_3M
FROM BARCLAYS_HOL.RAW_DATA.RB_CUSTOMERS c
JOIN snap s ON s.CUSTOMER_ID = c.CUSTOMER_ID
LEFT JOIN sav sv ON sv.CUSTOMER_ID = c.CUSTOMER_ID
CROSS JOIN obs o
WHERE c.CUSTOMER_SINCE <= o.OBS_DATE
  AND (c.CHURN_DATE IS NULL OR c.CHURN_DATE > o.OBS_DATE);  -- still a customer on the observation date

-- Class balance: about 2-3% leave in the next 3 months
SELECT CHURNED_NEXT_3M, COUNT(*) AS CUSTOMERS, ROUND(RATIO_TO_REPORT(COUNT(*)) OVER () * 100, 1) AS PCT
FROM RB_CHURN_FEATURES GROUP BY 1 ORDER BY 1;

-- Leakage traps to leave out: CHURN_DATE, CHURN_REASON, CHURNED, RB_MONTHLY_SNAPSHOT.CHURNED_FLAG,
-- any snapshot month after OBS_DATE, RB_ACCOUNTS.CLOSED_DATE and STATUS.

-- After the notebook: the experiment, the registered model and the scores
SHOW EXPERIMENTS IN SCHEMA BARCLAYS_HOL.ML;
SHOW MODELS IN SCHEMA BARCLAYS_HOL.ML;
SELECT RISK_BAND, COUNT(*) AS CUSTOMERS FROM BARCLAYS_HOL.ML.RB_ATTRITION_SCORES GROUP BY 1 ORDER BY 1;
