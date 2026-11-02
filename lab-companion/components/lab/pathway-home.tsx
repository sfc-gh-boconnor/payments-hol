"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { useQuery } from "@tanstack/react-query"
import { ArrowRight, CheckCircle2, Clock } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { cn } from "@/lib/utils"

type ModuleSummary = { code: string; title: string; minutes: number | null; persona: string; checkIds: string[] }
type Progress = Record<string, { ok: boolean }>

export function PathwayHome({
  pathways,
  modules,
}: {
  pathways: Record<string, { blurb: string; modules: string[] }>
  modules: ModuleSummary[]
}) {
  const names = Object.keys(pathways)
  const [persona, setPersona] = useState<string | null>(null)
  useEffect(() => setPersona(localStorage.getItem("hol_persona")), [])
  const choose = (p: string) => {
    setPersona(p)
    localStorage.setItem("hol_persona", p)
  }

  const progress = useQuery<{ user: string; progress: Progress }>({
    queryKey: ["progress"],
    queryFn: async () => {
      const r = await fetch("/api/progress")
      if (!r.ok) throw new Error((await r.json()).error ?? "Failed")
      return r.json()
    },
  })
  const done = (m: ModuleSummary) => {
    const p = progress.data?.progress ?? {}
    const passed = m.checkIds.filter((id) => p[id]?.ok).length
    return { passed, total: m.checkIds.length }
  }

  const byCode = Object.fromEntries(modules.map((m) => [m.code, m]))
  const path = persona && pathways[persona]
  const others = path ? modules.filter((m) => !path.modules.includes(m.code)) : modules

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Choose your pathway</CardTitle>
          <CardDescription>
            Everyone starts with C1. Each vignette stands alone - if it lists a prerequisite you have not built, run the catch-up script it names.
            {progress.data?.user && <> Signed in as <strong>{progress.data.user}</strong>.</>}
          </CardDescription>
        </CardHeader>
        <CardContent className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          {names.map((p) => (
            <button
              key={p}
              onClick={() => choose(p)}
              className={cn(
                "min-w-0 rounded-lg border p-3 text-left transition-colors hover:border-primary",
                persona === p && "border-primary bg-primary/5 ring-1 ring-primary",
              )}
            >
              <div className="text-sm font-semibold">{p}</div>
              <div className="mt-1 text-xs text-muted-foreground">{pathways[p].blurb}</div>
            </button>
          ))}
        </CardContent>
      </Card>

      {path && (
        <section className="space-y-3">
          <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">{persona} pathway</h2>
          <div className="grid gap-3">
            {path.modules.map((code, i) => byCode[code] && (
              <ModuleRow key={code} m={byCode[code]} step={i + 1} {...done(byCode[code])} />
            ))}
          </div>
        </section>
      )}

      <section className="space-y-3">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-muted-foreground">
          {path ? "Other vignettes" : "All modules"}
        </h2>
        <div className="grid gap-3 md:grid-cols-2">
          {others.map((m) => <ModuleRow key={m.code} m={m} {...done(m)} compact />)}
        </div>
      </section>
    </div>
  )
}

function ModuleRow({ m, step, passed, total, compact }: { m: ModuleSummary; step?: number; passed: number; total: number; compact?: boolean }) {
  const complete = total > 0 && passed === total
  return (
    <Link href={`/module/${m.code}`} className="group min-w-0">
      <div className={cn("flex min-w-0 items-center gap-4 rounded-lg border bg-card p-4 transition-colors group-hover:border-primary", compact && "p-3")}>
        {step !== undefined && (
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-muted text-sm font-semibold">{step}</div>
        )}
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2">
            <span className="text-sm font-bold text-primary">{m.code}</span>
            <span className="truncate text-sm font-medium">{m.title}</span>
          </div>
          <div className="mt-0.5 flex items-center gap-3 text-xs text-muted-foreground">
            <span>{m.persona}</span>
            {m.minutes && <span className="flex items-center gap-1"><Clock className="h-3 w-3" />{m.minutes} min</span>}
          </div>
        </div>
        {total > 0 && (
          complete
            ? <Badge variant="success" className="shrink-0 gap-1"><CheckCircle2 className="h-3 w-3" />Complete</Badge>
            : <Badge variant="outline" className="shrink-0">{passed}/{total} checks</Badge>
        )}
        <Button variant="ghost" size="icon" className="shrink-0" tabIndex={-1}><ArrowRight className="h-4 w-4" /></Button>
      </div>
    </Link>
  )
}
