"""DS2 reference solution: an unsupervised fraud anomaly model, tracked and registered.

The answer key for notebooks/ds2_fraud_anomaly.ipynb. Trains an isolation forest on behaviour only
(no labels), then uses IS_FRAUD just to measure it. Runs inside Snowflake on the active session; submit_job() runs it as an ML Job on DS_TRAINING_POOL.
"""
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.metrics import average_precision_score, roc_auc_score
from snowflake.ml.experiment import ExperimentTracking
from snowflake.ml.registry import Registry
from snowflake.snowpark import functions as F
from snowflake.snowpark.context import get_active_session

DB, SCHEMA = "BARCLAYS_HOL", "ML"
FEATURES = ["LOG_AMOUNT", "AMOUNT_VS_USUAL", "HOUR_OF_DAY", "IS_NIGHT", "IS_ONLINE", "IS_NEW_PAYEE", "IS_ABROAD",
            "IS_FASTER_PAYMENT", "TXNS_PRIOR_30M", "COUNTRY_CHANGE_2H", "CUSTOMER_65_PLUS"]
ALERT_RATE = 0.005  # the fraud team can review the top 0.5% of transactions


def main(session):
    session.use_schema(f"{DB}.{SCHEMA}")
    feats = session.table("RB_TXN_FEATURES")
    # 1. Train on a sample of behaviour; labels stay out of training
    sample = feats.sample(n=300_000).to_pandas()
    X = sample[FEATURES].astype(float).fillna(0)
    y = sample.IS_FRAUD.astype(int)

    exp = ExperimentTracking(session, database_name=DB, schema_name=SCHEMA)
    exp.set_experiment("RB_FRAUD")
    stamp = pd.Timestamp.now().strftime("%m%d_%H%M%S")  # finished runs are immutable: a rerun gets new run names
    results = {}
    for trees, contamination in [(100, 0.005), (300, 0.01)]:
        run = f"IFOREST_{trees}_{stamp}"
        with exp.start_run(run):
            model = IsolationForest(n_estimators=trees, contamination=contamination, random_state=42).fit(X)
            score = -model.score_samples(X)  # higher = more anomalous
            flagged = score >= np.quantile(score, 1 - ALERT_RATE)
            by_type = sample.assign(flag=flagged)[sample.IS_FRAUD == 1].groupby("FRAUD_TYPE").flag.mean()
            metrics = {"auc_vs_labels": round(roc_auc_score(y, score), 4), "avg_precision": round(average_precision_score(y, score), 4),
                       "precision_at_alert_rate": round(float(y[flagged].mean()), 4), "recall_at_alert_rate": round(float(flagged[y == 1].mean()), 4)}
            metrics.update({f"recall_{k.lower()}": round(float(v), 4) for k, v in by_type.items()})
            exp.log_params({"model": "isolation_forest", "n_estimators": trees, "contamination": contamination,
                            "alert_rate": ALERT_RATE, "training_rows": len(X), "labels_used_in_training": "none"})
            exp.log_metrics(metrics)
            results[run] = (model, metrics)

    # 2. Register the best run
    best = max(results, key=lambda r: results[r][1]["avg_precision"])
    model, metrics = results[best]
    reg = Registry(session, database_name=DB, schema_name=SCHEMA)
    mv = reg.log_model(model, model_name="RB_FRAUD_ANOMALY", sample_input_data=X.head(50), metrics=metrics,
                       target_platforms=["WAREHOUSE"],
                       comment=f"{best}: isolation forest on transaction behaviour, trained without labels. Experiment RB_FRAUD.")
    reg.get_model("RB_FRAUD_ANOMALY").default = mv.version_name

    # 3. Score every transaction in Snowflake and keep the top 0.5% as alerts
    scored = mv.run(feats.select("TXN_ID", "CUSTOMER_ID", "TXN_TS", *[F.col(c).cast("float").alias(c) for c in FEATURES]),
                    function_name="score_samples")
    out_col = [c for c in scored.columns if c not in ["TXN_ID", "CUSTOMER_ID", "TXN_TS", *FEATURES]][0]
    scored = scored.with_column("ANOMALY_SCORE", -F.col(out_col)).select("TXN_ID", "CUSTOMER_ID", "TXN_TS", "ANOMALY_SCORE")
    cutoff = scored.approx_quantile("ANOMALY_SCORE", [1 - ALERT_RATE])[0]
    scored.filter(F.col("ANOMALY_SCORE") >= cutoff).write.save_as_table("RB_FRAUD_ALERTS", mode="overwrite")
    return {run: m for run, (_, m) in results.items()} | {"registered": f"RB_FRAUD_ANOMALY {mv.version_name}"}


def submit_job(session):
    """Run main() as an ML Job on DS_TRAINING_POOL (3 vCPU, 13 GiB), so the notebook kernel
    on the small NOTEBOOK_POOL never holds the training data or models in memory."""
    import sys
    import cloudpickle
    from snowflake.ml.jobs import remote

    if __name__ != "__main__":  # imported as a module: send its code with the job
        cloudpickle.register_pickle_by_value(sys.modules[__name__])

    @remote("DS_TRAINING_POOL", stage_name="BARCLAYS_HOL.ML.JOB_STAGE", session=session)
    def train_ds2():
        from snowflake.snowpark.context import get_active_session as active
        return main(active())

    job = train_ds2()
    job.wait()  # first run starts the pool: a few minutes
    print(job.status)
    return job.result()


if __name__ == "__main__":
    print(submit_job(get_active_session()))
