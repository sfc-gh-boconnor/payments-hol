"use client"

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { CheckCircle2, CircleDashed, Loader2, PlayCircle, XCircle } from "lucide-react"
import { formatRelative } from "@/lib/format"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { EmptyState } from "@/components/empty-state"
import { Skeleton } from "@/components/ui/skeleton"

type Result = { id: string; label: string; hint: string; ok?: boolean; detail?: string; at?: string }

export function CheckPanel({ code }: { code: string }) {
  const qc = useQueryClient()
  const latest = useQuery<{ results: Result[] }>({
    queryKey: ["checks", code],
    queryFn: async () => {
      const r = await fetch(`/api/checks/${code}`)
      if (!r.ok) throw new Error((await r.json()).error ?? "Failed")
      return r.json()
    },
  })
  const run = useMutation({
    mutationFn: async () => {
      const r = await fetch(`/api/checks/${code}`, { method: "POST" })
      if (!r.ok) throw new Error((await r.json()).error ?? "Check failed")
      return r.json() as Promise<{ results: Result[] }>
    },
    onSuccess: (data) => {
      qc.setQueryData(["checks", code], { results: data.results.map((r) => ({ ...r, at: new Date().toISOString() })) })
      qc.invalidateQueries({ queryKey: ["progress"] })
    },
  })

  const results = latest.data?.results ?? []
  const passed = results.filter((r) => r.ok).length

  return (
    <Card>
      <CardHeader className="flex flex-row items-start justify-between gap-3 space-y-0">
        <div className="min-w-0">
          <CardTitle>Check my work</CardTitle>
          <CardDescription>
            Validates the objects you built in this account.
            {results.length > 0 && ` ${passed} of ${results.length} passing.`}
          </CardDescription>
        </div>
        <Button onClick={() => run.mutate()} disabled={run.isPending} className="shrink-0">
          {run.isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : <PlayCircle className="h-4 w-4" />}
          {run.isPending ? "Checking" : "Run checks"}
        </Button>
      </CardHeader>
      <CardContent className="space-y-3">
        {latest.isPending && <><Skeleton className="h-12" /><Skeleton className="h-12" /></>}
        {latest.isError && <EmptyState variant="error" title="Could not load checks" description={latest.error.message} />}
        {run.isError && <EmptyState variant="error" title="Check run failed" description={run.error.message} />}
        {results.map((r) => (
          <div key={r.id} className="flex min-w-0 gap-3 rounded-md border p-3">
            {r.ok === undefined ? (
              <CircleDashed className="mt-0.5 h-5 w-5 shrink-0 text-muted-foreground" />
            ) : r.ok ? (
              <CheckCircle2 className="mt-0.5 h-5 w-5 shrink-0 text-success" />
            ) : (
              <XCircle className="mt-0.5 h-5 w-5 shrink-0 text-destructive" />
            )}
            <div className="min-w-0 flex-1">
              <div className="text-sm font-medium">{r.label}</div>
              {r.detail && <div className="truncate text-xs text-muted-foreground">{r.detail}</div>}
              {r.ok === false && <div className="mt-1 text-xs text-warning">{r.hint}</div>}
            </div>
            {r.at && <div className="shrink-0 text-xs text-muted-foreground">{formatRelative(r.at)}</div>}
          </div>
        ))}
      </CardContent>
    </Card>
  )
}
