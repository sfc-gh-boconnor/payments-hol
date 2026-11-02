import content from "@/lib/content.generated.json"
import { CHECKS } from "@/lib/checks"

export type Module = {
  code: string
  title: string
  persona: string
  minutes: number | null
  prerequisites: string
  question: string
  build: string[]
  steps: string[]
  prompts: string[]
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
  "Data Engineer": { blurb: "Iceberg sources to tested, scheduled data products with dbt, dynamic tables and data quality.", modules: ["C1", "DE1", "DE2", "GOV2"] },
  "Data Analyst": { blurb: "AI SQL on client feedback, then a trusted semantic view anyone can query in plain English.", modules: ["C1", "DA2", "DA1"] },
  "Payments Ops": { blurb: "A client 360 agent, alert triage with AI next actions, and complaint themes - low code.", modules: ["C1", "OPS1", "OPS2", "DA2"] },
  "AI Builder": { blurb: "Agents with custom tools, a governed MCP server, and Marketplace knowledge instead of Cortex Search.", modules: ["C1", "AI1", "AI3", "AI2"] },
  "Governance": { blurb: "Classify, tag, mask and filter PII, then prove lineage and who accessed what.", modules: ["C1", "GOV1", "GOV2", "AI3"] },
}

export const moduleByCode = (code: string) => MODULES.find((m) => m.code === code)
export const checkIds = (code: string) => (CHECKS[code] ?? []).map((c) => c.id)
