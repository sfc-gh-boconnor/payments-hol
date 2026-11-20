// Shared clip for the starter-notebook modules (DE3, DA2, DA3, GOV3): open the module's
// notebook and create its notebook service with the lab's settings. Cancels the form
// rather than pressing Create and connect, which would start the compute pool.
import { switchTo, openWorkspace, closeAllTabs, closeFolder, openNotebook, createNotebookService } from "./snowsight.mjs"

export function notebookServiceRun(notebookName) {
  return async function run({ page, mark }) {
    await switchTo(page, "Home")
    await openWorkspace(page, "payments-hol")
    await closeAllTabs(page) // no notebooks left open from earlier clips
    await closeFolder(page, "notebooks", notebookName) // so the clip shows it opening
    await page.waitForTimeout(1000)
    mark()

    await openNotebook(page, notebookName)
    await createNotebookService(page)
  }
}
