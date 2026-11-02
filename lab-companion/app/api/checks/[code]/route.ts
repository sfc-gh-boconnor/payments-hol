/**
 * POST /api/checks/<CODE> - run "Check my work" for one module and record the results.
 * GET  /api/checks/<CODE> - the current user's latest results for that module.
 */
import { CHECKS } from "@/lib/checks"
import { currentUser, runChecks, userProgress } from "@/lib/lab"

export const dynamic = "force-dynamic"

type Ctx = { params: Promise<{ code: string }> }

export async function POST(_req: Request, { params }: Ctx) {
  const { code } = await params
  if (!CHECKS[code]) return Response.json({ error: `Unknown module ${code}` }, { status: 404 })
  try {
    const user = await currentUser()
    const results = await runChecks(code, user)
    return Response.json({ user, results })
  } catch (e) {
    console.error(new Date().toISOString(), "[checks] run failed", e)
    return Response.json({ error: e instanceof Error ? e.message : "Check failed" }, { status: 500 })
  }
}

export async function GET(_req: Request, { params }: Ctx) {
  const { code } = await params
  if (!CHECKS[code]) return Response.json({ error: `Unknown module ${code}` }, { status: 404 })
  try {
    const user = await currentUser()
    const progress = await userProgress(user)
    const results = CHECKS[code].map((c) => ({ id: c.id, label: c.label, hint: c.hint, ...(progress[c.id] ?? null) }))
    return Response.json({ user, results })
  } catch (e) {
    console.error(new Date().toISOString(), "[checks] read failed", e)
    return Response.json({ error: e instanceof Error ? e.message : "Failed to load progress" }, { status: 500 })
  }
}
