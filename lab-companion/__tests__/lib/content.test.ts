import { describe, expect, it } from "vitest"
import { MODULES } from "@/lib/content"
import { CHECKS } from "@/lib/checks"

describe("lab content", () => {
  it("every step's Check refers to a real check for its module", () => {
    for (const m of MODULES) {
      const ids = (CHECKS[m.code] ?? []).map((c) => c.id)
      for (const s of m.steps) if (s.checkId) expect(ids, `${m.code}: ${s.title}`).toContain(s.checkId)
    }
  })

  it("every module is led by Cortex Code prompts", () => {
    for (const m of MODULES) expect(m.steps.filter((s) => s.prompt).length, m.code).toBeGreaterThan(0)
  })
})
