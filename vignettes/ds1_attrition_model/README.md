# DS1: Predict attrition with an experiment and the Model Registry

| | |
|---|---|
| **Persona** | Data Scientist |
| **Time** | ~45 min |
| **Prerequisites** | DS0 recommended. Uses the RB_ tables in `BARCLAYS_HOL.RAW_DATA` and the `BARCLAYS_HOL.ML` schema, built at provisioning |

## Business question
> Which retail customers will leave in the next 3 months, why, and who should the retention team call first?

## What you'll build
- View `ML.RB_CHURN_FEATURES`: point-in-time features observed on 31 Aug 2026, labelled with who left in the 3 months after
- Experiment `ML.RB_ATTRITION` with two tracked runs (logistic baseline and XGBoost) and their metrics
- Model `ML.RB_ATTRITION_MODEL` in the Model Registry, best run as the default version
- Table `ML.RB_ATTRITION_SCORES`: a churn probability and risk band for every customer, scored with the registered model

## Steps
### Open the starter notebook and create its service
Where: the **payments-hol** Workspace (not My Workspace) > file explorer > `notebooks/ds1_attrition_model.ipynb`
Media: ds1_notebook_service.mp4 | Open the notebook > Create new service > NOTEBOOK_POOL, 1 hour, HOL_NOTEBOOK_ACCESS_INTEGRATION
1. Open `notebooks/` > **ds1_attrition_model.ipynb** in the file explorer.
- Can't see `notebooks/` and `vignettes/`? You're in the wrong Workspace. Pick **payments-hol** from the Workspace dropdown (top left).
2. In the notebook toolbar, click the arrow next to the status dot (right of the blue run button).
3. Choose **Create new service**.
- Already created one in another module? Pick it under **Select service** instead, usually `USER_SERVICE_1`.
4. Expand **Service settings** in **Connect your notebook** and fill it in as below. Only the three **bold** rows change.
| Setting | Value |
|---|---|
| Service name | leave the default (e.g. `USER_SERVICE_1`) |
| Runtime | leave as is (v3.0 · Python 3.12) |
| Compute type | CPU |
| **Compute pool** | **NOTEBOOK_POOL** (change it from HOL_COMPUTE_POOL_CPU) |
| **Idle timeout** | **1 hour** (change it from 24 hours) |
| **External access integrations** | **HOL_NOTEBOOK_ACCESS_INTEGRATION** |
5. Click **Create and connect**. The first start takes 1-2 minutes.
6. Check the role is **HOL_PARTICIPANT** and the warehouse is **BARCLAYS_WH** (role and warehouse button in the notebook toolbar).
The notebook runtime already has `snowflake-ml-python`, scikit-learn and XGBoost.
Expect: the starter notebook open in payments-hol with its numbered headings, and the status dot showing the service connected

### Build point-in-time features
Where: the Cortex Code sidebar, with `ds1_attrition_model` open
```prompt
In the open notebook ds1_attrition_model, put each cell I ask for under its matching numbered heading. Under heading 1, add a SQL cell named features that creates the view BARCLAYS_HOL.ML.RB_CHURN_FEATURES with one row per retail customer who was still a customer on the observation date 31 Aug 2026. Use only data from on or before that date: tenure, age, segment, IMD decile, housing tenure, credit score, digital active, whether their home branch is one of BR-MAN-90, BR-LDS-90 or BR-CDF-90, drive minutes to it, and from RB_MONTHLY_SNAPSHOT the last 3 months' average logins, branch visits and card spend, latest balances and products held, salary trend (last 3 months against the 3 before), and from RB_ACCOUNTS joined to RB_PRODUCTS the lowest savings rate and whether they hold a legacy saver. The label CHURNED_NEXT_3M is 1 if CHURN_DATE falls in the 3 months after the observation date. Don't use CHURNED, CHURN_REASON, CHURNED_FLAG, CLOSED_DATE or STATUS. Then add a SQL cell named class_balance and run both.
```
**Important:** the label comes from after the observation date, and every feature from before it. That's what stops the model seeing the future.
Expect: about 18,400 customers, of whom about 2% leave in the next 3 months
Check: ds1_features

### Train two models and track them in an experiment
```prompt
Under heading 2, add a Python cell named load that reads RB_CHURN_FEATURES into pandas with the active Snowpark session, and a cell named train_and_track that splits 70/30 stratified, then trains a logistic regression baseline (balanced class weights, scaled features) and an XGBoost classifier (scale_pos_weight for the imbalance) as scikit-learn pipelines. Track each as a run in the Snowflake experiment RB_ATTRITION in BARCLAYS_HOL.ML using snowflake.ml.experiment.ExperimentTracking: log parameters including the observation date, and metrics AUC, average precision, precision in the top decile and lift in the top decile. Give each run a unique name with a timestamp, because finished runs can't be reopened. Run both cells.
```
Then compare the runs:
1. Open **AI & ML > Experiments** in Snowsight (in a new browser tab).
2. Open **RB_ATTRITION**, tick both runs and press **Compare**.
**Tip:** accuracy would be about 98% for a model that predicts nobody leaves. Lift in the top decile is what the retention team cares about.
Expect: two finished runs. XGBoost scores an AUC of about 0.87 against about 0.86 for the baseline, and its top decile holds about 7 times the average rate of leavers.
Check: ds1_experiment

### Register the best model
```prompt
Under heading 3, add a Python cell named register that picks the run with the best AUC and logs its pipeline to the Snowflake Model Registry (snowflake.ml.registry.Registry) in BARCLAYS_HOL.ML as model RB_ATTRITION_MODEL, with its metrics, sample input data, target platform WAREHOUSE and a comment naming the experiment and observation date. Let the registry generate the version name, then make the new version the default. Run it and show the model's versions.
```
Then look at it: **AI & ML > Models** > **RB_ATTRITION_MODEL** shows the version, its metrics and the comment.
Expect: RB_ATTRITION_MODEL with one version (more if you re-run), metrics attached and set as the default
Check: ds1_model_registered

### Score every customer
```prompt
Under heading 4, add a Python cell named score that runs the default version of RB_ATTRITION_MODEL from the registry with predict_proba on every row of RB_CHURN_FEATURES, and writes CUSTOMER_ID, CHURN_PROBABILITY and RISK_BAND (HIGH for the top 5%, MEDIUM for the next 15%, LOW otherwise) to the table BARCLAYS_HOL.ML.RB_ATTRITION_SCORES. Then add a SQL cell named risk_bands showing, per band, the customer count, average probability and the actual share who left. Run both.
```
Expect: about 900 HIGH, 2,800 MEDIUM and 14,800 LOW customers. About a third of the HIGH band really did leave, against about 2% overall.
Check: ds1_scored

### Explain the drivers
```prompt
Under heading 5, add a Python cell named drivers that shows the XGBoost feature importances as a bar chart and explains the top five in plain English for a retention manager. Then add a SQL cell named retention_list that joins RB_ATTRITION_SCORES to RB_CUSTOMERS and RETAIL.BRANCHES for the 20 HIGH-risk customers with the highest probability: name, city, home branch, products held and a suggested retention action for each. Run both.
```
Expect: the top drivers include complaints, short tenure, falling salary credits and branch reliance at a closure branch, then a call list of 20 customers with an action each

## Check your work
The feature view, an experiment with at least two runs, a registered model and the scores table all exist in `BARCLAYS_HOL.ML`.

## Barclayflake note
At Barclays a model like this goes to model risk review before anyone acts on it. Here, the review evidence comes built in: the experiment holds every run that was tried, the registry holds the exact version that scored customers, and lineage links the two.
