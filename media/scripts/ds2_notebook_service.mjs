// DS2 step 1: open ds2_fraud_anomaly and create its notebook service (see ../notebook_service.mjs).
import { notebookServiceRun } from "../notebook_service.mjs"

export const name = "ds2_notebook_service"
export const viewport = { width: 1024, height: 640 }
export const outputWidth = 720
export const crop = undefined
export const run = notebookServiceRun("ds2_fraud_anomaly")
