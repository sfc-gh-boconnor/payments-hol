// DS1 step 3: with ds1_attrition_model open, open the Cortex Code sidebar and paste the
// first DS1 prompt. The prompt is pasted, not sent.
import { switchTo, openWorkspace, closeAllTabs, openNotebook, pasteIntoCocoSidebar } from "../snowsight.mjs"

export const name = "ds1_coco_sidebar"
export const viewport = { width: 1024, height: 640 }
export const outputWidth = 720
export const crop = undefined

const PROMPT = "In the open notebook ds1_attrition_model, put each cell I ask for under its matching numbered heading. Under heading 1, add a SQL cell named features that creates the view BARCLAYS_HOL.ML.RB_CHURN_FEATURES with one row per retail customer who was still a customer on the observation date 31 Aug 2026. Use only data from on or before that date: tenure, age, segment, IMD decile, housing tenure, credit score, digital active, whether their home branch is one of BR-MAN-90, BR-LDS-90 or BR-CDF-90, drive minutes to it, and from RB_MONTHLY_SNAPSHOT the last 3 months' average logins, branch visits and card spend, latest balances and products held, salary trend (last 3 months against the 3 before), and from RB_ACCOUNTS joined to RB_PRODUCTS the lowest savings rate and whether they hold a legacy saver. The label CHURNED_NEXT_3M is 1 if CHURN_DATE falls in the 3 months after the observation date. Don't use CHURNED, CHURN_REASON, CHURNED_FLAG, CLOSED_DATE or STATUS. Then add a SQL cell named class_balance and run both."

export async function run({ page, mark }) {
  await switchTo(page, "Home")
  await openWorkspace(page, "payments-hol")
  await closeAllTabs(page) // no files left open from earlier clips
  await openNotebook(page, "ds1_attrition_model")
  await page.waitForTimeout(1000)
  mark()

  await pasteIntoCocoSidebar(page, PROMPT)
}
