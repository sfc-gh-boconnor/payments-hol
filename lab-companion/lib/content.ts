import content from "@/lib/content.generated.json"
import { CHECKS } from "@/lib/checks"

/** One step of a module. prompt is pasted into Cortex Code; sql is a small snippet to run. */
export type Step = {
  title: string
  body: string
  where: string
  prompt: string
  sql: string
  expect: string
  checkId: string
  /** Where the prompt is pasted when it isn't the Cortex Code sidebar */
  pasteInto: string
}

export type Module = {
  code: string
  title: string
  persona: string
  minutes: number | null
  prerequisites: string
  question: string
  build: string[]
  steps: Step[]
  check: string
  note: string
  kind: "core" | "vignette"
  track?: string
  sqlPath: string
  sql: string
}

export type CatchUp = { name: string; sqlPath: string; sql: string }

export const MODULES = content.modules as Module[]
export const CATCHUPS = content.catchups as CatchUp[]

/** Persona pathways: the order attendees work through vignettes (see pathways/README.md). */
export const PATHWAYS: Record<string, { blurb: string; modules: string[] }> = {
  "Data Engineer": { blurb: "Autonomous data engineering and real-time analytics: Iceberg sources to tested, self-scheduling data products with dbt, Pipeline Builder and dynamic tables, then streaming payments served by an interactive warehouse.", modules: ["C1", "DE1", "DE2", "DE3", "GOV2"] },
  "Data Analyst": { blurb: "AI SQL on client feedback, a trusted semantic view anyone can query in plain English, and drive-time catchment analysis on the retail branch network.", modules: ["C1", "DA2", "DA1", "DA3"] },
  "Payments Ops": { blurb: "A client 360 agent, alert triage with AI next actions, and complaint themes - low code.", modules: ["C1", "OPS1", "OPS2", "DA2"] },
  "AI Builder": { blurb: "Agents with custom tools, a governed MCP server, and Marketplace knowledge instead of Cortex Search.", modules: ["C1", "AI1", "AI3", "AI2"] },
  "Governance": { blurb: "Data and AI governance: classify, tag, mask and filter PII, prove lineage and who accessed what, then govern every AI client through one gateway.", modules: ["C1", "GOV1", "GOV2", "GOV3", "AI3"] },
}

export const moduleByCode = (code: string) => MODULES.find((m) => m.code === code)
export const checkIds = (code: string) => (CHECKS[code] ?? []).map((c) => c.id)
