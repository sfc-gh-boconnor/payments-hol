import Link from "next/link"
import { notFound } from "next/navigation"
import { ArrowLeft, Clock } from "lucide-react"
import { PageHeader } from "@/components/page-header"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { CheckPanel } from "@/components/lab/check-panel"
import { InlineMd } from "@/components/lab/inline-md"
import { PromptCard } from "@/components/lab/prompt-card"
import { SqlBlock } from "@/components/lab/sql-block"
import { CATCHUPS, MODULES, moduleByCode } from "@/lib/content"
import { CHECKS, PREREQS } from "@/lib/checks"
import { PrereqPanel } from "@/components/lab/prereq-panel"
import { PgConnectionPanel } from "@/components/lab/pg-connection-panel"

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
              {!PREREQS[m.code] && (
                <div className="rounded-md bg-muted/60 p-3 text-xs">
                  <span className="font-semibold">Prerequisites: </span><InlineMd text={m.prerequisites} />
                </div>
              )}
            </CardContent>
          </Card>

          {PREREQS[m.code] && <PrereqPanel code={m.code} prerequisites={m.prerequisites} />}

          <Card>
            <CardHeader><CardTitle>Steps</CardTitle></CardHeader>
            <CardContent>
              <div className="mb-5 space-y-3">
                <p className="rounded-md border border-primary/30 bg-primary/5 px-3 py-2 text-xs">
                  <span className="font-semibold">Start a new Cortex Code chat for this module</span> (<span className="font-semibold">+</span> at the top of the sidebar) and paste this first, so Cortex Code doesn&apos;t have to look for a warehouse. A fresh chat keeps Cortex Code focused.
                </p>
                <PromptCard prompt={`For this chat, use role HOL_PARTICIPANT and warehouse BARCLAYS_WH, and work in database BARCLAYS_HOL. I'm working on lab module ${m.code}: ${m.title}.`} expect="Cortex Code confirms the role and warehouse, then waits for your first prompt." />
              </div>
              <ol className="space-y-6">
                {m.steps.map((s, i) => {
                  const check = CHECKS[m.code]?.find((c) => c.id === s.checkId)
                  return (
                    <li key={s.title} className="min-w-0 space-y-3">
                      <div className="flex items-start gap-3">
                        <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-primary text-xs font-semibold text-primary-foreground">{i + 1}</span>
                        <div className="min-w-0 space-y-1">
                          <div className="font-medium"><InlineMd text={s.title} /></div>
                          {s.where && <div className="text-xs text-muted-foreground"><span className="font-semibold">Where: </span><InlineMd text={s.where} /></div>}
                          {s.body && <p className="text-sm"><InlineMd text={s.body} /></p>}
                        </div>
                      </div>
                      <div className="space-y-3 pl-9">
                        {m.code === "DE3" && s.title.startsWith("Reveal the connection") && <PgConnectionPanel />}
                        {s.prompt && <PromptCard prompt={s.prompt} expect={s.expect} pasteInto={s.pasteInto} />}
                        {s.sql && <SqlBlock sql={s.sql} path="Run in a SQL file in the Workspace" />}
                        {!s.prompt && s.expect && <p className="text-xs"><span className="font-semibold">What you should see: </span><InlineMd text={s.expect} /></p>}
                        {check && <p className="text-xs text-muted-foreground">Then press <span className="font-semibold">Check my work</span>: {check.label}</p>}
                      </div>
                    </li>
                  )
                })}
              </ol>
            </CardContent>
          </Card>

          <details className="rounded-lg border bg-card p-4">
            <summary className="cursor-pointer text-sm font-medium">Stuck? Run the reference SQL</summary>
            <p className="mt-2 text-xs text-muted-foreground">The tested script that builds everything in this module. Use it if a prompt doesn&apos;t give you a working result.</p>
            <div className="mt-3"><SqlBlock sql={m.sql} path={m.sqlPath} /></div>
          </details>

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
