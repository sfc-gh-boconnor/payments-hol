-- =====================================================
-- DS2: FRAUD ANOMALY DETECTION - reference SQL
-- Per-transaction behavioural features for an unsupervised anomaly model. Labels
-- (IS_FRAUD, FRAUD_TYPE) are kept only to evaluate it. Run as HOL_PARTICIPANT.
-- The notebook (notebooks/ds2_fraud_anomaly.ipynb) trains on this view.
-- =====================================================
USE SECONDARY ROLES NONE;
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_HOL.ML;

CREATE OR REPLACE VIEW RB_TXN_FEATURES COMMENT = 'DS2 behavioural features per outgoing retail transaction; IS_FRAUD kept for evaluation only' AS
WITH t AS (
    SELECT TXN_ID, CUSTOMER_ID, TXN_TS, -AMOUNT_GBP AS AMOUNT, CHANNEL, CATEGORY, MERCHANT_COUNTRY,
           IS_ONLINE, IS_NEW_PAYEE, IS_FRAUD, FRAUD_TYPE
    FROM BARCLAYS_HOL.RAW_DATA.RB_TRANSACTIONS
    WHERE AMOUNT_GBP < 0  -- money going out
),
usual AS (
    SELECT CUSTOMER_ID, MEDIAN(AMOUNT) AS MEDIAN_AMOUNT, STDDEV(AMOUNT) AS SD_AMOUNT
    FROM t GROUP BY 1
)
SELECT t.TXN_ID, t.CUSTOMER_ID, t.TXN_TS,
       LN(1 + t.AMOUNT) AS LOG_AMOUNT,
       t.AMOUNT / NULLIF(u.MEDIAN_AMOUNT, 0) AS AMOUNT_VS_USUAL,  -- how unusual for this customer
       HOUR(t.TXN_TS) AS HOUR_OF_DAY,
       IFF(HOUR(t.TXN_TS) BETWEEN 0 AND 5, 1, 0) AS IS_NIGHT,
       IFF(t.IS_ONLINE, 1, 0) AS IS_ONLINE,
       IFF(t.IS_NEW_PAYEE, 1, 0) AS IS_NEW_PAYEE,
       IFF(t.MERCHANT_COUNTRY <> 'GB', 1, 0) AS IS_ABROAD,
       IFF(t.CHANNEL = 'FPS_OUT', 1, 0) AS IS_FASTER_PAYMENT,
       -- velocity: this customer's payments in the 30 minutes before
       COUNT(*) OVER (PARTITION BY t.CUSTOMER_ID ORDER BY t.TXN_TS
                      RANGE BETWEEN INTERVAL '30 minutes' PRECEDING AND CURRENT ROW) - 1 AS TXNS_PRIOR_30M,
       -- impossible travel: a different country within 2 hours
       IFF(LAG(t.MERCHANT_COUNTRY) OVER (PARTITION BY t.CUSTOMER_ID ORDER BY t.TXN_TS) <> t.MERCHANT_COUNTRY
           AND DATEDIFF(minute, LAG(t.TXN_TS) OVER (PARTITION BY t.CUSTOMER_ID ORDER BY t.TXN_TS), t.TXN_TS) <= 120, 1, 0) AS COUNTRY_CHANGE_2H,
       IFF(c.AGE >= 65, 1, 0) AS CUSTOMER_65_PLUS,
       IFF(t.IS_FRAUD, 1, 0) AS IS_FRAUD, t.FRAUD_TYPE  -- evaluation only, never a feature
FROM t
JOIN usual u ON u.CUSTOMER_ID = t.CUSTOMER_ID
JOIN BARCLAYS_HOL.RAW_DATA.RB_CUSTOMERS c ON c.CUSTOMER_ID = t.CUSTOMER_ID;

SELECT COUNT(*) AS TXNS, SUM(IS_FRAUD) AS FRAUD, ROUND(100 * AVG(IS_FRAUD), 2) AS FRAUD_PCT FROM RB_TXN_FEATURES;

-- After the notebook: how many of the flagged transactions are labelled fraud, by type
SELECT f.FRAUD_TYPE, COUNT(*) AS FLAGGED
FROM BARCLAYS_HOL.ML.RB_FRAUD_ALERTS a JOIN RB_TXN_FEATURES f ON f.TXN_ID = a.TXN_ID
GROUP BY 1 ORDER BY 2 DESC;
SHOW MODELS LIKE 'RB_FRAUD_ANOMALY' IN SCHEMA BARCLAYS_HOL.ML;
