import { PageHeader } from "@/components/page-header"
import { FacilitatorBoard } from "@/components/lab/facilitator-board"
import { CHECKS } from "@/lib/checks"
import { MODULES } from "@/lib/content"

export const dynamic = "force-dynamic"

export default function FacilitatorPage() {
  const modules = MODULES.filter((m) => CHECKS[m.code]).map((m) => ({ code: m.code, checks: CHECKS[m.code].length }))
  return (
    <main className="mx-auto w-full max-w-7xl space-y-6 px-4 py-6 sm:px-6 sm:py-10 lg:px-8">
      <PageHeader
        eyebrow="Facilitator"
        title="Lab progress"
        description="Who has completed what, from every Check my work run in this account. Use it to spot attendees who are stuck."
      />
      <FacilitatorBoard modules={modules} />
    </main>
  )
}
