/**
 * POST /api/de3/pg-connection - the attendee's Postgres connection for DE3.
 * BARCLAYS_HOL.LAB.PG_CONNECTION_INFO() (owner's rights, owned by HOL_ADMIN) reads the
 * secret the notebook saved when it created HOL_PAYMENTS_PG. The password is only in the
 * response body: never logged, never cached.
 */
import { querySnowflake } from "@/lib/snowflake"

export const dynamic = "force-dynamic"

const NO_STORE = { "Cache-Control": "no-store" }

export type PgConnection = {
  ready: boolean
  state?: string
  message?: string
  host?: string
  port?: number
  database?: string
  user?: string
  password?: string
}

export async function POST() {
  try {
    const rows = await querySnowflake("CALL BARCLAYS_HOL.LAB.PG_CONNECTION_INFO()")
    const value = rows[0] ? Object.values(rows[0])[0] : undefined
    const info: PgConnection = typeof value === "string" ? JSON.parse(value) : value
    if (!info) return Response.json({ error: "No connection information returned" }, { status: 500, headers: NO_STORE })
    return Response.json(info, { headers: NO_STORE })
  } catch (e) {
    // Don't log the error object: keep anything secret out of the logs
    console.error(new Date().toISOString(), "[de3/pg-connection] reveal failed")
    const message = e instanceof Error && /does not exist|not authorized/i.test(e.message)
      ? "The reveal procedure isn't installed. Ask the facilitator to rerun setup/00_admin_provision.sql."
      : "Couldn't read the Postgres connection"
    return Response.json({ error: message }, { status: 500, headers: NO_STORE })
  }
}
