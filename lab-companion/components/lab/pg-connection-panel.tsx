"use client"

import { useState } from "react"
import { useMutation } from "@tanstack/react-query"
import { Check, Copy, Eye, EyeOff, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { EmptyState } from "@/components/empty-state"
import { copyText } from "@/lib/clipboard"
import type { PgConnection } from "@/app/api/de3/pg-connection/route"

function Field({ label, value, secret }: { label: string; value: string; secret?: boolean }) {
  const [copied, setCopied] = useState(false)
  const [shown, setShown] = useState(!secret)
  return (
    <div className="flex min-w-0 items-center gap-2 rounded-md border p-2">
      <span className="w-20 shrink-0 text-xs font-semibold">{label}</span>
      <code className="min-w-0 flex-1 truncate text-xs">{shown ? value : "•".repeat(16)}</code>
      {secret && (
        <Button variant="ghost" size="sm" onClick={() => setShown(!shown)} aria-label={shown ? "Hide" : "Show"}>
          {shown ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
        </Button>
      )}
      <Button
        variant="ghost"
        size="sm"
        aria-label={`Copy ${label}`}
        onClick={async () => {
          if (await copyText(value)) {
            setCopied(true)
            setTimeout(() => setCopied(false), 1500)
          }
        }}
      >
        {copied ? <Check className="h-4 w-4 text-success" /> : <Copy className="h-4 w-4" />}
      </Button>
    </div>
  )
}

/** DE3: reveal the HOL_PAYMENTS_PG host, user and password the notebook saved to a secret. */
export function PgConnectionPanel() {
  const reveal = useMutation({
    mutationFn: async () => {
      const r = await fetch("/api/de3/pg-connection", { method: "POST", cache: "no-store" })
      const body = await r.json()
      if (!r.ok) throw new Error(body.error ?? "Reveal failed")
      return body as PgConnection
    },
  })
  const info = reveal.data

  return (
    <div className="space-y-3 rounded-md border border-primary/30 bg-primary/5 p-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-xs">
          <span className="font-semibold">Your Postgres connection.</span> Keep the password private: don&apos;t paste it into chats or screenshots.
        </p>
        <Button variant="outline" size="sm" onClick={() => reveal.mutate()} disabled={reveal.isPending}>
          {reveal.isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : <Eye className="h-4 w-4" />}
          {info ? "Reveal again" : "Reveal Postgres connection"}
        </Button>
      </div>
      {reveal.isError && <EmptyState variant="error" title="Couldn't reveal the connection" description={reveal.error.message} />}
      {info && !info.password && <p className="text-xs text-warning">{info.message}</p>}
      {info?.password && (
        <div className="space-y-2">
          {!info.ready && <p className="text-xs text-warning">HOL_PAYMENTS_PG is {info.state}: wait until it&apos;s READY before connecting.</p>}
          <Field label="PG_HOST" value={info.host ?? ""} />
          <Field label="PG_USER" value={info.user ?? ""} />
          <Field label="PG_PASS" value={info.password} secret />
          <p className="text-xs text-muted-foreground">Port {info.port}, database {info.database}, SSL required.</p>
        </div>
      )}
    </div>
  )
}
