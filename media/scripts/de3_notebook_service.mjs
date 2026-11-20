// DE3 step 1: open de3_realtime_payments and create its notebook service (see ../notebook_service.mjs).
import { notebookServiceRun } from "../notebook_service.mjs"

export const name = "de3_notebook_service"
export const viewport = { width: 1024, height: 640 }
export const outputWidth = 720
export const crop = undefined
export const run = notebookServiceRun("de3_realtime_payments")
