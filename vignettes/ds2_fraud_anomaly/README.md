# DS2: Fraud anomaly detection

| | |
|---|---|
| **Persona** | Data Scientist |
| **Time** | ~40 min |
| **Optional** | An extension to DS1: skip it if you're short of time. Uses the same notebook service, experiments and Model Registry. |
| **Prerequisites** | DS0 recommended (DS1 if you want the service already created). Uses `BARCLAYS_HOL.RAW_DATA.RB_TRANSACTIONS` and the `BARCLAYS_HOL.ML` schema |

## Business question
> New fraud patterns arrive before anyone has labelled them. Can we flag transactions that don't look like the customer, without training on labels, and how much fraud would the fraud team catch?

## What you'll build
- View `ML.RB_TXN_FEATURES`: behaviour per outgoing transaction (amount against the customer's usual, time of day, new payee, abroad, velocity, country change)
- Experiment `ML.RB_FRAUD` with two isolation forest runs, measured against the fraud labels
- Model `ML.RB_FRAUD_ANOMALY` in the Model Registry
- Table `ML.RB_FRAUD_ALERTS`: the top 0.5% most anomalous transactions, for the fraud team to review

## Steps
### Open the starter notebook
Where: the **payments-hol** Workspace > file explorer > `notebooks/ds2_fraud_anomaly.ipynb`
Media: ds2_notebook_service.mp4 | Open the notebook > service settings: NOTEBOOK_POOL, 1 hour, HOL_NOTEBOOK_ACCESS_INTEGRATION
1. Open `notebooks/` > **ds2_fraud_anomaly.ipynb** in the file explorer.
2. In the notebook toolbar, click the arrow next to the status dot and pick your service under **Select service** (usually `USER_SERVICE_1`, from DS1).
- No service yet? Choose **Create new service** and fill it in as in DS1: **NOTEBOOK_POOL**, **1 hour** idle timeout, **HOL_NOTEBOOK_ACCESS_INTEGRATION**.
3. Check the role is **HOL_PARTICIPANT** and the warehouse is **BARCLAYS_WH**.
Expect: the starter notebook open with its numbered headings, connected to your service

### Build behavioural features
Where: the Cortex Code sidebar, with `ds2_fraud_anomaly` open
```prompt
In the open notebook ds2_fraud_anomaly, put each cell I ask for under its matching numbered heading. Under heading 1, add a SQL cell named features that creates the view BARCLAYS_HOL.ML.RB_TXN_FEATURES with one row per outgoing transaction (AMOUNT_GBP below 0) in BARCLAYS_HOL.RAW_DATA.RB_TRANSACTIONS. Features: log amount, amount divided by that customer's median, hour of day, is night (midnight to 5am), is online, is new payee, is abroad, is a Faster Payment, the customer's number of payments in the previous 30 minutes, whether the country changed within 2 hours of their previous payment, and whether the customer is 65 or over (from RB_CUSTOMERS). Keep IS_FRAUD and FRAUD_TYPE for evaluation only. Run it and show the fraud rate.
```
Expect: about 1.2 million outgoing transactions, 0.4% of them labelled fraud

### Train anomaly models without labels and track them
```prompt
Under heading 2, add a Python cell named train_and_track that first sets the session's database and schema to BARCLAYS_HOL.ML (an ML Job needs them), then runs the training as a Snowflake ML Job, using the @remote decorator from snowflake.ml.jobs with compute pool DS_TRAINING_POOL and stage BARCLAYS_HOL.ML.JOB_STAGE, so the sample and models never sit in this notebook's memory. Inside the job function: get the session with get_active_session, sample 300,000 rows of RB_TXN_FEATURES, and train two scikit-learn IsolationForest models on the features only (no labels): 100 trees with contamination 0.005, and 300 trees with contamination 0.01. Track each as a run in the Snowflake experiment RB_FRAUD in BARCLAYS_HOL.ML with ExperimentTracking, using unique timestamped run names. Score with -score_samples, flag the top 0.5% as alerts, and log the parameters, AUC and average precision against IS_FRAUD, precision and recall at the 0.5% alert rate, and recall for each FRAUD_TYPE. Then log the run with the best average precision to the Model Registry in BARCLAYS_HOL.ML as RB_FRAUD_ANOMALY (sample input, metrics, target platform WAREHOUSE, a comment saying it was trained without labels), make it the default version, and return the metrics. Submit the job, wait for it, and print its status and result. Run it.
```
**Tip:** the job runs on DS_TRAINING_POOL, not your notebook service. The first one takes a few minutes while the pool starts.
**Important:** the labels never touch training. They're only there to tell you whether the model would have caught real fraud.
Expect: both runs score an AUC of about 0.99 against the labels. At a 0.5% alert rate, about 6 in 10 alerts are real fraud and about 2 in 3 to 3 in 4 frauds are caught: nearly all APP scams and account takeovers, most card testing, but only about 1 in 8 impossible-travel payments.
Check: ds2_experiment

### Register and score every transaction
```prompt
Under heading 3, add a Python cell named register_and_score that gets the default version of RB_FRAUD_ANOMALY from the Model Registry in BARCLAYS_HOL.ML, runs it with score_samples on a Snowpark DataFrame of every row of RB_TXN_FEATURES (so the scoring runs in the warehouse, not the notebook) and saves the top 0.5% most anomalous transactions to the table BARCLAYS_HOL.ML.RB_FRAUD_ALERTS with TXN_ID, CUSTOMER_ID, TXN_TS and ANOMALY_SCORE. Then add a SQL cell named alerts_by_type counting the alerts by FRAUD_TYPE (null means not labelled fraud). Run both.
```
Expect: about 6,000 alerts, about 3,800 of them labelled fraud. The rest are unusual but genuine payments, which the fraud team would clear.
Check: ds2_model_registered

### Find what the model misses
```prompt
Under heading 4, add a SQL cell named misses that shows the fraud the model didn't flag, by FRAUD_TYPE, and explains why impossible travel slips through when each payment looks normal on its own. Then test a simple rule, COUNTRY_CHANGE_2H = 1, on its own: how many transactions it flags and how many are impossible travel. Suggest how to combine the model and the rule.
```
Expect: most of the missed fraud is impossible travel. The country-change rule flags about 2,100 transactions, about 300 of them impossible travel. Models and rules work best together.
**Tip:** the alerts link to the fraud case notes, SAR narratives and evidence files in AI4, where AI SQL reads them.

## Check your work
An experiment with at least two runs, a registered anomaly model and the alerts table all exist in `BARCLAYS_HOL.ML`.

## Barclayflake note
Fraud models change often, so the registry's versions and the experiment's runs are how a bank shows which model was live when a payment was stopped, and why it was chosen.
