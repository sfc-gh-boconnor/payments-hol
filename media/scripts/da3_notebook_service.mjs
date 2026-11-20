// DA3 step 1: open da3_branch_network and create its notebook service (see ../notebook_service.mjs).
import { notebookServiceRun } from "../notebook_service.mjs"

export const name = "da3_notebook_service"
export const viewport = { width: 1024, height: 640 }
export const outputWidth = 720
export const crop = undefined
export const run = notebookServiceRun("da3_branch_network")
