"use client"

import { useState } from "react"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { CheckCircle2, Circle, Database, Loader2, XCircle } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle,
} from "@/components/ui/dialog"
import { Skeleton } from "@/components/ui/skeleton"
import { formatRelative } from "@/lib/format"
import { cn } from "@/lib/utils"

type Step = { STEP_NO: number; STEP_TOTAL: number; STEP_NAME: string; STATUS: string; STARTED_AT: string | null; FINISHED_AT: string | null; ERROR_MESSAGE: string | null }
type Status = { run: { runId: string; scope: string; steps: Step[] } | null; running: boolean; admin: boolean }

const SCOPES = {
  TEXT: { label: "Reset AI and DS text data", detail: "Calls, emails, complaints, fraud cases, SARs, disputes and evidence files (AI4, AI5, DS). About 1 minute." },
  ALL: { label: "Reload all lab data", detail: "Every data set: corporate payments, retail banking, branch network and text. About 3 minutes." },
} as const
type Scope = keyof typeof SCOPES

export function DataRefresh() {
  const qc = useQueryClient()
  const [confirm, setConfirm] = useState<Scope | null>(null)
  const status = useQuery<Status>({
    queryKey: ["data-load"],
    queryFn: async () => {
      const r = await fetch("/api/data-load")
      if (!r.ok) throw new Error((await r.json()).error ?? "Failed")
      return r.json()
    },
    // poll quickly while a load runs, slowly otherwise
    refetchInterval: (q) => (q.state.data?.running ? 2_000 : 30_000),
  })
  const start = useMutation({
    mutationFn: async (scope: Scope) => {
      const r = await fetch("/api/data-load", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ scope }) })
      if (!r.ok) throw new Error((await r.json()).error ?? "Failed to start")
    },
    onSuccess: () => {
      setConfirm(null)
      // the task takes a few seconds to write its first row
      setTimeout(() => qc.invalidateQueries({ queryKey: ["data-load"] }), 3_000)
      qc.setQueryData<Status>(["data-load"], (d) => (d ? { ...d, running: true } : d))
    },
  })

  if (status.isPending) return <Skeleton className="h-40" />
  const { run, running, admin } = status.data ?? { run: null, running: false, admin: false }
  const steps = run?.steps ?? []
  const done = steps.filter((s) => s.STATUS === "DONE").length
  const failed = steps.find((s) => s.STATUS === "FAILED")
  const current = steps.find((s) => s.STATUS === "RUNNING")
  const pct = steps.length ? Math.round((100 * done) / steps.length) : 0
  const startedAt = steps.map((s) => s.STARTED_AT).filter(Boolean).sort()[0]
  const finishedAt = steps.map((s) => s.FINISHED_AT).filter(Boolean).sort().at(-1)
  const secs = startedAt && finishedAt ? Math.round((new Date(finishedAt).getTime() - new Date(startedAt).getTime()) / 1000) : null

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2"><Database className="size-4" /> Lab data</CardTitle>
        <CardDescription>
          Every data set loads inside Snowflake from the lab repository (LAB.LOAD_LAB_DATA).
          {admin ? " Reloading replaces the source tables, so do it before attendees start or between sessions." : " Facilitators can reload it from here."}
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {status.isError && <p className="text-sm text-destructive">Could not read the load status: {status.error.message}</p>}

        {run && (
          <div className="space-y-2">
            <div className="flex items-baseline justify-between text-sm">
              <span className="font-medium">
                {running
                  ? `Step ${Math.min(done + 1, steps.length)} of ${steps.length}: ${current?.STEP_NAME ?? "starting"}`
                  : failed ? `Failed at step ${failed.STEP_NO}: ${failed.STEP_NAME}`
                  : `Lab data loaded (${run.scope === "ALL" ? "all data" : run.scope === "TEXT" ? "text data" : run.scope.toLowerCase()})`}
              </span>
              <span className="text-muted-foreground">
                {running ? `${pct}%` : finishedAt ? `${formatRelative(finishedAt)}${secs !== null ? `, ${secs} s` : ""}` : ""}
              </span>
            </div>
            <div className="h-2 w-full overflow-hidden rounded-full bg-muted" role="progressbar" aria-valuenow={pct} aria-valuemin={0} aria-valuemax={100}>
              <div className={cn("h-full rounded-full transition-all duration-500", failed ? "bg-destructive" : "bg-primary")} style={{ width: `${failed ? 100 : pct}%` }} />
            </div>
            {(running || failed) && (
              <ol className="grid gap-1 text-sm sm:grid-cols-2">
                {steps.map((s) => (
                  <li key={s.STEP_NO} className={cn("flex items-center gap-2", s.STATUS === "PENDING" && "text-muted-foreground")}>
                    {s.STATUS === "DONE" ? <CheckCircle2 className="size-4 text-green-600" />
                      : s.STATUS === "RUNNING" ? <Loader2 className="size-4 animate-spin" />
                      : s.STATUS === "FAILED" ? <XCircle className="size-4 text-destructive" />
                      : <Circle className="size-4" />}
                    {s.STEP_NAME}
                  </li>
                ))}
              </ol>
            )}
            {failed?.ERROR_MESSAGE && <p className="rounded-md bg-destructive/10 p-2 font-mono text-xs text-destructive">{failed.ERROR_MESSAGE}</p>}
          </div>
        )}
        {!run && <p className="text-sm text-muted-foreground">No load recorded in this account yet.</p>}

        {admin && (
          <div className="flex flex-wrap gap-2">
            {(Object.keys(SCOPES) as Scope[]).map((s) => (
              <Button key={s} variant={s === "ALL" ? "outline" : "default"} disabled={running || start.isPending} onClick={() => setConfirm(s)}>
                {running && run?.scope === s ? <Loader2 className="size-4 animate-spin" /> : null}
                {SCOPES[s].label}
              </Button>
            ))}
          </div>
        )}
      </CardContent>

      <Dialog open={confirm !== null} onOpenChange={(o) => !o && setConfirm(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{confirm ? SCOPES[confirm].label : ""}?</DialogTitle>
            <DialogDescription>
              {confirm ? SCOPES[confirm].detail : ""} The tables are replaced with the lab&apos;s validated data, so anything
              attendees built on them should be rebuilt afterwards.
            </DialogDescription>
          </DialogHeader>
          {start.isError && <p className="text-sm text-destructive">{start.error.message}</p>}
          <DialogFooter>
            <DialogClose asChild><Button variant="outline">Cancel</Button></DialogClose>
            <Button disabled={start.isPending} onClick={() => confirm && start.mutate(confirm)}>
              {start.isPending && <Loader2 className="size-4 animate-spin" />} Start
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  )
}
