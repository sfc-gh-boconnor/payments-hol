// Getting started: from CoCo, switch back to Home, open Workspaces, pick payments-hol,
// then open the Cortex Code sidebar (bottom right) and paste DE1's first prompt.
// The Workspaces UI runs in an iframe, so its controls are found through frameLocator.
// The prompt is pasted, not sent.
import { clickWithHighlight } from "../lib.mjs"

export const name = "start_open_workspace"
export const viewport = { width: 1024, height: 640 }
export const outputWidth = 720
export const crop = undefined

const PROMPT =
  "Walk me through the dbt project in the dbt/ folder of this Workspace: what each staging and mart model " +
  "does, where the sources come from, and which models are defined in models/marts/schema.yml but have no " +
  ".sql file yet."

const closeIfVisible = async (locator) => {
  if (await locator.isVisible().catch(() => false)) await locator.click()
}

export async function run({ page, mark }) {
  const home = page.getByRole("radio", { name: "Home", exact: true })
  const coco = page.getByRole("radio", { name: "CoCo", exact: true })
  const ws = page.frameLocator('iframe[src*="workspaces"]')
  const picker = ws.getByText(/^(My Workspace|payments-hol)$/).first()

  // Reset: Snowsight reopens the last workspace, so switch back to My Workspace
  // first, so the clip shows what a first-time attendee sees
  await home.waitFor({ timeout: 60_000 })
  await home.click()
  await page.getByRole("link", { name: "Workspaces", exact: true }).first().click()
  await picker.waitFor({ timeout: 30_000 })
  if ((await picker.textContent()).trim() === "payments-hol") {
    await picker.click()
    await ws.getByRole("option", { name: "My Workspace" }).click()
    await ws.getByText("My Workspace", { exact: true }).first().waitFor()
  }
  await coco.click() // start where the previous clip ended
  await page.getByText(/how can I help\?/).first().waitFor({ timeout: 30_000 })
  await page.waitForTimeout(800)
  mark()

  await clickWithHighlight(home)
  await page.waitForTimeout(600)
  await clickWithHighlight(page.getByRole("link", { name: "Workspaces", exact: true }).first())
  await picker.waitFor({ timeout: 30_000 })
  await page.waitForTimeout(800)

  // One-off notices that cover the panel: the "NEW" notebooks tip and the legacy worksheets banner
  await closeIfVisible(ws.locator(":text('Go Beyond SQL with Notebooks')").locator("xpath=ancestor::*[.//button][1]").getByRole("button").first())
  await closeIfVisible(ws.locator(":text('legacy worksheets')").locator("xpath=ancestor::*[.//button][1]").getByRole("button").last())
  await page.waitForTimeout(400)

  await clickWithHighlight(picker)
  await page.waitForTimeout(500)
  await clickWithHighlight(ws.getByRole("option", { name: "payments-hol" }))
  await ws.getByText("vignettes", { exact: true }).first().waitFor({ timeout: 30_000 })
  await page.waitForTimeout(1000)

  // Cortex Code sidebar: the round button at the bottom right
  await clickWithHighlight(page.getByRole("button", { name: "Open or move CoCo" }))
  await page.waitForTimeout(1200)
  // The sidebar reopens the last chat; start a fresh one, as attendees do for each module
  const newChat = page.getByRole("button", { name: "New chat" })
  if (await newChat.isVisible().catch(() => false)) {
    await clickWithHighlight(newChat)
    await page.waitForTimeout(800)
  }
  const box = page.getByPlaceholder(/^Ask, build/).or(page.getByRole("textbox", { name: /Ask, build/ })).first()
  await box.waitFor({ timeout: 30_000 })
  await page.waitForTimeout(800)
  await closeIfVisible(page.getByRole("button", { name: "Close", exact: true })) // "CoCo doesn't need a day off" tip

  await clickWithHighlight(box)
  await box.fill(PROMPT) // attendees paste the prompt, so it appears all at once
  await page.waitForTimeout(2000)
}
