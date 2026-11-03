# Lab feedback

Test run: DataOps event `test-barclays-hol-roconnor` (v2, 2 Nov 2026).

Each issue: where it happened, what went wrong, what was expected, and severity
(**Blocker** stops the attendee, **Major** confusing or wrong, **Minor** polish).

## Setup and access

### 1. Attendees aren't sent to the Lab Companion app (Blocker) - FIXED 3 Nov

- **Fix:** the v2 install now runs inside Configure Attendee Account, which exports `LAB_COMPANION_URL` to the dotenv the instructions page reads. The event instructions (`dataops-integration/event_instructions.md`, applied with the admin API) show **1. Open Lab Companion** and **2. Open Snowflake**, each in its own tab. The old DataOps homepage button and job were removed.

- **Where:** the DataOps event instructions page (the event `instructions` template, edited through the admin API).
- **What happened:** the page has one "Lab Instructions" button (the DataOps homepage) and the Snowflake account URL. Nothing links to the Lab Companion, so attendees don't know to open it, and it's the lab guide with Check my work.
- **Expected:** two clear links, each opening in its own window, so attendees work with both side by side:
  1. **Open the Lab Companion**: this account's app URL (`https://<id>.snowflakecomputing.app`).
  2. **Open Snowflake**: `https://{{vars.DATAOPS_SNOWFLAKE_ACCOUNT}}.snowflakecomputing.com`.
- **Notes for the fix:**
  - The template gets per-account values from `vars`, which come from the dotenv artifact `dataops/event/attendee_account_outputs.env`, exported by **Configure Attendee Account**.
  - The Lab Companion URL is only known after **Deploy Barclays HOL v2**, so that job would need to export it (for example `LAB_COMPANION_URL`) in the same way.
  - Still to confirm: whether the instructions page reads `vars` from that job's dotenv, or only from Configure's.
  - `target="_blank"` on both links opens them in separate windows or tabs. Separate windows can't be forced; the page could tell attendees to drag one to its own window.
  - The URL format differs per account (for example `eqnravb-…-ukssih.snowflakecomputing.app`), so it must come from `SHOW APPLICATION SERVICES`, not be built from the account name.

## Lab Companion

### 5. Cortex Code prompts are missing or easy to miss in the module page (Major, all modules, FIXED 3 Nov: Cortex Code-first rewrite)
- **What happened:** the attendee saw no Cortex Code prompts in the Lab Companion.
- **Cause (checked):**
  - The prompts are in the app's content: `lib/content.generated.json` has 1–2 per module.
  - `app/module/[code]/page.tsx` renders them, but only as a "Try in Cortex Code" card **below the full SQL block** (lines 55–64). That's below a long script, so in practice nobody sees it.
  - The steps don't point to the prompts. For example, DE1 step 3 says "use Cortex Code to generate the marts" but doesn't show the prompt at that step.
  - The DE1 prompts are truncated in the README ("... (full prompt in de1.sql)"), so even the card shows unusable text.
  - The prompts are plain italic blockquotes with no copy button.
- **Expected:** each module shows its Cortex Code prompts prominently, as full and copyable text, next to the step that uses them.
- **Design decision (Becky, 3 Nov): the lab is Cortex Code first, not script first.** Attendees should open Cortex Code in Snowsight (the side panel, "Hi EVENT, How can I help?") and paste prompts, not open or run the `.sql` script.
  - Each step leads with the prompt to paste into Cortex Code and what to expect back.
  - The full SQL script moves into a collapsed "Stuck? Run the reference SQL" fallback at the bottom (default closed), not a large open block under the steps.
  - Add an "Open Cortex Code" instruction to C1 (where the panel is in Snowsight) and refer to it in later modules.
  - Rework every module's steps around prompts. Today most build work lives only in the SQL, so each module needs more prompts than the current 1–2.
  - Remove the script-first wording in step lists and in the `.sql` header comments that the app shows.
- **Prompt card design (agreed):** each step that uses Cortex Code shows a prompt card:
  - a small "Paste into Cortex Code" label with the Cortex Code icon, and a one-line hint: "Open the Cortex Code sidebar in Snowsight (right-hand panel)";
  - the full prompt in a clean, readable box (not italic), with a prominent **Copy prompt** button and a "Copied" confirmation;
  - a short "What you should see" line under it (for example "4 new staging views and a passing `dbt build`").
  - The first card in C1 includes a screenshot or annotated image of where the sidebar is.
  - The step's Check my work stays next to the card, so the flow is: copy prompt, paste into the sidebar, review and run, Check my work.
- **Notes for the fix:**
  - Show prompts inline in the step that uses them (not a separate card below the SQL).
  - Add a copy button, reusing the `SqlBlock` copy pattern.
  - Replace the truncated DE1 prompts in the README with the full text from `de1.sql` DE1.3, and say the marts must keep the `schema.yml` column names (this ties into item 4).
  - Check every module's README prompts are complete. Run `npm run sync-content` and redeploy afterwards.

## Workspace (payments-hol)

## C1 Explore the Iceberg data product

## C2 Data product tour

## DE1 Iceberg + dbt pipeline

### 2. "Walk dbt/" doesn't say how to open the payments-hol Workspace (Major, FIXED 3 Nov: Cortex Code-first rewrite)
- **Where:** DE1 step 1 ("Open the lab Workspace **payments-hol** (**Projects > Workspaces**) and walk `dbt/`"), plus the header comment in `de1.sql`, as shown in the Lab Companion.
- **What happened:** the steps don't say where the Workspace is. Projects > Workspaces opens **My Workspace** by default, and payments-hol is only reachable through the **workspace picker**: the "My Workspace" dropdown at the top of the Workspaces panel lists it under **All / Shared**.
- **Expected:** exact clicks, e.g. *Projects > Workspaces, click the **My Workspace** dropdown at the top left, choose **payments-hol**, then open the `dbt/` folder*. Possibly a screenshot, or a tip to pin it with the pin icon.
- **Notes for the fix:**
  - The same "Projects > Workspaces" wording is in C1 ("CoCo panel in your Workspace"), the README attendee start, `getting-started/step1.md` and the event instructions page (`dataops-integration/event_instructions.md`). Fix them all with the same wording.
  - The Lab Companion shows module content from `lab-companion/lib/content.generated.json`, so run `npm run sync-content` after editing the vignette README or SQL.
  - payments-hol is a **shared** Workspace (in `DEFAULT_DATABASE.PUBLIC`, created by the DataOps Deploy Workspace job), which is why it's under Shared rather than Private or Git.

### 3. DE1 doesn't say the dbt deploy is in the Workspace's dbt pane (Major, FIXED 3 Nov: Cortex Code-first rewrite)
- **Where:** DE1 step 2 ("Deploy `dbt/` as a dbt Project and run `build` (Workspace **Deploy/Run**, or `EXECUTE DBT PROJECT`)") and DE1.2 in `de1.sql` ("select dbt/ > Deploy > name BARCLAYS_DBT, then Run > build").
- **What happened:** the steps don't say where the controls are. Becky found that deploying is done from the Workspace's **dbt pane**, not from the `dbt/` folder in the file explorer, which is what the steps imply ("select dbt/ > Deploy").
- **Expected:** steps that name the dbt pane and give the exact clicks to deploy as `BARCLAYS_DBT` and run `build`, with the SQL as a fallback.
- **Notes for the fix:**
  - **Captured from Becky's run (3 Nov):** the **dbt** pane is a tab in the Workspace's **bottom panel**, next to **Query History**. It shows **Profile** (`dev`), **Environment** (`None`), a blue **Run** button with a dropdown arrow, **Output / DAG / Performance** tabs, and **Connect** on the right. The steps must tell attendees to **open this bottom panel and select the dbt tab** (with `dbt/` files open in the editor); nothing in the lab mentions it.
  - Her run ended `Done. PASS=6 WARN=0 ERROR=0 SKIP=0 TOTAL=6`: that's **`run`** (the 6 models). **`build`** also runs the tests (27 on demo810). The step should say to choose **build** from the Run dropdown, so the pre-written tests run as DE1 step 3 expects.
  - **Still to capture:** which control deploys the project as an object (probably the Run dropdown or **Connect**), and whether deploying with the name `BARCLAYS_DBT` in `BARCLAYS_HOL.ANALYTICS` updates the existing object. A screenshot of the Run dropdown and of Connect would settle it.
  - The object `BARCLAYS_HOL.ANALYTICS.BARCLAYS_DBT` is **already deployed** during provisioning (`provision_account.sh` step 4, owner `HOL_PARTICIPANT`). So step 2 can start with `EXECUTE DBT PROJECT BARCLAYS_HOL.ANALYTICS.BARCLAYS_DBT ARGS = 'build';`, which is tested (27/27 on demo810), and present the Workspace deploy as optional.
  - **To check:** the redeploy path after the Cortex Code steps that change `dbt/`: `ALTER DBT PROJECT BARCLAYS_HOL.ANALYTICS.BARCLAYS_DBT DEPLOY FROM 'snow://workspace/DEFAULT_DATABASE.PUBLIC."payments-hol"/versions/<live|head>/dbt'`. Shared workspaces publish to `head` on COMMIT, so `live` may not hold the attendee's saved edits. Test in an event account before documenting.
  - Remove the "(Facilitator: the project object is created by `snow dbt deploy` or the Workspace.)" line from `de1.sql`: attendees see it in the Lab Companion.

### 4. DE1 step 3 says "generate the missing marts" but nothing shows which marts are missing (Major, FIXED 3 Nov: Cortex Code-first rewrite)
- **Where:** DE1 step 3 ("Use the two Cortex Code prompts to generate the missing marts; re-run `build` until the pre-written tests pass").
- **What happened:** the dbt run showed `PASS=6`, with no errors or warnings, so there's no sign anything is missing. The step doesn't name the marts or say where they belong.
- **Why:** `dbt/models/marts/schema.yml` already has the docs and tests for `mart_customer_payments` and `mart_rm_performance`, but there are no `.sql` files for them. dbt silently ignores tests for models that don't exist, so nothing is reported until the models are created.
- **Expected:** the step should say what's missing and why, for example: *"`schema.yml` describes and tests two marts that don't exist yet: `mart_customer_payments` and `mart_rm_performance`. Open `dbt/models/marts/schema.yml` to see them, then use the Cortex Code prompts below to create them in `dbt/models/marts/`."*
- **Notes for the fix:**
  - The README's prompts are truncated (*"Create a dbt mart model mart_customer_payments ... (full prompt in de1.sql)"*), and the Lab Companion shows that truncated text as the prompt. Put the **full** prompts (from `de1.sql`, DE1.3) in the README so attendees can copy them straight from the Lab Companion.
  - Point out that `build` is what runs the tests (it ties in with item 3), and that the new marts must keep the `schema.yml` column names, or their tests fail.
  - Optional: a quick before and after, i.e. `build` before CoCo (6 models, no new tests), then after (8 models, plus the new tests).

## DE2 Dynamic Tables + data quality

## DA1 Semantic view + Cortex Analyst

## DA2 AI SQL on customer feedback

## OPS1 Corporate Payments 360 agent

## OPS2 Alert triage

## AI1 Agent with custom tools

## AI2 Snowflake-managed MCP server

## AI3 Marketplace knowledge extension

## GOV1 PII policies

## GOV2 Lineage, audit and trust

## General

### 6. Make the whole lab Cortex Code first, not just DE1 (Major, all modules, FIXED 3 Nov: Cortex Code-first rewrite)
- **Requirement (Becky, 3 Nov):** wherever Cortex Code is used, every module follows the item 5 pattern: a prompt card (copy, paste into the Cortex Code sidebar, what you should see, Check my work), and the SQL as a collapsed fallback. The aim is a lab that feels less scripted.
- **Applies to:** C1, C2, DE1, DE2, DA1, DA2, OPS1, OPS2, AI1, AI2, AI3, GOV1, GOV2.
- **Per module, for the fix:**
  - Turn each build step that's SQL-only today into a Cortex Code prompt with an expected outcome. Keep it as plain UI steps where Cortex Code doesn't fit (for example, chatting to the agent in Snowflake Intelligence in OPS1/AI2, or the Marketplace listing in AI3).
  - Make sure each prompt produces objects with the exact names Check my work looks for (for example `DT_HIGH_VALUE_FAILURES`, `SV_CLIENT_360`). Otherwise the checks fail even when the attendee did the step correctly.
  - Keep any purely setup or safety SQL (role/warehouse context) as one small "run first" snippet, not the whole script.
  - Rewrite the README `## Cortex Code prompts` and the steps so `sync-content` produces per-step prompts. This needs a content model change: prompts attached to steps, with an expected-outcome field.
  - Test each prompt end to end in a fresh event account as `HOL_PARTICIPANT` before the event, because Cortex Code output varies.

### 7. Use the payments-hol Workspace as the central hub for the lab (Major, lab design, FIXED 3 Nov: Cortex Code-first rewrite)
- **Requirement (Becky, 3 Nov):** the Workspace is the single place attendees build things. The Workspace Home "+" menu offers SQL file, Notebook, dbt Project, Streamlit App, **Agent**, **Semantic view** and **Pipeline Builder (Preview)**. New Agent files open with **Create with CoCo (Recommended)** or Start blank, so Cortex Code guided creation is the built-in recommended route.
- **Proposed mapping (to confirm in the fix plan):**

  | Module | Workspace creator | How |
  | --- | --- | --- |
  | C1, C2 | SQL file | explore with Cortex Code prompts in the sidebar |
  | DE1 | dbt Project (existing `dbt/`) | dbt pane, prompts for the missing marts, `build` |
  | DE2 | **Pipeline Builder** (new) | build the dynamic table / DQ pipeline visually (to check what Pipeline Builder supports) |
  | DA1 | Semantic view | create `SV_CLIENT_360` with CoCo |
  | DA2 | SQL file or Notebook | AI SQL prompts |
  | OPS1, AI1 | **Agent > Create with CoCo** | build the agent in the Workspace instead of `CREATE AGENT` SQL |
  | OPS2 | Streamlit App | build the triage app in the Workspace |
  | AI2, AI3, GOV1, GOV2 | SQL file + sidebar prompts | where no dedicated creator exists |

- **Notes for the fix:**
  - Pipeline Builder and Create with CoCo are Preview / new, so check they're available in event accounts (SFSEHOL org, aws_us_west_2, ENTERPRISE) and work as `HOL_PARTICIPANT`.
  - Agent and semantic view creators save files (for example `Untitled 1.agent.yaml`) in the Workspace. Steps must tell attendees the exact name to use, so Check my work finds the deployed object, and how to deploy it from the file.
  - The new-agent title shows as `Untitled%201` (URL-encoded space). This is a cosmetic product quirk, so tell attendees to rename it straight away.
  - C1 should open with a short Workspace tour: Home, the "+" creators, file explorer, the bottom panel (Query History, dbt), and the Cortex Code sidebar.
  - The Lab Companion module pages should say which Workspace creator to open at each step.
