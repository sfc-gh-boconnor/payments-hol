"use client"

import { useState } from "react"
import { Check, Copy } from "lucide-react"
import { copyText } from "@/lib/clipboard"
import { Button } from "@/components/ui/button"

export function SqlBlock({ sql, path }: { sql: string; path: string }) {
  const [copied, setCopied] = useState(false)
  return (
    <div className="min-w-0 overflow-hidden rounded-lg border">
      <div className="flex items-center justify-between gap-2 border-b bg-muted/60 px-3 py-2">
        <code className="truncate text-xs text-muted-foreground">{path}</code>
        <Button
          size="sm"
          variant="outline"
          onClick={async () => {
            if (await copyText(sql)) {
              setCopied(true)
              setTimeout(() => setCopied(false), 1500)
            }
          }}
        >
          {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
          {copied ? "Copied" : "Copy SQL"}
        </Button>
      </div>
      <pre className="max-h-[560px] overflow-auto bg-slate-950 p-4 text-[12.5px] leading-relaxed text-slate-100">
        <code>{sql}</code>
      </pre>
    </div>
  )
}
