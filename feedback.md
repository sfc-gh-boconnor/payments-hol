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
  | DA2 | Notebook `da2_feedback_analysis` | AI SQL prompts as cells, plus an altair chart |
  | OPS1, AI1 | **Agent > Create with CoCo** | build the agent in the Workspace instead of `CREATE AGENT` SQL |
  | OPS2 | Streamlit App | build the triage app in the Workspace |
  | AI2, AI3, GOV1, GOV2 | SQL file + sidebar prompts | where no dedicated creator exists |

- **Notes for the fix:**
  - Pipeline Builder and Create with CoCo are Preview / new, so check they're available in event accounts (SFSEHOL org, aws_us_west_2, ENTERPRISE) and work as `HOL_PARTICIPANT`.
  - Agent and semantic view creators save files (for example `Untitled 1.agent.yaml`) in the Workspace. Steps must tell attendees the exact name to use, so Check my work finds the deployed object, and how to deploy it from the file.
  - The new-agent title shows as `Untitled%201` (URL-encoded space). This is a cosmetic product quirk, so tell attendees to rename it straight away.
  - C1 should open with a short Workspace tour: Home, the "+" creators, file explorer, the bottom panel (Query History, dbt), and the Cortex Code sidebar.
  - The Lab Companion module pages should say which Workspace creator to open at each step.

### 8. "Failed to create document" from Workspace Home > + (Major, open)

- **What happened (3 Nov, after the LKRTFH rerun):** in the payments-hol Workspace, Home > **+** > a creator shows "Failed to create document".
- **Likely causes (not yet confirmed):**
  1. The rerun's **Deploy Workspace** job runs `CREATE OR REPLACE WORKSPACE DEFAULT_DATABASE.PUBLIC."payments-hol"`. A browser tab opened before the rerun points at the dropped workspace, so new files fail. Fix: reload Snowsight and reopen the Workspace.
  2. Role: the Workspace is owned by the event attendee role, and `HOL_PARTICIPANT` only gets READ/WRITE through PUBLIC. Creating files may need the owner role (or more than WRITE) in a shared Workspace. Test: switch back to the event's default role and try again.
- **Also a problem:** because of `CREATE OR REPLACE`, every rerun wipes the attendee's Workspace edits (for example the DE1 marts). The fix should make the job `CREATE WORKSPACE IF NOT EXISTS`, and only copy the files in on first creation.
- **To decide once the cause is known:** which role attendees work in (event role vs `HOL_PARTICIPANT`), and whether the Workspace grant needs to be OWNERSHIP or a direct grant to `HOL_PARTICIPANT`.
- **Confirmed cause (Becky, 3 Nov):** event logins sign in as `USER` with default role **ATTENDEE_ROLE**, which owns the payments-hol Workspace. The lab tells attendees to switch to `HOL_PARTICIPANT` (C1 step 2, every "Set your context" snippet, the event instructions). `HOL_PARTICIPANT` is granted to the user directly (`deploy_barclays_hol.sh`), not to ATTENDEE_ROLE, and only has READ/WRITE on the Workspace through PUBLIC, so creating files fails.
- **Proposed fix:** attendees stay in ATTENDEE_ROLE for the whole lab.
  - `deploy_barclays_hol.sh`: `GRANT ROLE HOL_PARTICIPANT TO ROLE ATTENDEE_ROLE` (alongside the existing user grant).
  - Remove `USE ROLE HOL_PARTICIPANT` / `USE SECONDARY ROLES NONE` from the step snippets (keep `USE WAREHOUSE`/`USE SCHEMA`), and remove "switch to HOL_PARTICIPANT" from `event_instructions.md`, `step1.md` and the README. The reference `.sql` files keep their role lines for blank-account installs.
  - GOV1 still works: `IS_ROLE_IN_SESSION('HOL_PARTICIPANT')` is true through inheritance, and the identifiers stay masked because ATTENDEE_ROLE isn't HOL_ADMIN. To verify: ATTENDEE_ROLE has no direct privileges on `BARCLAYS_HOL` that would bypass the read-only Iceberg guard (C1 insert test) or the policies.
  - Deploy Workspace: `CREATE WORKSPACE IF NOT EXISTS`, and copy the files only on first creation, so reruns keep attendee work.

## C1 results

### 9. C1 "See what has been published" prompt works, but Cortex Code started with no warehouse (Minor)

- **Output (Becky, 3 Nov):** as expected. Nine Iceberg tables with row counts (PAYMENTS 50,000), the metadata JSON location, and a good explanation of Snowflake-managed Iceberg: open Parquet/Iceberg, Snowflake as catalog and writer, Horizon Iceberg REST for other engines, Time Travel and policies still apply. Check `c1_iceberg_published` should pass.
- **Problem:** the first query failed because the Cortex Code session had no warehouse. Cortex Code then ran `USE WAREHOUSE BARCLAYS_WH` and retried. The sidebar session doesn't pick up the `USE` statements from the step 2 SQL file, and `USER`'s default warehouse is `DEFAULT_WH`, which HOL_PARTICIPANT can't use.
- **Fix:** in `deploy_barclays_hol.sh`, set `DEFAULT_WAREHOUSE = BARCLAYS_WH` (and `DEFAULT_NAMESPACE = BARCLAYS_HOL.ANALYTICS`) on the ALTER USER that sets the default role. Then the step 2 context snippet becomes optional.

## Lab Companion: activity checks

### 10. Check my work can't tell whether the attendee used Cortex Code (Major, new feature)

- **What happened (Becky, 3 Nov, lab complete):** Check my work only checks that objects exist. It can't show whether the Cortex Code prompt steps were done with Cortex Code, or by running the reference SQL.
- **What Snowflake records (checked in LKRTFH query history):**
  - Cortex Code in Snowsight sets `ALTER SESSION SET QUERY_TAG = '{"app":"cortex_code_sandbox","request_id":"..."}'` before its queries. Every statement it runs carries that tag, with `USER_NAME = USER` and `ROLE_NAME = HOL_PARTICIPANT`. Example: the C1 Iceberg prompt at 12:43 GMT (`SHOW ICEBERG TABLES`, `SYSTEM$GET_ICEBERG_TABLE_INFORMATION`).
  - dbt runs from the Workspace dbt pane show as `execute dbt project from workspace "DEFAULT_DATABASE"."PUBLIC"."payments-hol"`, with sessions whose `CLIENT_ENVIRONMENT` APPLICATION is `snowflake_dbt`.
  - Worksheet/SQL-file queries have no tag and come from "Snowflake Web App" sessions.
  - **The Lab Companion's own queries run as the app's service user (`MANAGED_SERVICE_1`, role HOL_ADMIN), not as `USER`.** Filtering on `USER_NAME = <attendee>` therefore excludes them, as Becky wants: only work done in Snowflake counts, not the guided app.
- **Expected:**
  1. **Activity checks per Cortex Code step:** besides "object exists", each prompt step gets a "Built with Cortex Code" check. It passes when a query tagged `cortex_code_sandbox` by the attendee created or changed the step's object. For example, a `CREATE` of `DT_LIVE_SLA_BREACHES`, found via `QUERY_TEXT`, or via `ACCESS_HISTORY.OBJECTS_MODIFIED` joined to the tagged query IDs. The DE1 marts check for a dbt-pane build after a Cortex Code session that edited the models. Show it in the step as "Done with Cortex Code" / "Done another way".
  2. **An "Ask about my progress" agent chat in the app:** a Cortex Agent over a view such as `BARCLAYS_HOL.LAB.V_ATTENDEE_ACTIVITY`, which holds the attendee's queries with a source column (`cortex_code` / `dbt_pane` / `worksheet` / `snowflake_intelligence`), the objects created and the timestamps. Attendees and facilitators can ask "what have I done with Cortex Code?" or "which modules did USER finish?". The view must exclude the app's service user and the DataOps/admin users (`DATAOPS_SERVICE_ADMIN`, `EMERGENCY_SERVICE_USER`, `SYSTEM`), so the chat's own queries never show up as activity.
  3. **The facilitator board** shows the same Cortex Code / other-way split per attendee.
- **Notes for the fix:**
  - **Data source:** `INFORMATION_SCHEMA.QUERY_HISTORY_BY_USER` is near real time but covers only 7 days, and the app role needs MONITOR on the user. `ACCOUNT_USAGE.QUERY_HISTORY` / `ACCESS_HISTORY` lag up to about 45 minutes / 3 hours, which is too slow for live Check my work. Use the information schema for live checks, and account usage for post-lab reporting.
  - Snowflake Intelligence and agent-playground chats (OPS1, AI1, AI3) don't show up as worksheet SQL. Their Analyst queries are the signal (semantic view queries by `USER`); confirm what tag or client they carry.
  - Check whether Cortex Code usage also lands in an ACCOUNT_USAGE Cortex Code usage view. That would give per-request counts without parsing query tags (not verified).
  - **Seen while checking (3 Nov, LKRTFH):** since 12:37 GMT, the only Cortex Code activity for `USER` is the C1 Iceberg prompt; the earlier dbt build at 11:42 GMT was from the dbt pane. Either the rest of the lab was done in another account or session, or the rebuild reset what's visible. Confirm with Becky which account she finished the lab in, before using LKRTFH as test data.

### 11. DE1 step 2: "choose build" didn't match the dbt pane UI (Minor, fixed locally)

- **What happened:** the arrow next to Run opens a **Select Operation** dialog (Deps, Seed, Compile, Run, Test, **Build**, Retry, Parse, …) with an **Execute** button. The step said "choose build from the Run dropdown" and didn't explain why Build rather than Run.
- **Fix (local, not pushed):** DE1 steps 2 and 4 now say: click the arrow next to Run > **Select Operation** > **Build** > **Execute**. They also explain that Build runs the models and tests in order, while Run skips the tests that prove the Cortex Code marts.

### 12. DE1 step 4: Check my work fails after Cortex Code writes mart_rm_performance (Major, fixed locally)

- **What happened (LKRTFH query history, 13:00–13:08 GMT):** for `mart_customer_payments`, Cortex Code ran `build --select +mart_customer_payments` and tests itself, so the table existed. For `mart_rm_performance`, it only ran `compile --select mart_rm_performance`, because the prompt said "tell me to run dbt build". The table was never created, so `de1_coco_marts` failed even though the model was done.
- **Fix (local, not pushed):** the step 4 prompt now tells Cortex Code to run dbt build for the model and its upstream models, and fix it until the tests pass. The "What you should see" line says to confirm with a full **Build** from the dbt pane, and that the table only exists after a build.
- **Also:** the check label "Cortex Code built MART_RM_PERFORMANCE" reads as if writing the file is enough. Change it to "MART_RM_PERFORMANCE built and tested", with the hint "Run Build from the dbt pane".
- **Update (Becky):** make the build explicit as its own step. DE1 now has step 4 "Generate mart_rm_performance with Cortex Code" (no check), then step 5 "Build the whole project and check the tests": dbt pane > arrow next to Run > Build > Execute, expect 8 models and `ERROR=0`. `de1_coco_marts` is attached to step 5, and its hint points to step 5.

### 13. DE1 "Schedule the project" had no Check my work (Minor, fixed locally)

- **Fix (local):** new check `de1_task`, "Nightly dbt build task scheduled (suspended)", using `SHOW TASKS LIKE 'TSK_DBT_NIGHTLY_BUILD' IN SCHEMA BARCLAYS_HOL.ANALYTICS`, attached to step 6. Verified in LKRTFH as HOL_ADMIN: it passes for Becky's task (suspended, `USING CRON 0 5 * * * Europe/London`).
- **Gap to fix:** the task runs the **deployed** project object `BARCLAYS_HOL.ANALYTICS.BARCLAYS_DBT`, which was deployed at provisioning. It doesn't include the marts Cortex Code just wrote in the Workspace. Add a step (or prompt) to deploy the Workspace's `dbt/` to `BARCLAYS_DBT` (Workspace dbt deploy, or `ALTER DBT PROJECT ... DEPLOY FROM 'snow://workspace/DEFAULT_DATABASE.PUBLIC."payments-hol"/versions/live/dbt'`, still to verify), and explain why: the Workspace is where you develop, the deployed object is what production schedules.

### 14. Nothing says whether to start a new Cortex Code chat per module (Minor, fixed locally)

- **What happened:** moving from DE1 to DE2, the attendee wasn't sure whether to keep the same Cortex Code chat.
- **Fix:** add a line to each module's first step, and to C1's Cortex Code step: "Start a new Cortex Code chat for each module (**+** at the top of the sidebar). The prompts name every object in full, so they don't depend on earlier chats, and a fresh chat keeps Cortex Code focused." A new chat also makes the activity checks (item 10) easier to attribute per module.
- **Decision (Becky):** one new Cortex Code chat per module, so context doesn't build up. Done locally: every module page shows a "Start a new Cortex Code chat for this module" note at the top of Steps, and C1's Cortex Code step says the same.

## DE2 Dynamic Tables + data quality

### 15. Show the dynamic table results and lineage in the Lab Companion (Enhancement)

- **Idea (Becky, 3 Nov):** after a dynamic table step, a Lab Companion button to **show the outcome** (a preview of the rows) and a **React diagram of the pipeline**, in the style of Snowsight's dynamic table graph. Also point attendees to the lineage in the Snowsight UI.
- **Proposed design:**
  - **"Show result" button** on steps that create a table: it runs `SELECT * FROM <object> LIMIT 20` as the app and renders a small table under the step. Add a `Preview: <FQN>` field to the README step format (`sync-content` parses it), so any module can use it (DE2 DTs, DA2 `RM_FEEDBACK_THEMES`, OPS2 queue and recommendations).
  - **Pipeline graph card** on DE2 (and DE1 for dbt): nodes from `SNOWFLAKE.CORE.GET_LINEAGE(<object>, 'TABLE', 'UPSTREAM', 3)` plus `INFORMATION_SCHEMA.DYNAMIC_TABLES()` for each DT's target lag, refresh mode, last refresh and state. Render left to right: Iceberg sources > staging/marts > `DT_FAILED_PAYMENT_TRIAGE` > `DT_RETRYABLE_SUMMARY`, with `MART_SLA_COMPLIANCE` > `DT_LIVE_SLA_BREACHES`. Colour by kind (Iceberg, view, table, dynamic table), with a status dot per DT (refreshed / failed / not yet built) and the target lag on the node, like Snowsight's graph. Use a layered DAG layout (for example React Flow with dagre), or plain SVG if dependencies should stay light.
  - The graph only shows objects that exist, so it fills in as the attendee builds. That makes it a progress visual, not just a diagram.
- **UI pointer (done locally):** DE2's first DT step now says where to see the table and its lineage in Snowsight (Catalog > Database Explorer > the DT > Data Preview / Lineage). The refresh step already mentions **Monitoring > Dynamic Tables > Graph**.
- **To check:** the app role (HOL_ADMIN) can call `GET_LINEAGE` on these objects (lineage hides objects the role can't see, as `***`), and the exact Snowsight menu path in event accounts.

### 16. DE2 Pipeline Builder should be a real step, and attendees lacked its privileges (Major, fixed locally + LKRTFH)

- **What happened (Becky):** the "Optional: explore Pipeline Builder" step should be a real build step. Creating a Pipeline Builder project with schema `RAW_DATA` failed: *"Your primary role HOL_PARTICIPANT must have CREATE DCM PROJECT granted on SCHEMA BARCLAYS_HOL.RAW_DATA."*
- **Cause:** each Pipeline Builder pipeline is a **DCM project**. `RAW_DATA` is the read-only Iceberg source schema, so nothing should be created there. HOL_PARTICIPANT already has `CREATE DCM PROJECT` and `CREATE TASK` on `ANALYTICS`. The [docs](https://docs.snowflake.com/en/user-guide/pipeline-builder/pipeline-builder-overview) also require `EXECUTE TASK` on the account to run task graphs, and `CREATE CODE BUNDLE` on the schema for notebook/Python tasks. HOL_PARTICIPANT had neither.
- **Fix:**
  - **LKRTFH (done now):** `GRANT EXECUTE TASK ON ACCOUNT` and `GRANT CREATE CODE BUNDLE ON SCHEMA BARCLAYS_HOL.ANALYTICS` to HOL_PARTICIPANT.
  - **`setup/00_admin_provision.sql` (local, not pushed):** the same two grants, so new events get them.
  - **DE2 step 6 (local):** "Orchestrate the pipeline with Pipeline Builder" replaces the optional step. Name `payments_nightly`, schema **BARCLAYS_HOL.ANALYTICS** (with an explicit "not RAW_DATA" warning and why), **Generate with Cortex** with a prompt for a 3-task graph (dbt build > DT refresh + DQ checks, 05:00 London, suspended), then Deploy.
  - **New check `de2_pipeline` (local):** "Pipeline Builder project created in ANALYTICS" (`SHOW DCM PROJECTS IN SCHEMA BARCLAYS_HOL.ANALYTICS`). The SQL is verified in LKRTFH as HOL_ADMIN: currently false, as expected.
- **Notes:**
  - Per the docs, Pipeline Builder orchestrates tasks only; it doesn't build dynamic tables or views. That's why it comes after the DT steps, and the step says so.
  - Not yet verified: how **Generate with Cortex** handles this prompt, and the deployed task names. Check against Becky's run. If the names differ, the check (DCM project only) still passes.
  - Item 13 applies here too: the dbt task runs the deployed `BARCLAYS_DBT`, which doesn't have the Cortex Code marts until the Workspace project is deployed.

### 17. "Set your context" SQL snippets serve no purpose in a Cortex Code-first lab (Minor, fixed locally + LKRTFH)

- **What happened (Becky):** every module started with a "Set your context" SQL snippet (`USE ROLE`/`USE WAREHOUSE`/`USE SCHEMA`). Cortex Code runs in its own session, so a SQL file's `USE` statements never reach it (see item 9, where it started with no warehouse). Every prompt names its objects in full anyway.
- **Fix:**
  - **Removed (local):** the "Set your context" step from all 8 vignettes that had one. C1's "Open Cortex Code" step no longer has a snippet; it says you're signed in as `HOL_PARTICIPANT` on `BARCLAYS_WH`, so there's nothing to set.
  - **LKRTFH (done now):** `ALTER USER "USER" SET DEFAULT_WAREHOUSE = BARCLAYS_WH`, so `USER` now defaults to HOL_PARTICIPANT, BARCLAYS_WH and no secondary roles (verified). Takes effect from the next sign-in.
  - **DataOps `deploy_barclays_hol.sh` (staged locally in `/tmp/dbh.sh`, not committed):** the ALTER USER now also sets `DEFAULT_WAREHOUSE = BARCLAYS_WH`. This resolves item 9 for future events.
  - **Check hints (local):** removing steps shifted the step numbers, so the hints no longer quote "Step N". They describe the action instead, and the page shows each check next to its step.
- The reference `.sql` files keep their `USE` lines: they're run as scripts, where those lines do matter.

## GOV2 Lineage, audit and trust

### 18. Add Cortex Code automations to the lab (Enhancement, added locally)

- **Idea (Becky, 3 Nov):** after the restricted-column access query, Cortex Code itself suggested *"This could run as a daily cortex automation that reports any new reads of these columns. Want me to set it up?"* That should be a lab step.
- **Added (local, not pushed):** GOV2 step 4, "Turn the access check into a daily automation". The prompt creates `RESTRICTED_COLUMN_WATCH` (daily 08:00 London, read-only, unattended), created paused, test-run once, then scheduled. New check `gov2_automation` looks for a `COCO_ROUTINE_%` agent task in the attendee's own `"USER$".PUBLIC`.
- **What I verified in LKRTFH:**
  - `EXECUTE AGENT TASK` is granted to PUBLIC, so HOL_PARTICIPANT can create automations. No new grant is needed.
  - An automation is an `AGENT TASK` in the creating user's personal database, and each run uses the user's **default role**, now HOL_PARTICIPANT (item 8), so runs see what the attendee sees, policies included.
  - The app's role (HOL_ADMIN) **can't** see personal-database agent tasks (`SHOW AGENT TASKS IN ACCOUNT` returns 0). The check therefore runs with **caller's rights**: a new `asCaller` option on checks, used only by this check. The SQL shape was verified as a non-admin role; it hasn't yet been tested end to end as `USER` through the deployed app.
  - `USER` has **no email address** (`IS_EMAIL_VERIFIED = false`), so the automatic run-report email can't be delivered. The step tells attendees to read the report in the run's thread. Optional fix: set an email on event users in the DataOps job, but each attendee would still have to verify it.
- **Notes:**
  - Each run costs task billing plus Cortex Code tokens (preview pricing), and the minimum frequency is hourly. Decide whether attendees should suspend or drop it at the end of the lab (the facilitator could add it to SLEEP_LAB()).
  - ACCOUNT_USAGE.ACCESS_HISTORY lags by up to about 3 hours, so the first run may report nothing.

### 19. HOL_PARTICIPANT can't see the Lab Companion app (Blocker, fixed in LKRTFH + locally)

- **What happened (Becky):** signed in as HOL_PARTICIPANT, the Lab Companion app isn't visible.
- **Cause:** HOL_PARTICIPANT had USAGE on the app and on `BARCLAYS_HOL`, but **not on the `BARCLAYS_HOL.LAB` schema** that holds the app. Setup 04 deliberately gave attendees nothing on LAB ("the app writes on their behalf"), which left the app invisible to them. This only showed up now because `USER` previously signed in as ATTENDEE_ROLE and switched roles; now its default role is HOL_PARTICIPANT (item 8). HOL_RESTRICTED had no access to the app at all.
- **Fix:**
  - **LKRTFH (done now):** USAGE on schema `BARCLAYS_HOL.LAB` and on the application service for HOL_PARTICIPANT, HOL_RESTRICTED and ATTENDEE_ROLE, plus USAGE on `BARCLAYS_HOL` for ATTENDEE_ROLE. Verified with SHOW GRANTS.
  - **`setup/04_lab_companion.sql` (local):** grants USAGE on the LAB schema to HOL_PARTICIPANT and HOL_RESTRICTED. HOL_RESTRICTED sits *below* HOL_PARTICIPANT (it's granted to it), so it needs its own grants.
  - **`setup/install_lab_companion.sh` (local):** grants USAGE on the app to both HOL_PARTICIPANT and HOL_RESTRICTED. ATTENDEE_ROLE inherits HOL_PARTICIPANT in event accounts, so it needs nothing extra there.
- Attendees still can't read `LAB_PROGRESS` directly: USAGE on the schema doesn't give table access.

### 20. Cortex Code looks for a warehouse at the start of every chat (Minor, fixed locally)

- **What happened (Becky, DA1):** Cortex Code kept trying to find an available warehouse before running anything, which felt like it needed a "set context" step again.
- **Checked in LKRTFH:** `USER`'s `DEFAULT_WAREHOUSE` is `BARCLAYS_WH`, and Becky's sign-in (14:38 GMT) was after it was set. Query history shows Cortex Code itself running `USE WAREHOUSE BARCLAYS_WH` at the start of the chat, then every query running on `BARCLAYS_WH`. Cortex Code resolves a warehouse itself rather than relying on the session default, so a user default doesn't remove that first lookup.
- **Fix (local):** the "Start a new Cortex Code chat" note at the top of every module's Steps now includes a copyable **context prompt card**: "For this chat, use role HOL_PARTICIPANT and warehouse BARCLAYS_WH, and work in database BARCLAYS_HOL. I'm working on lab module <code>: <title>." The chat starts with the right context in one paste, which keeps the lab Cortex Code-first. C1 explains why it's there.
- Keep the user default warehouse (item 17): worksheets, the dbt pane and automations (which run with the user's defaults) rely on it.

## DA2 AI SQL on customer feedback

### 21. AI_FILTER churn step returns nothing: the seed feedback has no churn statements (Major, fixed locally)

- **What happened (Becky):** the AI_FILTER prompt ("find feedback that mentions a risk of the client moving their business elsewhere") didn't give a short list. Cortex Code correctly found that the 2,000 feedback rows contain only **12 distinct texts** (6 negative, 6 positive) and none mentions leaving. A loose prompt matched every complaint (1,000+ rows); a strict one matched none.
- **Cause:** `setup/01_seed_synthetic_data.sql` draws `FEEDBACK_TEXT` from a fixed array of 12 sentences.
- **Fix (local, not pushed):**
  - **Seed:** 24 texts. Added 3 explicit churn statements (reviewing other providers, moving to another bank, tendering their banking), 3 aspect texts (speed / communication / fees, for DA2's AI_SENTIMENT step) and 6 with payment references and amounts (for the AI_EXTRACT prompt). Random index `UNIFORM(0,23,...)`.
  - **DA2 prompt:** now asks for *explicit* statements of leaving, switching, moving or tendering ("not ordinary complaints"), grouped by distinct text. **Expect** says three distinct churn statements, and explains that this is the difference from a sentiment score.
  - **Verified in LKRTFH:** the new AI_FILTER wording over all 24 texts returns TRUE for exactly the 3 churn texts and FALSE for the other 21.
- **Note:** existing accounts keep the old 12 texts until setup 01 and 02 are rerun (the RAW_DATA Iceberg tables are republished), and FEEDBACK_ENRICHED is rebuilt. LKRTFH not reseeded: Becky decided (3 Nov) to leave it until the next build.

### 22. Legacy `SNOWFLAKE.CORTEX.SENTIMENT` is blocked in event accounts: the DA2 reference SQL and the core_analytics catch-up fail (Blocker, fixed locally)

- **Found while testing item 21:** *"SNOWFLAKE.CORTEX.SENTIMENT is not available on this account. New accounts are blocked from using legacy SNOWFLAKE.CORTEX functions."* Becky's Cortex Code run worked around it (it scored sentiment with `AI_COMPLETE`), but anyone using the reference SQL or `setup/catchup/core_analytics.sql` gets an error. That catch-up is the prerequisite for DE2, DA1, OPS2 and others.
- **Fix (local):** both files now use `AI_SENTIMENT`, mapping the overall label to `positive = 1, negative = -1, neutral/mixed = 0`, so `SENTIMENT_SCORE` and the existing ±0.3 `SENTIMENT_LABEL` thresholds still work. The DA2 enrichment prompt tells Cortex Code to do the same and not to use the legacy function. Verified in LKRTFH: AI_SENTIMENT returns the expected labels, and both `FEEDBACK_ENRICHED` queries compile as HOL_PARTICIPANT.
- **Trade-off:** the score is now 3-valued rather than continuous, so "average sentiment" reads as a balance of positive vs negative. That's fine for the lab's charts and thresholds.
- `legacy/` (v1) and `guide/` still reference the old functions; they aren't part of v2.

### 23. DA2 "sectors with worsening sentiment" finds only noise: the seed has no trend (Major, open)

- **What happened (Becky):** the "Go further" prompt (sectors with worsening sentiment month over month) worked. Cortex Code's caveats were all correct (checked in LKRTFH): November 2026 has 7 rows (dates span 3 Nov 2025 to 3 Nov 2026); Pharmaceuticals and Real Estate have 11 months; all 1,046 negative rows score exactly -1. It then suggested a **monthly Cortex Code automation** to track it. That's valid (automations take any schedule down to hourly, e.g. cron on the 1st of the month).
- **Problem:** the seed gives every feedback row a random date (`UNIFORM` over 8,760 hours) and a random text, so there is **no real trend**. Any "worsening" sector is random noise, and a monthly automation on static lab data would keep reporting noise.
- **Fix (proposed):**
  - **Seed:** bias the text choice by sector and date so a clear story exists. For example, Logistics feedback turns increasingly negative over the last 4 months (more delay/outage texts), and Pharmaceuticals improves. Keep the rest random. Ideally the churn statements (item 21) cluster in the worsening sector, so DA2's steps connect: worsening sentiment > churn risk > RM themes.
  - **Expect line:** name the sector the attendee should find, so the result can be checked.
  - Exclude the current partial month in the prompt ("complete months only"), so the attendee doesn't hit the 7-row month.
  - The automation idea fits better in GOV2 (item 18) or as an optional DA2 extension; mention that monthly needs a cron schedule.

### 24. DA2 "chart it" prompt: Cortex Code doesn't produce a chart in the sidebar (Minor, fixed locally)

- **What happened (Becky):** "Using FEEDBACK_ENRICHED, show me which customer sectors have worsening sentiment month over month and chart it" returned the analysis but no chart. The step's Expect promised "a chart in the sidebar".
- **Superseded by item 25 (DA2 is now a Notebook with a real chart).** Previous fix: the prompt asked Cortex Code to write the trend query (MONTH, CUSTOMER_SECTOR, AVG_SENTIMENT, complete months only) into a new SQL file and summarise which sectors are worsening. Expect tells attendees to run it and use the results pane's **Chart** tab (Line, MONTH on X, AVG_SENTIMENT value, CUSTOMER_SECTOR series). Not verified: whether Cortex Code in Snowsight can render charts in the sidebar at all. If it can, the prompt could ask for it again.
- Pairs with item 23: until the seed has a planted trend, the chart shows noise.

## 25. DA2 as a Notebook (charts) — FIXED locally
The Cortex Code sidebar can't render charts, so DA2 is now built in a Workspace Notebook `da2_feedback_analysis` (+ > Notebook, NOTEBOOK_POOL + BARCLAYS_WH). Each prompt asks Cortex Code to add and run a named cell; new step "Chart sentiment by sector" adds an altair line chart. Needs: USAGE on NOTEBOOK_POOL for HOL_PARTICIPANT (in DataOps deploy_workspace.yml) and CREATE NOTEBOOK on ANALYTICS (in setup). First pool start takes 1–2 min — consider resuming NOTEBOOK_POOL just before the session. Pool is max 1 node XS: check sizing for a full room (one notebook kernel per attendee).

## 26. Pipeline Builder deploy fixes (DE2) — FIXED locally
- Generate with Cortex deployed the tasks **started**, despite "keep suspended" in the prompt. A second build then failed: "cannot change orchestration model while PIPE_DBT_BUILD is not suspended". Fixed in LKRTFH by suspending PIPE_DBT_BUILD. The step now has a troubleshooting note for this.
- The plan then failed because the graph-wide warehouse default would remove each task's own warehouse, which makes a task serverless and needs EXECUTE MANAGED TASK (not granted to HOL_PARTICIPANT). Cortex Code fixed it by setting `warehouse: BARCLAYS_WH` on each task.
- The prompt now asks for a warehouse on each task (no graph default) and desired state Suspended. Steps also cover Workspace Home > Pipeline Builder, the Prompt box + Generate, Proceed/Modify/Cancel, Deploy, and reopening the pipeline.

## 27. GOV2 standalone audit pack — FIXED locally
- **Problem:** GOV2 is on the Data Engineer (C1 > DE1 > DE2 > GOV2) and Governance (C1 > GOV1 > GOV2 > AI3) pathways, but needed `SV_CLIENT_360` (DA1), `CORPORATE_PAYMENTS_360` (OPS1) and `MART_SLA_COMPLIANCE` (DE1). The ready-made SV_PAYMENTS / PAYMENTS_ASSISTANT only build with `--with-reference-build`, which events don't use (and it would pre-build other modules).
- **Fix:** new `setup/06_audit_pack.sql`, run at every provisioning (provision_account.sh step 4a and INSTALL.sql). Builds `BARCLAYS_HOL.AUDIT_PACK` (owned by HOL_PARTICIPANT) on the Iceberg sources: `PAYMENT_SLA_DAILY`, `CLIENT_ACCOUNTS` (IBAN, ACCOUNT_NUMBER, SORT_CODE), `SV_PAYMENTS_AUDIT` and `PAYMENTS_AUDIT_AGENT`. No names overlap other modules. GOV2 steps, gov2.sql, the documentation check and prerequisites (now just the pack) point at it.
- **Verified in LKRTFH:** lineage RAW_DATA.PAYMENTS > PAYMENT_SLA_DAILY > SV_PAYMENTS_AUDIT > PAYMENTS_AUDIT_AGENT; upstream from the agent reaches the Iceberg tables; semantic view queries; gov2.sql runs clean as HOL_PARTICIPANT. Not verified: the agent chat answering in Snowsight.

## 28. GOV2 automation check failed although the automation existed — FIXED in LKRTFH
- **Cause:** the check runs `SHOW AGENT TASKS ... IN SCHEMA "USER$".PUBLIC` with the attendee's caller's rights, but the app runs with *restricted* caller's rights, so its owner role HOL_ADMIN needs CALLER grants on the user's personal database: "Database USER$ does not exist or not authorized ... must have CALLER USAGE ... on DATABASE USER$USER".
- **Fix:** granted HOL_ADMIN CALLER USAGE on `USER$USER`, INHERITED CALLER USAGE on its schemas and INHERITED CALLER MONITOR on its tasks (LKRTFH, done). Added the same to `setup/03_add_participants.sql` and to the DataOps `deploy_barclays_hol.sh` (local `/tmp/dbh.sh`, not yet committed to DataOps).
- **Not verified:** whether `USER$<name>` exists before the user first signs in. If not, the DataOps grant fails on a fresh account and needs to run later (e.g. from the Lab Companion setup).

## 29. New module DA3: branch network and spatial analytics (retail banking) — BUILT locally
- **Why:** Becky wanted geospatial for retail banking on the analyst side, modelled on CARTO's "Agentic GIS for Financial Services" branch consolidation story.
- **Data:** new `setup/07_retail_geo_seed.sql` (provisioning step 4c and INSTALL.sql) builds `BARCLAYS_HOL.RETAIL`, read-only to attendees: 57 branches around 8 UK cities, 144 ATMs, 20,000 retail customers and ~146k branch visits, all with GEOGRAPHY points. Planted answers: overlap pairs in Manchester (0.31 km), Glasgow (0.35 km) and Leeds (0.54 km); King Street and Boar Lane are high-cost, low-footfall; Barry is 8 km from any other branch with older, less digital customers.
- **Module:** a Workspace Notebook (network map, ST_DISTANCE nearest branch, ST_DWITHIN overlaps, H3 density map, closure impact), then the `SV_BRANCH_NETWORK` semantic view, Cortex Analyst questions and the `BRANCH_NETWORK_ADVISOR` agent via Create with CoCo. Four checks plus a prerequisite check; added to the Data Analyst pathway (C1 > DA2 > DA1 > DA3).
- **Verified in LKRTFH:** the seed and `da3.sql` run clean as HOL_PARTICIPANT; Boar Lane and King Street rank as the top LOW-risk candidates and Barry as HIGH; every check passes.
- **Not verified:** the Cortex Code notebook prompts (cell creation and the altair maps), Analyst answers in Snowsight, and the agent's consolidation plan.
- **Design limits:** the semantic view uses numeric distances because GEOGRAPHY support in semantic views isn't documented. Maps are altair on LON/LAT (no basemap); pydeck in Workspace notebooks is unconfirmed.

- **Update (ORS travel times):** straight-line distance replaced with real road-network travel from OpenRouteService on SPCS, precomputed once (Becky's routing quickstart) so event accounts don't need ORS. `setup/tools/ors_precompute.py` ran MATRIX and ISOCHRONES in LKRTFH across 8 UK regions (BBBike city extracts, Wales for Cardiff), producing `data/retail/branch_cell_travel.csv.gz` (162,453 drive and walk times, branch to H3 res-8 cell) and `branch_isochrones.csv.gz` (171 catchments). These load into `RETAIL.BRANCH_CELL_TRAVEL` / `BRANCH_ISOCHRONES`. Verified: King Street and Boar Lane are top LOW-risk closures (+0.7 and +1.9 drive minutes), the overlap pairs share 85-99% of their 10-minute catchments, Barry is HIGH (p90 +17.9 minutes, 465 vulnerable customers), and 19,526 of 20,000 customers are routable. The ORS engine is left installed in LKRTFH, suspended.
