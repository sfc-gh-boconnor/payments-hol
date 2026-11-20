"""DS1 reference solution: train, track and register the attrition model.

The answer key for notebooks/ds1_attrition_model.ipynb, the same steps Cortex Code builds.
Runs inside Snowflake on the active session; submit_job() runs it as an ML Job on DS_TRAINING_POOL.
Needs snowflake-ml-python >= 1.19 and xgboost.
"""
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import average_precision_score, roc_auc_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from snowflake.ml.experiment import ExperimentTracking
from snowflake.ml.registry import Registry
from snowflake.snowpark.context import get_active_session
from xgboost import XGBClassifier

DB, SCHEMA = "BARCLAYS_HOL", "ML"


def main(session):
    session.use_schema(f"{DB}.{SCHEMA}")
    # 1. Point-in-time features (the view from ds1.sql)
    df = session.table(f"{DB}.{SCHEMA}.RB_CHURN_FEATURES").to_pandas()
    y = df.pop("CHURNED_NEXT_3M").astype(int)
    ids = df.pop("CUSTOMER_ID")
    cat = ["SEGMENT", "HOUSING_TENURE"]
    num = [c for c in df.columns if c not in cat]
    df[num] = df[num].apply(pd.to_numeric, errors="coerce").fillna(0).astype(float)
    X_tr, X_te, y_tr, y_te = train_test_split(df, y, test_size=0.3, stratify=y, random_state=42)

    def evaluate(model):
        p = model.predict_proba(X_te)[:, 1]
        top = np.argsort(-p)[: len(p) // 10]
        return {"auc": round(roc_auc_score(y_te, p), 4), "avg_precision": round(average_precision_score(y_te, p), 4),
                "precision_top_decile": round(float(y_te.iloc[top].mean()), 4),
                "lift_top_decile": round(float(y_te.iloc[top].mean() / y_te.mean()), 2)}

    prep = ColumnTransformer([("num", StandardScaler(), num), ("cat", OneHotEncoder(handle_unknown="ignore"), cat)])
    candidates = {
        "LOGISTIC_BASELINE": (Pipeline([("prep", prep), ("clf", LogisticRegression(max_iter=2000, class_weight="balanced"))]),
                              {"model": "logistic_regression", "class_weight": "balanced"}),
        "XGBOOST": (Pipeline([("prep", prep), ("clf", XGBClassifier(n_estimators=300, max_depth=4, learning_rate=0.05, subsample=0.8,
                                                                    scale_pos_weight=float((y_tr == 0).sum() / (y_tr == 1).sum())))]),
                    {"model": "xgboost", "n_estimators": 300, "max_depth": 4, "learning_rate": 0.05}),
    }

    # 2. Track both runs in a Snowflake experiment
    exp = ExperimentTracking(session, database_name=DB, schema_name=SCHEMA)
    exp.set_experiment("RB_ATTRITION")
    results = {}
    stamp = pd.Timestamp.now().strftime("%m%d_%H%M%S")  # finished runs are immutable: a rerun gets new run names
    for run, (model, params) in candidates.items():
        with exp.start_run(f"{run}_{stamp}"):
            model.fit(X_tr, y_tr)
            metrics = evaluate(model)
            exp.log_params({**params, "observation_date": "2026-08-31", "label_window_months": 3})
            exp.log_metrics(metrics)
            results[run] = (model, metrics)

    # 3. Register the best run in the Model Registry
    best = max(results, key=lambda r: results[r][1]["auc"])
    model, metrics = results[best]
    reg = Registry(session, database_name=DB, schema_name=SCHEMA)
    mv = reg.log_model(model, model_name="RB_ATTRITION_MODEL",  # version name auto-generated, so re-runs add a version
                       sample_input_data=X_tr.head(50), metrics=metrics, target_platforms=["WAREHOUSE"],
                       comment=f"{best}: attrition in the next 3 months, observed 2026-08-31. Best of {len(results)} runs in experiment RB_ATTRITION.")
    reg.get_model("RB_ATTRITION_MODEL").default = mv.version_name

    # 4. Score every customer with the registered model, inside Snowflake
    scored = mv.run(df, function_name="predict_proba")
    prob = scored.iloc[:, -1].to_numpy()
    out = pd.DataFrame({"CUSTOMER_ID": ids.values, "CHURN_PROBABILITY": prob})
    out["RISK_BAND"] = np.select([out.CHURN_PROBABILITY.rank(pct=True) > 0.95, out.CHURN_PROBABILITY.rank(pct=True) > 0.8], ["HIGH", "MEDIUM"], "LOW")
    session.write_pandas(out, "RB_ATTRITION_SCORES", database=DB, schema=SCHEMA, auto_create_table=True, overwrite=True)
    return {run: m for run, (_, m) in results.items()} | {"registered": f"RB_ATTRITION_MODEL {mv.version_name}"}


def submit_job(session):
    """Run main() as an ML Job on DS_TRAINING_POOL (3 vCPU, 13 GiB), so the notebook kernel
    on the small NOTEBOOK_POOL never holds the training data or models in memory."""
    import sys
    import cloudpickle
    from snowflake.ml.jobs import remote

    if __name__ != "__main__":  # imported as a module: send its code with the job
        cloudpickle.register_pickle_by_value(sys.modules[__name__])

    @remote("DS_TRAINING_POOL", stage_name="BARCLAYS_HOL.ML.JOB_STAGE", session=session)
    def train_ds1():
        from snowflake.snowpark.context import get_active_session as active
        return main(active())

    job = train_ds1()
    job.wait()  # first run starts the pool: a few minutes
    print(job.status)
    return job.result()


if __name__ == "__main__":
    print(submit_job(get_active_session()))
