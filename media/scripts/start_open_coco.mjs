// Getting started: switch the left nav from Home to CoCo and put C1's first
// prompt into the "How can I help?" box. The prompt is typed, not sent.
import { clickWithHighlight, highlight } from "../lib.mjs"

export const name = "start_open_coco"
// A small window keeps the side nav and the prompt box close together
export const viewport = { width: 1024, height: 640 }
export const outputWidth = 720
// Trim the empty space below the prompt box
export const crop = { x: 0, y: 0, width: 1024, height: 470 }

const PROMPT =
  "List the Iceberg tables in BARCLAYS_HOL.RAW_DATA with their row counts, and show the Iceberg metadata " +
  "location for BARCLAYS_HOL.RAW_DATA.PAYMENTS. Explain what Snowflake-managed Iceberg means for other " +
  "engines reading this data."

export async function run({ page, mark }) {
  // The Home / CoCo toggle is a radio group of two buttons at the top of the side nav
  const home = page.getByRole("radio", { name: "Home", exact: true })
  const coco = page.getByRole("radio", { name: "CoCo", exact: true })
  await home.waitFor({ timeout: 60_000 })
  await home.click() // start from the Home view
  await page.waitForTimeout(800)
  mark()

  await highlight(home, 600)
  await clickWithHighlight(coco)
  await page.waitForTimeout(1500)

  const box = page.getByRole("textbox").first()
  await box.waitFor({ timeout: 30_000 })

  // First visit shows a "CoCo mode (preview)" pop-up over the box; close it if present
  const popupClose = page.locator(":text('CoCo mode (preview)')").locator("xpath=ancestor::*[.//button][1]").getByRole("button").first()
  if (await popupClose.isVisible().catch(() => false)) {
    await clickWithHighlight(popupClose)
    await page.waitForTimeout(500)
  }

  await clickWithHighlight(box)
  await box.fill(PROMPT) // attendees paste the prompt, so it appears all at once
  await page.waitForTimeout(2000)
}
