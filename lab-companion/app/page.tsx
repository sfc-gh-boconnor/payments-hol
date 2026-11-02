import { PageHeader } from "@/components/page-header"
import { PathwayHome } from "@/components/lab/pathway-home"
import { MODULES, PATHWAYS, checkIds } from "@/lib/content"

export const dynamic = "force-dynamic"

export default function Home() {
  const modules = MODULES.map((m) => ({ code: m.code, title: m.title, minutes: m.minutes, persona: m.persona, checkIds: checkIds(m.code) }))
  return (
    <main className="mx-auto w-full max-w-7xl space-y-6 px-4 py-6 sm:px-6 sm:py-10 lg:px-8">
      <PageHeader
        eyebrow="Hands-on lab"
        title="Corporate Banking Payments Operations"
        description="Build a payments data product on Snowflake - from Snowflake-managed Iceberg sources to governed AI agents. All data is synthetic."
      />
      <PathwayHome pathways={PATHWAYS} modules={modules} />
    </main>
  )
}
