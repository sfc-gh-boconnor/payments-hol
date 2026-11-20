/**
 * GET /api/data-map - live row counts for the tables on the Data map page.
 * Fixed query, no input: the app's own role reads INFORMATION_SCHEMA for the lab schemas.
 */
import { querySnowflake } from "@/lib/snowflake"

export const dynamic = "force-dynamic"

const QUERY = `SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT
FROM BARCLAYS_HOL.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN ('RAW_DATA', 'RETAIL', 'ANALYTICS', 'AUDIT_PACK', 'COWORK_PACK')`

export async function GET() {
  try {
    const rows = await querySnowflake(QUERY)
    const counts: Record<string, number | null> = {}
    for (const r of rows) {
      const n = r.ROW_COUNT == null ? null : Number(r.ROW_COUNT)
      counts[r.TABLE_NAME] = n
      counts[`${r.TABLE_SCHEMA}.${r.TABLE_NAME}`] = n
    }
    return Response.json({ counts })
  } catch (e) {
    console.error(new Date().toISOString(), "[data-map] failed", e)
    return Response.json({ error: "Could not read row counts" }, { status: 500 })
  }
}
