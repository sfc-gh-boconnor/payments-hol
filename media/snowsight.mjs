// Reusable Snowsight steps for clip scripts. Each step highlights what it clicks, so it can
// go after mark() and appear in the clip, or before mark() as silent setup.
// Every quirk worked around here was found the hard way; see the notes on each step.
import { clickWithHighlight, highlight } from "./lib.mjs"

const pause = (page, ms) => page.waitForTimeout(ms)

// The Workspaces UI runs inside an iframe: everything in it is reached through this.
export const workspaceFrame = (page) => page.frameLocator('iframe[src*="workspaces"]')

const closeIfVisible = async (locator) => {
  if (await locator.isVisible().catch(() => false)) await locator.click()
}

// Home/CoCo is a radio toggle at the top left, not a pair of buttons.
export async function switchTo(page, mode /* "Home" | "CoCo" */) {
  const radio = page.getByRole("radio", { name: mode, exact: true })
  await radio.waitFor({ timeout: 60_000 })
  await clickWithHighlight(radio)
  if (mode === "CoCo") {
    await closeIfVisible(page.getByRole("button", { name: "Close", exact: true })) // "CoCo mode (preview)" pop-up
    await page.getByText(/how can I help\?/).first().waitFor({ timeout: 30_000 })
  }
}

// Home > Workspaces > pick a workspace. Snowsight reopens the last workspace, so this
// only uses the picker when needed. Pass { fresh: true } in setup to reset to My Workspace.
export async function openWorkspace(page, name = "payments-hol", { fresh = false } = {}) {
  const ws = workspaceFrame(page)
  await clickWithHighlight(page.getByRole("link", { name: "Workspaces", exact: true }).first())
  await page.mouse.move(600, 300) // leave the left nav, or its flyout menu stays open
  const picker = ws.getByText(/^(My Workspace|payments-hol)$/).first()
  await picker.waitFor({ timeout: 30_000 })
  // one-off notices that cover the file panel
  await closeIfVisible(ws.locator(":text('Go Beyond SQL with Notebooks')").locator("xpath=ancestor::*[.//button][1]").getByRole("button").first())
  await closeIfVisible(ws.locator(":text('legacy worksheets')").locator("xpath=ancestor::*[.//button][1]").getByRole("button").last())
  const target = fresh ? "My Workspace" : name
  if ((await picker.textContent()).trim() !== target) {
    await clickWithHighlight(picker)
    await pause(page, 400)
    await clickWithHighlight(ws.getByRole("option", { name: target }))
  }
  if (!fresh) await ws.getByText("vignettes", { exact: true }).first().waitFor({ timeout: 30_000 })
  return ws
}

// Close every open editor tab, so the clip doesn't show files from earlier recordings.
// Each tab's "Close <file>" button only appears on hover. Setup only, before mark().
export async function closeAllTabs(page) {
  const ws = workspaceFrame(page)
  const tabs = ws.locator('[data-action-name="EditorTab"][id^="EditorPane"]')
  for (let i = 0; i < 30 && (await tabs.count()) > 0; i++) {
    const tab = tabs.first()
    await tab.hover()
    await tab.locator("xpath=ancestor::*[@role='button'][1]").getByRole("button", { name: /^Close / }).click()
    await pause(page, 300)
  }
  if ((await tabs.count()) > 0) throw new Error("could not close all editor tabs")
}

// Collapse a folder in the file tree so the clip can show it being opened.
export async function closeFolder(page, folder, childPrefix) {
  const ws = workspaceFrame(page)
  const item = ws.getByRole("treeitem", { name: folder, exact: true })
  await item.waitFor({ timeout: 30_000 })
  const child = ws.getByRole("treeitem", { name: new RegExp(`^${childPrefix}`) })
  if (await child.isVisible().catch(() => false)) await item.click()
}

// Open a file: expand its folder if needed, then click the file.
export async function openFile(page, folder, filePrefix) {
  const ws = workspaceFrame(page)
  const file = ws.getByRole("treeitem", { name: new RegExp(`^${filePrefix}`) })
  if (!(await file.isVisible().catch(() => false)))
    await clickWithHighlight(ws.getByRole("treeitem", { name: folder, exact: true }))
  await clickWithHighlight(file)
}

// Open a starter notebook in notebooks/ and wait for its service controls.
export async function openNotebook(page, notebookName) {
  await openFile(page, "notebooks", notebookName)
  await workspaceFrame(page).getByRole("button", { name: "Service List dropdown button" }).waitFor({ timeout: 30_000 })
  await pause(page, 1500)
}

// Single-choice dropdown in a form, e.g. pickOption(page, form, "Compute pool", /^NOTEBOOK_POOL/).
// Fields are found by aria-label: the accessible name also includes the current value, and
// each field has a "<label> help" icon button whose name starts the same way.
export async function pickOption(page, form, label, option) {
  const field = form.locator(`button[aria-label="${label}"]`)
  await field.scrollIntoViewIfNeeded()
  await pause(page, 300)
  await clickWithHighlight(field)
  await clickWithHighlight(workspaceFrame(page).getByRole("option", { name: option }))
  await pause(page, 500)
}

// Multi-select dropdown (e.g. External access integrations). Each click toggles, and
// Escape, Tab or a click outside clears the choice, so: click the option at most once,
// close the list by force-clicking the field (an overlay covers it), then check it stuck.
export async function pickMulti(page, form, label, optionText) {
  const field = form.locator(`button[aria-label="${label}"]`)
  const option = workspaceFrame(page).getByRole("option", { name: new RegExp(`^${optionText}`) })
  const chosen = async () => (await field.textContent()).includes(optionText)
  await field.scrollIntoViewIfNeeded()
  await clickWithHighlight(field)
  await pause(page, 400) // the list animates open; earlier clicks are dropped
  if (!(await chosen()) && (await option.isVisible())) {
    await clickWithHighlight(option)
    await pause(page, 600)
  }
  if (await option.isVisible()) {
    await field.click({ force: true })
    await pause(page, 500)
  }
  if (!(await chosen())) throw new Error(`${label}: ${optionText} not selected`)
}

// The notebook's "Connect your notebook" form: service dropdown (next to the status dot)
// > Create new service > Service settings. Fills the lab's settings, highlights
// Create and connect, then cancels unless { create: true } (which starts the compute pool).
export async function createNotebookService(page, {
  pool = /^NOTEBOOK_POOL/,
  idle = /^1 hour$/,
  integration = "HOL_NOTEBOOK_ACCESS_INTEGRATION",
  create = false,
} = {}) {
  const ws = workspaceFrame(page)
  await clickWithHighlight(ws.getByRole("button", { name: "Service List dropdown button" }))
  await clickWithHighlight(ws.getByText("Create new service", { exact: true }))
  const form = ws.locator("[role=dialog]").filter({ hasText: "Connect your notebook" })
  await form.getByText("Service name", { exact: true }).waitFor({ timeout: 30_000 })
  await pause(page, 1000)

  await clickWithHighlight(form.getByText("Service settings", { exact: true }).first()) // collapsed by default
  await form.getByText("Compute pool", { exact: true }).first().scrollIntoViewIfNeeded()
  await pickOption(page, form, "Compute pool", pool)
  await pickOption(page, form, "Idle timeout", idle)
  await pickMulti(page, form, "External access integrations", integration)

  const go = form.getByRole("button", { name: "Create and connect" })
  if (create) return clickWithHighlight(go)
  await highlight(go, 1800)
  await form.getByRole("button", { name: "Cancel" }).click()
}

// Cortex Code sidebar (round button, bottom right) > New chat > paste a prompt (not sent).
export async function pasteIntoCocoSidebar(page, prompt) {
  await clickWithHighlight(page.getByRole("button", { name: "Open or move CoCo" }))
  await pause(page, 1200)
  const newChat = page.getByRole("button", { name: "New chat" }) // it reopens the last chat
  if (await newChat.isVisible().catch(() => false)) {
    await clickWithHighlight(newChat)
    await pause(page, 800)
  }
  const box = page.getByPlaceholder(/^Ask, build/).or(page.getByRole("textbox", { name: /Ask, build/ })).first()
  await box.waitFor({ timeout: 30_000 })
  await closeIfVisible(page.getByRole("button", { name: "Close", exact: true })) // one-off tip
  await clickWithHighlight(box)
  await box.fill(prompt) // attendees paste, so it appears all at once
  await pause(page, 2000)
}
