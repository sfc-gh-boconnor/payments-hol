-- =====================================================
-- BARCLAYS PAYMENTS HOL v2 - EXECUTIVE DEMO
-- STEP 12c: AI AND ML RESULTS (BARCLAYS_DEMO.INSIGHTS)
--
-- Run once at build time, so the tour never waits for a model or an LLM:
--   DEMO_ATTRITION_MODEL     XGBoost attrition model in the demo's own registry
--   DEMO_ATTRITION_SCORES    every active customer's risk, DEMO_ATTRITION_DRIVERS
--   DEMO_FRAUD_ALERTS        unusual outbound payments, scored in SQL
--   DEMO_CALL_THEMES         AI SQL on a sample of calls
--   DEMO_FINCRIME_CASE       one APP scam case worked end to end with AI SQL
-- Reads only BARCLAYS_DEMO. AI SQL runs on small samples (about 70 calls).
-- =====================================================
USE ROLE HOL_ADMIN;
USE WAREHOUSE BARCLAYS_WH;
USE SCHEMA BARCLAYS_DEMO.INSIGHTS;

-- ---------- Attrition: point-in-time features (same as the lab's DS1, on the demo's data) ----------
CREATE OR REPLACE VIEW DEMO_CHURN_FEATURES AS
WITH obs AS (SELECT '2026-08-31'::DATE AS OBS_DATE),
snap AS (
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
    FROM BARCLAYS_DEMO.RAW_DATA.RB_MONTHLY_SNAPSHOT s, obs o
    WHERE s.MONTH <= o.OBS_DATE GROUP BY s.CUSTOMER_ID),
sav AS (
    SELECT a.CUSTOMER_ID, MIN(a.INTEREST_RATE_PCT) AS MIN_SAVINGS_RATE, MAX(IFF(p.TIER = 'LEGACY', 1, 0)) AS ON_LEGACY_SAVER
    FROM BARCLAYS_DEMO.RAW_DATA.RB_ACCOUNTS a JOIN BARCLAYS_DEMO.RAW_DATA.RB_PRODUCTS p ON p.PRODUCT_ID = a.PRODUCT_ID, obs o
    WHERE p.PRODUCT_FAMILY = 'SAVINGS' AND a.OPENED_DATE <= o.OBS_DATE GROUP BY a.CUSTOMER_ID)
SELECT c.CUSTOMER_ID,
       DATEDIFF(month, c.CUSTOMER_SINCE, o.OBS_DATE) AS TENURE_MONTHS,
       c.AGE, c.SEGMENT, c.IMD_DECILE, c.HOUSING_TENURE, c.CREDIT_SCORE,
       IFF(c.DIGITAL_ACTIVE, 1, 0) AS DIGITAL_ACTIVE,
       IFF(c.HOME_BRANCH_ID IN ('BR-MAN-90', 'BR-LDS-90', 'BR-CDF-90'), 1, 0) AS BRANCH_AT_RISK,
       c.HOME_BRANCH_DRIVE_S / 60 AS BRANCH_DRIVE_MIN,
       s.PRODUCTS_HELD, s.CURRENT_BALANCE, s.SAVINGS_BALANCE, s.CARD_SPEND_L3M, s.LOGINS_L3M, s.BRANCH_VISITS_L3M,
       s.SALARY_L3M / NULLIF(s.SALARY_P3M, 0) AS SALARY_TREND,
       COALESCE(sv.MIN_SAVINGS_RATE, 0) AS MIN_SAVINGS_RATE, COALESCE(sv.ON_LEGACY_SAVER, 0) AS ON_LEGACY_SAVER,
       s.PROFIT_TO_DATE,
       IFF(c.CHURN_DATE > o.OBS_DATE AND c.CHURN_DATE <= DATEADD(month, 3, o.OBS_DATE), 1, 0) AS CHURNED_NEXT_3M
FROM BARCLAYS_DEMO.RAW_DATA.RB_CUSTOMERS c
JOIN snap s ON s.CUSTOMER_ID = c.CUSTOMER_ID
LEFT JOIN sav sv ON sv.CUSTOMER_ID = c.CUSTOMER_ID
CROSS JOIN obs o
WHERE c.CUSTOMER_SINCE <= o.OBS_DATE AND (c.CHURN_DATE IS NULL OR c.CHURN_DATE > o.OBS_DATE);

-- Train, register and score in one warehouse procedure (no compute pool needed)
CREATE OR REPLACE PROCEDURE BARCLAYS_DEMO.EXEC.DEMO_TRAIN_ATTRITION()
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'snowflake-ml-python==2.9.0', 'xgboost', 'scikit-learn', 'pandas', 'numpy')
HANDLER = 'run'
COMMENT = 'Executive demo: trains DEMO_ATTRITION_MODEL on BARCLAYS_DEMO data and scores every customer'
EXECUTE AS CALLER  -- the registry and write_pandas need a current schema, which owner rights can't set
AS
$$
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from snowflake.ml.registry import Registry
from xgboost import XGBClassifier

DB, SCHEMA = "BARCLAYS_DEMO", "INSIGHTS"

def run(session):
    session.use_schema(f"{DB}.{SCHEMA}")
    df = session.table(f"{DB}.{SCHEMA}.DEMO_CHURN_FEATURES").to_pandas()
    y = df.pop("CHURNED_NEXT_3M").astype(int)
    ids = df.pop("CUSTOMER_ID")
    cat = ["SEGMENT", "HOUSING_TENURE"]
    num = [c for c in df.columns if c not in cat]
    df[num] = df[num].apply(pd.to_numeric, errors="coerce").fillna(0).astype(float)
    X_tr, X_te, y_tr, y_te = train_test_split(df, y, test_size=0.3, stratify=y, random_state=42)
    model = Pipeline([("prep", ColumnTransformer([("num", StandardScaler(), num), ("cat", OneHotEncoder(handle_unknown="ignore"), cat)])),
                      ("clf", XGBClassifier(n_estimators=300, max_depth=4, learning_rate=0.05, subsample=0.8,
                                            scale_pos_weight=float((y_tr == 0).sum() / (y_tr == 1).sum())))])
    model.fit(X_tr, y_tr)
    auc = round(float(roc_auc_score(y_te, model.predict_proba(X_te)[:, 1])), 4)

    reg = Registry(session, database_name=DB, schema_name=SCHEMA)
    for m in reg.show_models().get("name", []):
        if m == "DEMO_ATTRITION_MODEL":
            reg.delete_model("DEMO_ATTRITION_MODEL")
    mv = reg.log_model(model, model_name="DEMO_ATTRITION_MODEL", version_name="V1", sample_input_data=X_tr.head(50),
                       metrics={"auc": auc}, target_platforms=["WAREHOUSE"],
                       comment="Executive demo: attrition in the next 3 months, observed 2026-08-31")

    prob = mv.run(df, function_name="predict_proba").iloc[:, -1].to_numpy()
    out = pd.DataFrame({"CUSTOMER_ID": ids.values, "CHURN_PROBABILITY": prob})
    pct = out.CHURN_PROBABILITY.rank(pct=True)
    out["RISK_BAND"] = np.select([pct > 0.95, pct > 0.8], ["HIGH", "MEDIUM"], "LOW")
    session.write_pandas(out, "DEMO_ATTRITION_SCORES", database=DB, schema=SCHEMA, auto_create_table=True, overwrite=True)

    names = model.named_steps["prep"].get_feature_names_out()
    imp = model.named_steps["clf"].feature_importances_
    # one-hot columns (cat__SEGMENT_MASS) roll up to their source column
    src = [next((c for c in cat if n == f"cat__{c}" or n.startswith(f"cat__{c}_")), n.split("__", 1)[-1]) for n in names]
    drivers = pd.DataFrame({"FEATURE": src, "IMPORTANCE": imp}).groupby("FEATURE", as_index=False)["IMPORTANCE"].sum()
    drivers = drivers.sort_values("IMPORTANCE", ascending=False).head(10)
    session.write_pandas(drivers, "DEMO_ATTRITION_DRIVERS", database=DB, schema=SCHEMA, auto_create_table=True, overwrite=True)
    return {"auc": auc, "scored": len(out), "high_risk": int((out.RISK_BAND == "HIGH").sum())}
$$;
CALL BARCLAYS_DEMO.EXEC.DEMO_TRAIN_ATTRITION();

-- At-risk customers, with what they're worth and where they live (for the map and list)
CREATE OR REPLACE TABLE DEMO_AT_RISK_CUSTOMERS AS
SELECT s.CUSTOMER_ID, c.FIRST_NAME || ' ' || LEFT(c.LAST_NAME, 1) || '.' AS CUSTOMER, c.CITY, c.SEGMENT, c.AGE,
       ROUND(s.CHURN_PROBABILITY, 3) AS CHURN_PROBABILITY, s.RISK_BAND,
       ROUND(f.PROFIT_TO_DATE) AS PROFIT_TO_DATE_GBP, ROUND(f.SAVINGS_BALANCE) AS SAVINGS_BALANCE_GBP,
       f.ON_LEGACY_SAVER, f.BRANCH_AT_RISK, ROUND(f.SALARY_TREND, 2) AS SALARY_TREND,
       ROUND(c.HOME_LAT, 3) AS LAT, ROUND(c.HOME_LON, 3) AS LON
FROM DEMO_ATTRITION_SCORES s
JOIN BARCLAYS_DEMO.RAW_DATA.RB_CUSTOMERS c USING (CUSTOMER_ID)
JOIN DEMO_CHURN_FEATURES f USING (CUSTOMER_ID)
WHERE s.RISK_BAND IN ('HIGH', 'MEDIUM');

-- ---------- Fraud alerts: unusual outbound payments against each customer's own normal ----------
CREATE OR REPLACE TABLE DEMO_FRAUD_ALERTS AS
WITH base AS (
    SELECT t.*, ABS(t.AMOUNT_GBP) AS AMT,
           AVG(ABS(t.AMOUNT_GBP)) OVER (PARTITION BY t.CUSTOMER_ID) AS CUST_AVG,
           STDDEV(ABS(t.AMOUNT_GBP)) OVER (PARTITION BY t.CUSTOMER_ID) AS CUST_SD,
           COUNT(*) OVER (PARTITION BY t.CUSTOMER_ID, DATE_TRUNC('day', t.TXN_TS)) AS SAME_DAY
    FROM BARCLAYS_DEMO.RAW_DATA.RB_TRANSACTIONS t
    WHERE t.AMOUNT_GBP < 0 AND t.CHANNEL IN ('FPS_OUT', 'CARD'))
SELECT TXN_ID, CUSTOMER_ID, TXN_TS, CHANNEL, MERCHANT, MERCHANT_COUNTRY, ROUND(AMT, 2) AS AMOUNT_GBP, IS_NEW_PAYEE,
       ROUND(LEAST(1, 0.15 * GREATEST(0, (AMT - CUST_AVG) / NULLIF(CUST_SD, 0)) + IFF(IS_NEW_PAYEE, 0.25, 0)
                   + IFF(MERCHANT_COUNTRY <> 'GB', 0.15, 0) + IFF(SAME_DAY >= 3, 0.2, 0)), 3) AS ANOMALY_SCORE,
       IS_FRAUD AS CONFIRMED_FRAUD, FRAUD_TYPE
FROM base
QUALIFY ROW_NUMBER() OVER (ORDER BY ANOMALY_SCORE DESC, AMT DESC) <= 500;

-- ---------- What customers are telling us: AI SQL on a sample of calls ----------
CREATE OR REPLACE TABLE DEMO_CALL_THEMES AS
SELECT t.CALL_ID, t.CUSTOMER_ID, t.CALL_START_TS, t.QUEUE, t.TOPIC,
       AI_SENTIMENT(t.TRANSCRIPT):categories[0]:sentiment::VARCHAR AS SENTIMENT,
       AI_CLASSIFY(t.TRANSCRIPT, ['savings rates', 'branch access', 'service complaint', 'fraud or scam',
                                  'financial difficulty', 'card or app problem', 'product question', 'account admin']):labels[0]::VARCHAR AS CALL_REASON,
       AI_COMPLETE('claude-sonnet-4-5', 'In one short sentence, what did this bank customer want, and was it resolved? ' || t.TRANSCRIPT) AS ONE_LINE_SUMMARY
FROM BARCLAYS_DEMO.RAW_DATA.RB_CALL_TRANSCRIPTS t
WHERE t.CALL_START_TS >= '2026-08-01'
QUALIFY ROW_NUMBER() OVER (PARTITION BY t.QUEUE ORDER BY t.CALL_ID) <= 12;

CREATE OR REPLACE TABLE DEMO_CALL_THEMES_SUMMARY AS
SELECT AI_AGG(TRANSCRIPT, 'These are calls to a UK retail bank. Give the 4 biggest themes as short bullet points, each with one action for the bank.') AS THEMES
FROM BARCLAYS_DEMO.RAW_DATA.RB_CALL_TRANSCRIPTS
WHERE CALL_ID IN (SELECT CALL_ID FROM DEMO_CALL_THEMES);

-- ---------- One APP scam case, worked end to end ----------
CREATE OR REPLACE TABLE DEMO_FINCRIME_CASE AS
WITH c AS (
    SELECT f.*, cu.FIRST_NAME || ' ' || cu.LAST_NAME AS CUSTOMER_NAME, cu.AGE, cu.VULNERABLE_FLAG, t.TRANSCRIPT,
           (SELECT MIN(e.FILE_NAME) FROM BARCLAYS_DEMO.RAW_DATA.RB_EVIDENCE_FILES e WHERE e.CASE_ID = f.CASE_ID AND e.EVIDENCE_TYPE = 'POLICE_REPORT_PDF') AS POLICE_PDF,
           (SELECT MIN(e.FILE_NAME) FROM BARCLAYS_DEMO.RAW_DATA.RB_EVIDENCE_FILES e WHERE e.CASE_ID = f.CASE_ID AND e.EVIDENCE_TYPE = 'PHISHING_SCREENSHOT') AS PHISHING_PNG
    FROM BARCLAYS_DEMO.RAW_DATA.RB_FRAUD_CASES f
    JOIN BARCLAYS_DEMO.RAW_DATA.RB_CUSTOMERS cu ON cu.CUSTOMER_ID = f.CUSTOMER_ID
    JOIN BARCLAYS_DEMO.RAW_DATA.RB_CALL_TRANSCRIPTS t ON t.CUSTOMER_ID = f.CUSTOMER_ID AND t.TXN_ID = f.FIRST_FRAUD_TXN_ID AND t.QUEUE = 'FRAUD'
    WHERE f.FRAUD_TYPE = 'APP_SCAM')
SELECT CASE_ID, CUSTOMER_ID, CUSTOMER_NAME, AGE, VULNERABLE_FLAG, LOSS_GBP, DECISION, REPORTED_TS, POLICE_PDF, PHISHING_PNG,
       AI_COMPLETE('claude-sonnet-4-5', CONCAT('You are a fraud operations team leader at a UK bank. Write a case summary for a senior leader in about 120 words. ',
           'Under the PSR APP scam reimbursement rules, a victim is reimbursed unless they were grossly negligent, and vulnerable customers always are. ',
           'Give: what happened, the evidence, and whether the recorded decision is supported. Then, separately, list any discrepancies between the sources as checks for the investigator, not as reasons to refuse. ',
           'Case notes: ', INVESTIGATOR_NOTES, ' Customer call: ', TRANSCRIPT, ' Age: ', AGE, '. Vulnerable customers register: ', IFF(VULNERABLE_FLAG, 'yes', 'no'),
           '. Decision recorded: ', DECISION)) AS AI_CASE_SUMMARY,
       AI_EXTRACT(file => TO_FILE('@BARCLAYS_DEMO.RETAIL.DEMO_EVIDENCE', POLICE_PDF), responseFormat => {
           'crime_reference': 'What is the police crime reference number?',
           'offence': 'What offence is being reported?',
           'loss_gbp': 'What total loss in pounds is reported?'}):response AS POLICE_REPORT_FIELDS,
       AI_COMPLETE('claude-sonnet-4-5', 'This is a screenshot of a suspected phishing message sent to a bank customer. List who it impersonates and 3 to 5 red flags, as short bullet points.',
           TO_FILE('@BARCLAYS_DEMO.RETAIL.DEMO_EVIDENCE', PHISHING_PNG)) AS PHISHING_RED_FLAGS
FROM c
WHERE POLICE_PDF IS NOT NULL AND PHISHING_PNG IS NOT NULL AND DECISION = 'REIMBURSED_PSR_RULES'
ORDER BY LOSS_GBP DESC
LIMIT 1;

SELECT 'DEMO_ATTRITION_SCORES' AS T, COUNT(*) N FROM DEMO_ATTRITION_SCORES
UNION ALL SELECT 'DEMO_AT_RISK_CUSTOMERS', COUNT(*) FROM DEMO_AT_RISK_CUSTOMERS
UNION ALL SELECT 'DEMO_FRAUD_ALERTS', COUNT(*) FROM DEMO_FRAUD_ALERTS
UNION ALL SELECT 'DEMO_CALL_THEMES', COUNT(*) FROM DEMO_CALL_THEMES
UNION ALL SELECT 'DEMO_FINCRIME_CASE', COUNT(*) FROM DEMO_FINCRIME_CASE;
