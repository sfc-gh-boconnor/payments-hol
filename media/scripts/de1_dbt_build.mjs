// DE1 "Run dbt build from the dbt pane": open a dbt file, open the bottom panel's
// dbt tab, and choose Build from the operation picker. Stops before Execute, so
// recording never runs a build.
// Snowsight remembers the folder and panel state between visits, so each step
// checks the current state before clicking.
import { clickWithHighlight, highlight } from "../lib.mjs"

export const name = "de1_dbt_build"
export const viewport = { width: 1024, height: 640 }
export const outputWidth = 720
export const crop = undefined

export async function run({ page, mark }) {
  const ws = page.frameLocator('iframe[src*="workspaces"]')
  const home = page.getByRole("radio", { name: "Home", exact: true })
  await home.waitFor({ timeout: 60_000 })
  await home.click()
  await page.getByRole("link", { name: "Workspaces", exact: true }).first().click()

  const picker = ws.getByText(/^(My Workspace|payments-hol)$/).first()
  await picker.waitFor({ timeout: 30_000 })
  if ((await picker.textContent()).trim() !== "payments-hol") {
    await picker.click()
    await ws.getByRole("option", { name: "payments-hol" }).click()
  }
  const dbtFolder = ws.getByRole("treeitem", { name: "dbt", exact: true })
  await dbtFolder.waitFor({ timeout: 30_000 })

  // Reset to a clean starting point: dbt folder closed, bottom panel closed
  const projectFile = ws.getByRole("treeitem", { name: "dbt_project.yml" })
  if (await projectFile.isVisible().catch(() => false)) await dbtFolder.click()
  // The bottom-panel toggle is the rightmost of the bottom-left icons; its label flips
  // between "Expand pane" and "Collapse pane", and other panes use the same labels,
  // so pick it by position rather than by name or order
  const paneButtons = ws.getByRole("button", { name: /^(Expand|Collapse) pane$/ })
  const panelToggle = {
    async get() {
      const boxes = await paneButtons.evaluateAll((n) => n.map((e) => e.getBoundingClientRect()).map((r) => [r.x, r.y]))
      const footer = boxes.map((b, i) => [...b, i]).filter(([, y]) => y > 560).sort((a, b) => b[0] - a[0])
      return paneButtons.nth(footer[0][2])
    },
  }
  if (await ws.getByRole("button", { name: "Run Selected Operation" }).isVisible().catch(() => false)) {
    await (await panelToggle.get()).click()
  }
  await page.waitForTimeout(1000)
  mark()

  // 1. Open a file from the dbt project, so the dbt tab knows which project to use
  await clickWithHighlight(dbtFolder)
  await clickWithHighlight(projectFile)
  await page.waitForTimeout(800)

  // 2. Open the bottom panel (second icon at the bottom left); it opens on the dbt tab
  await clickWithHighlight(await panelToggle.get())
  const runButton = ws.getByRole("button", { name: "Run Selected Operation" })
  await runButton.waitFor({ timeout: 30_000 })
  await page.waitForTimeout(1000)

  // 3. Arrow next to the main button (it shows the last operation used) > Build
  await clickWithHighlight(ws.getByRole("button", { name: "Run", exact: true }).filter({ visible: true }).first())
  await page.waitForTimeout(1000)
  // Select Operation dialog: open the operation dropdown and choose Build
  const operation = ws.getByText("Select Operation", { exact: true }).locator("xpath=following::button[1]")
  await clickWithHighlight(operation)
  await page.waitForTimeout(600)
  await clickWithHighlight(ws.getByRole("option", { name: "Build", exact: true }).or(ws.getByRole("menuitem", { name: "Build", exact: true })).first())
  await page.waitForTimeout(600)
  // Show Execute, but don't press it: recording must not run a build
  await highlight(ws.getByRole("button", { name: "Execute", exact: true }), 1500)
}
