// Shared browser setup. Sessions live in a persistent Chrome profile under
// .auth/, so you sign in once with `npm run login` and every recording reuses it.
import { chromium } from "playwright"
import { readFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import path from "node:path"

export const ROOT = path.dirname(fileURLToPath(import.meta.url))
export const PROFILE_DIR = path.join(ROOT, ".auth", "profile")
export const config = JSON.parse(readFileSync(path.join(ROOT, "config.json"), "utf8"))

export async function openBrowser({ headless, recordDir, viewport = config.viewport } = {}) {
  const options = {
    headless,
    viewport,
    ...(recordDir && { recordVideo: { dir: recordDir, size: viewport } }),
  }
  try {
    // Real Chrome, as for the original manual sign-in
    return await chromium.launchPersistentContext(PROFILE_DIR, { ...options, channel: "chrome" })
  } catch {
    return await chromium.launchPersistentContext(PROFILE_DIR, options)
  }
}

// Draws a ring around an element and pauses, so viewers see what is about to be clicked.
export async function highlight(locator, ms = 700) {
  await locator.scrollIntoViewIfNeeded()
  await locator.evaluate((el) => {
    el.style.outline = "3px solid #29B5E8"
    el.style.outlineOffset = "2px"
    el.style.borderRadius = "6px"
  })
  await locator.page().waitForTimeout(ms)
  await locator.evaluate((el) => (el.style.outline = ""))
}

export async function clickWithHighlight(locator) {
  await highlight(locator)
  await locator.click()
}
