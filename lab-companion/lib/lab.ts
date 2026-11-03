// Server-only: imported by route handlers and Server Components, never by client components.
import { headers } from "next/headers"
import { querySnowflake } from "@/lib/snowflake"
import { callersRightsActive } from "@/lib/run-as"
import { CHECKS, type Check } from "@/lib/checks"

export type CheckResult = { id: string; label: string; ok: boolean; detail: string; hint: string }

const PROGRESS = "BARCLAYS_HOL.LAB.LAB_PROGRESS"

/**
 * The attendee viewing the app. Snowflake App Runtime adds the caller's user
 * name to every ingress request; fall back to a caller's-rights CURRENT_USER()
 * and finally to a local-dev placeholder.
 */
export async function currentUser(): Promise<string> {
  const h = await headers()
  const fromHeader = h.get("sf-context-current-user")
  if (fromHeader) return fromHeader.toUpperCase()
  if (callersRightsActive()) {
    try {
      const [row] = await querySnowflake("SELECT CURRENT_USER() AS U", { callersRights: true })
      if (row?.U) return String(row.U)
    } catch (e) {
      console.warn(new Date().toISOString(), "[lab] could not resolve caller identity", e)
    }
  }
  const [row] = await querySnowflake("SELECT CURRENT_USER() AS U")
  return String(row?.U ?? "LOCAL_DEV")
}

/** Run every check for a module (owner's rights) and record the results for `user`. */
/** Run checks live and return the results, without recording anything. */
export async function evaluateChecks(checks: Check[]): Promise<CheckResult[]> {
  const results: CheckResult[] = []
  for (const c of checks) {
    try {
      const [row] = await querySnowflake(c.sql, c.asCaller && callersRightsActive() ? { callersRights: true } : {})
      results.push({ id: c.id, label: c.label, ok: row?.OK === true, detail: String(row?.DETAIL ?? ""), hint: c.hint })
    } catch (e) {
      // A missing object is the usual reason - report it as a failed check, not an app error.
      const msg = e instanceof Error ? e.message : String(e)
      results.push({ id: c.id, label: c.label, ok: false, detail: msg.split("\n")[0].slice(0, 200), hint: c.hint })
    }
  }
  return results
}

export async function runChecks(code: string, user: string): Promise<CheckResult[]> {
  const results = await evaluateChecks(CHECKS[code] ?? [])
  for (const r of results) {
    await querySnowflake(
      `INSERT INTO ${PROGRESS} (USER_NAME, CHECK_ID, MODULE_CODE, PASSED, DETAIL) VALUES (?, ?, ?, ?, ?)`,
      { binds: [user, r.id, code, r.ok, r.detail] },
    )
  }
  return results
}

/** Latest result per check for one user. */
export async function userProgress(user: string): Promise<Record<string, { ok: boolean; detail: string; at: string }>> {
  const rows = await querySnowflake(
    `SELECT CHECK_ID, PASSED, DETAIL, CHECKED_AT FROM ${PROGRESS}
     WHERE USER_NAME = ?
     QUALIFY ROW_NUMBER() OVER (PARTITION BY CHECK_ID ORDER BY CHECKED_AT DESC) = 1`,
    { binds: [user] },
  )
  return Object.fromEntries(rows.map((r) => [r.CHECK_ID, { ok: r.PASSED === true, detail: r.DETAIL ?? "", at: String(r.CHECKED_AT) }]))
}

/** Every user's latest result per check - for the facilitator view. */
export async function allProgress() {
  return querySnowflake(
    `SELECT USER_NAME, MODULE_CODE, CHECK_ID, PASSED, CHECKED_AT FROM ${PROGRESS}
     QUALIFY ROW_NUMBER() OVER (PARTITION BY USER_NAME, CHECK_ID ORDER BY CHECKED_AT DESC) = 1
     ORDER BY USER_NAME, MODULE_CODE`,
  )
}
