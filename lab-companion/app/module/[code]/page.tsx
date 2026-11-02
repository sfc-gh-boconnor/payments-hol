import Link from "next/link"
import { notFound } from "next/navigation"
import { ArrowLeft, Clock } from "lucide-react"
import { PageHeader } from "@/components/page-header"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { CheckPanel } from "@/components/lab/check-panel"
import { InlineMd } from "@/components/lab/inline-md"
import { SqlBlock } from "@/components/lab/sql-block"
import { CATCHUPS, MODULES, moduleByCode } from "@/lib/content"
import { CHECKS } from "@/lib/checks"

export const dynamic = "force-dynamic"

export default async function ModulePage({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params
  const m = moduleByCode(code)
  if (!m) notFound()
  const idx = MODULES.findIndex((x) => x.code === code)
  const next = MODULES[idx + 1]
  const relevantCatchups = CATCHUPS.filter((c) => m.prerequisites.includes(c.sqlPath.split("/").pop()!))

  return (
    <main className="mx-auto w-full max-w-7xl space-y-6 px-4 py-6 sm:px-6 sm:py-10 lg:px-8">
      <Button asChild variant="ghost" size="sm" className="-ml-2">
        <Link href="/"><ArrowLeft className="h-4 w-4" />All modules</Link>
      </Button>
      <PageHeader
        eyebrow={`${m.code} · ${m.persona}`}
        title={m.title}
        description={m.question}
        actions={m.minutes ? <Badge variant="outline" className="gap-1"><Clock className="h-3 w-3" />{m.minutes} min</Badge> : undefined}
      />

      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_380px]">
        <div className="min-w-0 space-y-6">
          <Card>
            <CardHeader><CardTitle>What you'll build</CardTitle></CardHeader>
            <CardContent className="space-y-4 text-sm">
              <ul className="list-disc space-y-1 pl-5">{m.build.map((b) => <li key={b}><InlineMd text={b} /></li>)}</ul>
              <div className="rounded-md bg-muted/60 p-3 text-xs">
                <span className="font-semibold">Prerequisites: </span><InlineMd text={m.prerequisites} />
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader><CardTitle>Steps</CardTitle></CardHeader>
            <CardContent>
              <ol className="list-decimal space-y-1.5 pl-5 text-sm">{m.steps.map((s) => <li key={s}><InlineMd text={s} /></li>)}</ol>
            </CardContent>
          </Card>

          <SqlBlock sql={m.sql} path={m.sqlPath} />

          {m.prompts.length > 0 && (
            <Card>
              <CardHeader><CardTitle>Try in Cortex Code</CardTitle></CardHeader>
              <CardContent className="space-y-2">
                {m.prompts.map((p) => <blockquote key={p} className="border-l-4 border-primary bg-muted/40 px-3 py-2 text-sm italic">{p}</blockquote>)}
              </CardContent>
            </Card>
          )}

          {relevantCatchups.map((c) => (
            <details key={c.sqlPath} className="rounded-lg border bg-card p-4">
              <summary className="cursor-pointer text-sm font-medium">Catch-up script: {c.name}</summary>
              <div className="mt-3"><SqlBlock sql={c.sql} path={c.sqlPath} /></div>
            </details>
          ))}
        </div>

        <aside className="min-w-0 space-y-6">
          {CHECKS[m.code] && <CheckPanel code={m.code} />}
          <Card>
            <CardHeader><CardTitle>Success looks like</CardTitle></CardHeader>
            <CardContent className="text-sm"><InlineMd text={m.check} /></CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle>At Barclays</CardTitle></CardHeader>
            <CardContent className="text-sm text-muted-foreground"><InlineMd text={m.note} /></CardContent>
          </Card>
          {next && (
            <Button asChild variant="outline" className="w-full">
              <Link href={`/module/${next.code}`}>Next: {next.code} {next.title}</Link>
            </Button>
          )}
        </aside>
      </div>
    </main>
  )
}
