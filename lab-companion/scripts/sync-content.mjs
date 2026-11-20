// Bundles the lab content (core, vignettes, catch-up scripts) from the parent
// repo into lib/content.generated.json, so the app ships the exact SQL that was
// tested. Run after editing any README or .sql in the repo:
//   npm run sync-content
// The deploy uploads only this folder, so the generated file is committed.

import { readFileSync, readdirSync, writeFileSync, existsSync } from "node:fs"
import { join, relative, dirname } from "node:path"
import { fileURLToPath } from "node:url"

const APP = dirname(dirname(fileURLToPath(import.meta.url)))
const ROOT = dirname(APP)

const ORDER = ["de", "da", "ds", "ops", "ai", "gov"]
const PERSONA_OF = { de: "Data Engineer", da: "Data Analyst", ops: "Payments Ops", ai: "AI Builder", gov: "Governance", ds: "Data Scientist" }

// "## Steps" holds one "### Title" block per step. Inside a block:
//   Paste: <where the prompt goes, if not the Cortex Code sidebar>
//   Where: <where in Snowsight to work>     Expect: <what you should see>
//   Check: <check id from lib/checks.ts>    ```prompt ...``` (paste into Cortex Code)
//   ```sql ...``` (a small snippet to run)  any other lines are the step's text.
function parseSteps(lines) {
  const steps = []
  let s = null
  let fence = null
  for (const l of lines) {
    if (fence) {
      if (/^```\s*$/.test(l)) { s[fence.kind] = fence.buf.join("\n").trim(); fence = null }
      else fence.buf.push(l)
      continue
    }
    const h = l.match(/^### (.*)$/)
    if (h) { s = { title: h[1].trim(), body: "", where: "", prompt: "", sql: "", expect: "", checkId: "", pasteInto: "" }; steps.push(s); continue }
    if (!s) continue
    const f = l.match(/^```(prompt|sql)\s*$/)
    if (f) { fence = { kind: f[1], buf: [] }; continue }
    // "Media: file.mp4 | caption" attaches a short clip from public/media to the step
    const media = l.match(/^Media: ([\w.-]+\.mp4)\s*(?:\|\s*(.*))?$/)
    if (media) {
      if (!existsSync(join(ROOT, "lab-companion/public/media", media[1]))) throw new Error(`Missing clip public/media/${media[1]} in step "${s.title}"`)
      s.media = media[1]; s.mediaCaption = (media[2] ?? "").trim(); continue
    }
    const kv = l.match(/^(Where|Expect|Check|Paste): (.*)$/)
    if (kv) { s[{ Where: "where", Expect: "expect", Check: "checkId", Paste: "pasteInto" }[kv[1]]] = kv[2].trim(); continue }
    // Every line keeps its own line: a plain line is its own paragraph, and list items
    // ("- ", "1. ") and table rows ("| ") are rendered as lists and tables
    if (l.trim()) s.body = s.body ? `${s.body}\n${l.trim()}` : l.trim()
  }
  if (fence) throw new Error(`Unclosed code fence in step "${s.title}"`)
  return steps
}

function parseReadme(md) {
  const lines = md.split("\n")
  const [, code, title] = lines[0].match(/^# (\w+): (.*)$/)
  const meta = {}
  for (const l of lines) {
    const m = l.match(/^\| \*\*(.+?)\*\* \| (.*) \|$/)
    if (m) meta[m[1].toLowerCase()] = m[2]
  }
  const sections = {}
  let current = null
  for (const l of lines.slice(1)) {
    const h = l.match(/^## (.*)$/)
    if (h) { current = h[1]; sections[current] = []; continue }
    if (current) sections[current].push(l)
  }
  const list = (name) => (sections[name] ?? [])
    .filter((l) => /^(- |\d+\. )/.test(l))
    .map((l) => l.replace(/^(- |\d+\. )/, "").replace(/^\*"(.*)"\*$/, "$1"))
  const text = (name) => (sections[name] ?? []).filter((l) => l.trim()).join(" ").replace(/^> /, "")
  return {
    code, title,
    persona: meta.persona ?? "",
    minutes: Number((meta.time ?? "").replace(/\D/g, "")) || null,
    prerequisites: meta.prerequisites ?? "",
    // "| **Optional** | why |" marks a module attendees can skip (e.g. a feature not yet approved)
    optional: meta.optional ?? "",
    question: text("Business question"),
    build: list("What you'll build"),
    steps: parseSteps(sections.Steps ?? []),
    check: text("Check your work"),
    note: text("Barclayflake note"),
  }
}

const modules = []

for (const [readme, sqlPath] of [["core/C0_README.md", "core/C0_tour_data_estate.sql"], ["core/C1_README.md", "core/C1_explore_iceberg.sql"]]) {
  modules.push({
    ...parseReadme(readFileSync(join(ROOT, readme), "utf8")), kind: "core",
    sqlPath,
    sql: readFileSync(join(ROOT, sqlPath), "utf8"),
  })
}

const vdirs = readdirSync(join(ROOT, "vignettes"))
  .sort((a, b) => ORDER.indexOf(a.match(/^[a-z]+/)[0]) - ORDER.indexOf(b.match(/^[a-z]+/)[0]) || a.localeCompare(b))
for (const d of vdirs) {
  const dir = join(ROOT, "vignettes", d)
  const sqlFile = readdirSync(dir).find((f) => f.endsWith(".sql"))
  const m = parseReadme(readFileSync(join(dir, "README.md"), "utf8"))
  modules.push({
    ...m, kind: "vignette", track: PERSONA_OF[d.match(/^[a-z]+/)[0]],
    sqlPath: relative(ROOT, join(dir, sqlFile)),
    sql: readFileSync(join(dir, sqlFile), "utf8"),
  })
}

const catchups = readdirSync(join(ROOT, "setup/catchup")).filter((f) => f.endsWith(".sql")).sort().map((f) => ({
  name: f.replace(".sql", "").replaceAll("_", " "),
  sqlPath: `setup/catchup/${f}`,
  sql: readFileSync(join(ROOT, "setup/catchup", f), "utf8"),
}))

const out = join(APP, "lib/content.generated.json")
writeFileSync(out, JSON.stringify({ modules, catchups }, null, 1))
console.log(`Wrote ${relative(APP, out)}: ${modules.length} modules, ${catchups.length} catch-ups`)
if (!existsSync(join(ROOT, "vignettes"))) process.exit(1)
