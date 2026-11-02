/** GET /api/facilitator - every attendee's latest check results, for the facilitator view. */
import { allProgress } from "@/lib/lab"

export const dynamic = "force-dynamic"

export async function GET() {
  try {
    return Response.json({ rows: await allProgress() })
  } catch (e) {
    console.error(new Date().toISOString(), "[facilitator] failed", e)
    return Response.json({ error: e instanceof Error ? e.message : "Failed to load progress" }, { status: 500 })
  }
}
