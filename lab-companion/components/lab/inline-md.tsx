import { Fragment, type ReactNode } from "react"

/** Renders the small subset of markdown used in vignette READMEs: `code` and **bold**. */
export function InlineMd({ text }: { text: string }) {
  const parts: ReactNode[] = []
  const re = /(`[^`]+`|\*\*[^*]+\*\*)/g
  let last = 0
  let m: RegExpExecArray | null
  while ((m = re.exec(text))) {
    if (m.index > last) parts.push(text.slice(last, m.index))
    const tok = m[0]
    parts.push(
      tok.startsWith("`") ? (
        <code key={m.index} className="rounded bg-muted px-1 py-0.5 text-[0.85em]">{tok.slice(1, -1)}</code>
      ) : (
        <strong key={m.index}>{tok.slice(2, -2)}</strong>
      ),
    )
    last = m.index + tok.length
  }
  if (last < text.length) parts.push(text.slice(last))
  return <>{parts.map((p, i) => <Fragment key={i}>{p}</Fragment>)}</>
}
