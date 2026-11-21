/**
 * GET  /api/data-load  - the latest lab data load and its steps, plus whether the caller may start one
 * POST /api/data-load  - { scope: "TEXT" | "ALL" } starts a load (facilitators only)
 */
import { inProgress, isLabAdmin, latestRun, LOAD_TASKS, startLoad, type LoadScope } from "@/lib/data-load"

export const dynamic = "force-dynamic"

export async function GET() {
  try {
    const [run, admin] = await Promise.all([latestRun(), isLabAdmin()])
    return Response.json({ run, running: inProgress(run), admin })
  } catch (e) {
    console.error(new Date().toISOString(), "[data-load] status failed", e)
    return Response.json({ error: e instanceof Error ? e.message : "Failed to load status" }, { status: 500 })
  }
}

export async function POST(req: Request) {
  const { scope } = (await req.json().catch(() => ({}))) as { scope?: string }
  if (!scope || !(scope in LOAD_TASKS)) return Response.json({ error: "scope must be TEXT or ALL" }, { status: 400 })
  if (!(await isLabAdmin())) return Response.json({ error: "Only facilitators (HOL_ADMIN) can refresh lab data" }, { status: 403 })
  try {
    if (!(await startLoad(scope as LoadScope))) return Response.json({ error: "A load is already running" }, { status: 409 })
    return Response.json({ started: true })
  } catch (e) {
    console.error(new Date().toISOString(), "[data-load] start failed", e)
    return Response.json({ error: e instanceof Error ? e.message : "Failed to start the load" }, { status: 500 })
  }
}
