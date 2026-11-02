/** GET /api/progress - the current user's latest result for every check. */
import { currentUser, userProgress } from "@/lib/lab"

export const dynamic = "force-dynamic"

export async function GET() {
  try {
    const user = await currentUser()
    return Response.json({ user, progress: await userProgress(user) })
  } catch (e) {
    console.error(new Date().toISOString(), "[progress] failed", e)
    return Response.json({ error: e instanceof Error ? e.message : "Failed to load progress" }, { status: 500 })
  }
}
