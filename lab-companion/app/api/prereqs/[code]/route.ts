/**
 * POST /api/prereqs/<CODE> - check what a module needs before you start it.
 * Results are not recorded, so prerequisites never count as progress.
 */
import { PREREQS } from "@/lib/checks"
import { evaluateChecks } from "@/lib/lab"

export const dynamic = "force-dynamic"

export async function POST(_req: Request, { params }: { params: Promise<{ code: string }> }) {
  const { code } = await params
  if (!PREREQS[code]) return Response.json({ error: `No prerequisites for ${code}` }, { status: 404 })
  try {
    return Response.json({ results: await evaluateChecks(PREREQS[code]) })
  } catch (e) {
    console.error(new Date().toISOString(), "[prereqs] run failed", e)
    return Response.json({ error: e instanceof Error ? e.message : "Prerequisite check failed" }, { status: 500 })
  }
}
