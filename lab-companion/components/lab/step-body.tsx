import { InlineMd } from "@/components/lab/inline-md"

type Block = { kind: "p" | "ul" | "ol" | "table"; lines: string[]; start?: number; nested?: boolean }

const cells = (row: string) => row.replace(/^\||\|$/g, "").split("|").map((c) => c.trim())

/** A step body: one paragraph per line, "- " bullet and "1. " numbered lists (one item per line), and
 *  "| a | b |" tables (first row is the header, the "---" row is skipped).
 *  Bullets or a table straight after a numbered item are indented under it, and numbering carries on. */
export function StepBody({ text }: { text: string }) {
  const blocks: Block[] = []
  for (const line of text.split("\n")) {
    const num = line.match(/^(\d+)\.\s+(.*)$/)
    const kind = line.startsWith("|") ? "table" : /^-\s/.test(line) ? "ul" : num ? "ol" : "p"
    if (kind === "table" && /^\|[\s|:-]+\|$/.test(line)) continue // header separator
    const item = num ? num[2] : kind === "ul" ? line.replace(/^-\s+/, "") : line
    const prev = blocks[blocks.length - 1]
    if (prev && prev.kind === kind && kind !== "p") prev.lines.push(item) // each "p" line is its own paragraph
    else blocks.push({ kind, lines: [item], start: num ? Number(num[1]) : undefined, nested: kind !== "ol" && kind !== "p" && prev?.kind === "ol" })
  }
  return (
    <div className="max-w-prose space-y-3 text-sm leading-relaxed">
      {blocks.map((b, i) => {
        if (b.kind === "p") return <p key={i}><InlineMd text={b.lines[0]} /></p>
        if (b.kind === "ul")
          return <ul key={i} className={`list-disc space-y-1.5 marker:text-primary ${b.nested ? "pl-10" : "pl-5"}`}>{b.lines.map((l) => <li key={l}><InlineMd text={l} /></li>)}</ul>
        if (b.kind === "ol")
          return <ol key={i} start={b.start} className="list-decimal space-y-1.5 pl-5 marker:font-semibold marker:text-primary">{b.lines.map((l) => <li key={l}><InlineMd text={l} /></li>)}</ol>
        const [head, ...rows] = b.lines.map(cells)
        return (
          <div key={i} className={`overflow-x-auto ${b.nested ? "pl-5" : ""}`}>
            <table className="w-full border-collapse text-xs">
              <thead>
                <tr>{head.map((h) => <th key={h} className="border-b px-2 py-1.5 text-left font-semibold"><InlineMd text={h} /></th>)}</tr>
              </thead>
              <tbody>
                {rows.map((r, ri) => (
                  <tr key={ri} className="border-b last:border-0">
                    {r.map((c, ci) => <td key={ci} className="px-2 py-1.5 align-top"><InlineMd text={c} /></td>)}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )
      })}
    </div>
  )
}
