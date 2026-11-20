// One-time sign-in. Opens a visible Chrome window on Snowsight; sign in, and the
// session is saved in .auth/profile for the recordings.
//   npm run login            closes the browser once you're signed in
//   npm run login -- --keep  leaves it open until you close it
import { openBrowser, config } from "./lib.mjs"

const keep = process.argv.includes("--keep")
const context = await openBrowser({ headless: false })
const page = context.pages()[0] ?? (await context.newPage())
await page.goto(config.snowsightUrl)

console.log("Sign in to Snowsight in the browser window. Waiting up to 5 minutes...")
// Signed in once the Snowsight shell (left nav) has loaded
await page.getByRole("navigation").first().waitFor({ timeout: 5 * 60_000 })
console.log("Signed in. Session saved in media/.auth/profile.")

if (keep) {
  console.log("Browser left open; close it when you're done.")
  await new Promise((resolve) => context.on("close", resolve))
} else {
  await context.close()
}
