// GOV3 step 1: open gov3_ai_gateway and create its notebook service (see ../notebook_service.mjs).
import { notebookServiceRun } from "../notebook_service.mjs"

export const name = "gov3_notebook_service"
export const viewport = { width: 1024, height: 640 }
export const outputWidth = 720
export const crop = undefined
export const run = notebookServiceRun("gov3_ai_gateway")
