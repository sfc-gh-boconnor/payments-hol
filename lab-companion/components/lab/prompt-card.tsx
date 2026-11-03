"use client"

import { useState } from "react"
import { Check, Copy, Sparkles } from "lucide-react"
import { copyText } from "@/lib/clipboard"
import { Button } from "@/components/ui/button"
import { InlineMd } from "@/components/lab/inline-md"

/** A prompt to paste into Cortex Code (the sidebar unless `pasteInto` names another box), with what the attendee should see back. */
export function PromptCard({ prompt, expect, pasteInto }: { prompt: string; expect?: string; pasteInto?: string }) {
  const [copied, setCopied] = useState(false)
  return (
    <div className="min-w-0 overflow-hidden rounded-lg border border-primary/30 bg-primary/5">
      <div className="flex items-center justify-between gap-2 border-b border-primary/20 px-3 py-2">
        <div className="flex min-w-0 items-center gap-2">
          <Sparkles className="h-4 w-4 shrink-0 text-primary" />
          <div className="min-w-0">
            <div className="text-xs font-semibold">Paste into Cortex Code</div>
            <div className={`${pasteInto ? "" : "truncate "}text-[11px] text-muted-foreground`}>{pasteInto ? <InlineMd text={pasteInto} /> : "Open the Cortex Code sidebar in Snowsight (right-hand panel)"}</div>
          </div>
        </div>
        <Button
          size="sm"
          onClick={async () => {
            if (await copyText(prompt)) {
              setCopied(true)
              setTimeout(() => setCopied(false), 1500)
            }
          }}
        >
          {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
          {copied ? "Copied" : "Copy prompt"}
        </Button>
      </div>
      <p className="whitespace-pre-wrap px-4 py-3 text-sm leading-relaxed">{prompt}</p>
      {expect && (
        <div className="border-t border-primary/20 bg-background/60 px-4 py-2 text-xs">
          <span className="font-semibold">What you should see: </span><InlineMd text={expect} />
        </div>
      )}
    </div>
  )
}
