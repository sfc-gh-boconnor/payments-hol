import { PageHeader } from "@/components/page-header"
import { PathwayHome } from "@/components/lab/pathway-home"
import { Welcome } from "@/components/lab/welcome"
import { MODULES, PATHWAYS, checkIds } from "@/lib/content"

export const dynamic = "force-dynamic"

export default function Home() {
  const modules = MODULES.map((m) => ({ code: m.code, title: m.title, minutes: m.minutes, persona: m.persona, checkIds: checkIds(m.code) }))
  return (
    <main className="mx-auto w-full max-w-7xl space-y-6 px-4 py-6 sm:px-6 sm:py-10 lg:px-8">
      <PageHeader
        eyebrow="Hands-on lab"
        title="Banking Data Products with Cortex Code"
        description="Payments, client 360, customer voice and branch network data products on Snowflake, from Iceberg sources to governed AI agents."
      />
      <Welcome />
      <PathwayHome pathways={PATHWAYS} modules={modules} />
    </main>
  )
}
