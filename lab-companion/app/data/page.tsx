import { PageHeader } from "@/components/page-header"
import { DataMap } from "@/components/lab/data-map"

export const dynamic = "force-dynamic"

export default function DataMapPage() {
  return (
    <main className="mx-auto w-full max-w-7xl space-y-6 px-4 py-6 sm:px-6 sm:py-10 lg:px-8">
      <PageHeader
        eyebrow="Data map"
        title="Everything in your account"
        description="The data products in this lab, where they live, how they join and how data flows from source to AI agent. Module C0 tours it hands-on."
      />
      <DataMap />
    </main>
  )
}
