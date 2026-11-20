// DE1: open the payments-hol Workspace and find the dbt tab in the bottom panel.
// Selectors are written against the Snowsight UI as described in feedback.md
// (items 2 and 3); adjust them with `--headed` if Snowsight differs.
import { clickWithHighlight } from "../lib.mjs"

export const name = "de1_dbt_tab"
// Optional crop in viewport pixels, e.g. { x: 0, y: 450, width: 1440, height: 450 }
export const crop = undefined

export async function run({ page, mark }) {
  await page.getByRole("navigation").first().waitFor({ timeout: 60_000 })
  mark()

  await clickWithHighlight(page.getByRole("link", { name: /^Workspaces$/ }).first())
  await clickWithHighlight(page.getByRole("button", { name: /My Workspace/ }).first())
  await clickWithHighlight(page.getByText("payments-hol", { exact: true }).first())
  await page.getByText("dbt", { exact: true }).first().waitFor({ timeout: 30_000 })
  await clickWithHighlight(page.getByRole("tab", { name: /^dbt$/ }).first())
}
