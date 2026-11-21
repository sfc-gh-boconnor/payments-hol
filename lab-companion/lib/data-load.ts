// Server-only: the "Refresh lab data" button. Loads run as Snowflake tasks
// (setup/11_lab_data_loader.sql) so a request never waits for the load itself.
import { querySnowflake } from "@/lib/snowflake"
import { callersRightsActive } from "@/lib/run-as"

const LOG = "BARCLAYS_HOL.LAB.DATA_LOAD_LOG"

/** The task each scope starts. Fixed names only: the scope never reaches SQL as text. */
export const LOAD_TASKS = {
  TEXT: "BARCLAYS_HOL.LAB.LOAD_LAB_DATA_TEXT",
  ALL: "BARCLAYS_HOL.LAB.LOAD_LAB_DATA_ALL",
} as const
export type LoadScope = keyof typeof LOAD_TASKS

export type LoadStep = {
  STEP_NO: number
  STEP_TOTAL: number
  STEP_NAME: string
  STATUS: "PENDING" | "RUNNING" | "DONE" | "FAILED"
  STARTED_AT: string | null
  FINISHED_AT: string | null
  ERROR_MESSAGE: string | null
}
export type LoadRun = { runId: string; scope: string; steps: LoadStep[] }

/**
 * Only facilitators (users granted HOL_ADMIN) may reload data: it replaces the
 * tables attendees build on. Checked with the caller's own roles; in local dev
 * the developer is treated as a facilitator.
 */
export async function isLabAdmin(): Promise<boolean> {
  if (!callersRightsActive()) return true
  try {
    const [row] = await querySnowflake(
      "SELECT ARRAY_CONTAINS('HOL_ADMIN'::VARIANT, PARSE_JSON(CURRENT_AVAILABLE_ROLES())) AS OK",
      { callersRights: true },
    )
    return row?.OK === true
  } catch (e) {
    console.warn(new Date().toISOString(), "[data-load] could not check caller roles", e)
    return false
  }
}

/** The most recent load, with every step (PENDING ones included, for the progress bar). */
export async function latestRun(): Promise<LoadRun | null> {
  const rows = await querySnowflake(
    `WITH last AS (SELECT RUN_ID FROM ${LOG} GROUP BY RUN_ID ORDER BY MAX(STARTED_AT) DESC NULLS LAST LIMIT 1)
     SELECT l.RUN_ID, l.SCOPE, l.STEP_NO, l.STEP_TOTAL, l.STEP_NAME, l.STATUS,
            l.STARTED_AT::VARCHAR AS STARTED_AT, l.FINISHED_AT::VARCHAR AS FINISHED_AT, l.ERROR_MESSAGE
     FROM ${LOG} l JOIN last USING (RUN_ID) ORDER BY l.STEP_NO`,
  )
  if (!rows.length) return null
  return { runId: rows[0].RUN_ID, scope: rows[0].SCOPE, steps: rows as LoadStep[] }
}

/** Still going: a step is running, or waiting with nothing failed. A run older than
 *  30 minutes is treated as dead (its task was cancelled or timed out). */
export function inProgress(run: LoadRun | null): boolean {
  if (!run || run.steps.some((s) => s.STATUS === "FAILED")) return false
  const started = run.steps.map((s) => s.STARTED_AT).filter(Boolean).sort()[0]
  if (started && Date.now() - new Date(started).getTime() > 30 * 60_000) return false
  return run.steps.some((s) => s.STATUS === "RUNNING" || s.STATUS === "PENDING")
}

/** Start a load. Returns false if one is already running. */
export async function startLoad(scope: LoadScope): Promise<boolean> {
  if (inProgress(await latestRun())) return false
  await querySnowflake(`EXECUTE TASK ${LOAD_TASKS[scope]}`)
  return true
}
