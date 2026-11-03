"use client"

import { useMutation } from "@tanstack/react-query"
import { CheckCircle2, ClipboardCheck, Loader2, XCircle } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { EmptyState } from "@/components/empty-state"
import { InlineMd } from "@/components/lab/inline-md"

type Result = { id: string; label: string; hint: string; ok: boolean; detail: string }

/** "Before you start": checks the objects a module builds on. Not recorded as progress. */
export function PrereqPanel({ code, prerequisites }: { code: string; prerequisites: string }) {
  const run = useMutation({
    mutationFn: async () => {
      const r = await fetch(`/api/prereqs/${code}`, { method: "POST" })
      if (!r.ok) throw new Error((await r.json()).error ?? "Check failed")
      return r.json() as Promise<{ results: Result[] }>
    },
  })
  const results = run.data?.results ?? []
  const allOk = results.length > 0 && results.every((r) => r.ok)

  return (
    <Card>
      <CardHeader className="flex flex-row items-start justify-between gap-3 space-y-0">
        <div className="min-w-0">
          <CardTitle>Before you start</CardTitle>
          <CardDescription>
            <span className="font-semibold">Prerequisites: </span><InlineMd text={prerequisites} />
          </CardDescription>
        </div>
        <Button variant="outline" onClick={() => run.mutate()} disabled={run.isPending} className="shrink-0">
          {run.isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : <ClipboardCheck className="h-4 w-4" />}
          {run.isPending ? "Checking" : "Check prerequisites"}
        </Button>
      </CardHeader>
      {(results.length > 0 || run.isError) && (
        <CardContent className="space-y-3">
          {run.isError && <EmptyState variant="error" title="Prerequisite check failed" description={run.error.message} />}
          {allOk && <p className="text-sm font-medium text-success">You&apos;re ready to start this module.</p>}
          {results.map((r) => (
            <div key={r.id} className="flex min-w-0 gap-3 rounded-md border p-3">
              {r.ok ? <CheckCircle2 className="mt-0.5 h-5 w-5 shrink-0 text-success" /> : <XCircle className="mt-0.5 h-5 w-5 shrink-0 text-destructive" />}
              <div className="min-w-0 flex-1">
                <div className="text-sm font-medium">{r.label}</div>
                {r.detail && <div className="truncate text-xs text-muted-foreground">{r.detail}</div>}
                {!r.ok && <div className="mt-1 text-xs text-warning">{r.hint}</div>}
              </div>
            </div>
          ))}
        </CardContent>
      )}
    </Card>
  )
}
