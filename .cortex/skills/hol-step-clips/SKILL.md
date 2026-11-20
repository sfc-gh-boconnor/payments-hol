---
name: hol-step-clips
description: "Record, re-record or add the small looping MP4 step clips shown in the Payments HOL Lab Companion (Snowsight UI steps such as opening the payments-hol Workspace, opening a starter notebook, creating its notebook service, running dbt build, pasting a prompt into Cortex Code). Use when a lab step needs a clip, a clip is out of date or shows the wrong module, or Snowsight has changed. Triggers: record a clip, re-record the mp4, animation for this step, add a video to the step, clip shows the wrong notebook."
---

# Payments HOL: step clips

Clips are recorded locally with Playwright against the test account in `media/config.json`, from scripts in `media/scripts/`. They play in the Lab Companion through a `Media:` line in the module README.

## Rules for every clip

- MP4 only (no GIFs), 1024x640 browser, 720 px output, 10 fps, under 500 KB. Crop away empty space.
- Show what a first-time attendee sees: reset state (workspace, open tabs, folders, open chats) **before** `mark()`. No files from earlier recordings should be open.
- Each module gets its own clip when the module's object is visible in it (e.g. each starter notebook has its own service clip). Don't reuse another module's clip.
- Highlight every click (`clickWithHighlight`). Paste prompts with `fill`, never type them or send them.
- Never press buttons that start compute or change the account (Create and connect, Execute, Send). Highlight them instead and cancel.

## Workflow

### 1. Sign in (if needed)

`cd media && npm run login`. The user signs in in the Chrome window, which closes when Snowsight loads. Do this again when a recording fails on a "Session expired" or sign-in page (check `out/<name>.failed.png`).

### 2. Write or change the script

Build from the steps in `media/snowsight.mjs`, not raw selectors:

| Step | What it does |
| --- | --- |
| `switchTo(page, "Home" \| "CoCo")` | Home/CoCo toggle; closes the CoCo preview pop-up |
| `openWorkspace(page, "payments-hol", { fresh })` | Workspaces > picker; `fresh: true` resets to My Workspace |
| `closeAllTabs(page)` | close every open editor tab (setup, so no earlier files show) |
| `closeFolder(page, folder, childPrefix)` | collapse a folder so the clip shows it opening |
| `openFile(page, folder, prefix)` / `openNotebook(page, name)` | open a file or starter notebook |
| `createNotebookService(page, opts)` | service dropdown > Create new service > pool, idle timeout, integration; cancels |
| `pickOption` / `pickMulti` | single and multi-select form dropdowns |
| `pasteIntoCocoSidebar(page, prompt)` | Cortex Code sidebar > New chat > paste |

A script exports `name`, `viewport`, `outputWidth`, `crop` and `run({ page, mark })`. For a variant of an existing clip, follow `scripts/da2_notebook_service.mjs`: a few lines that call a shared run function with the module's object.

If a step is missing, add it to `snowsight.mjs` with a comment on any quirk, so the next clip gets it for free.

### 3. Record and check

```bash
npm run record -- <name>              # headless
npm run record -- <name> --headed     # watch it when fixing selectors
DEBUG=1 npm run record -- <name>
```

On `FAILED`, read `out/<name>.failed.png` and the `.mjs:` line in the error. Then **look at the result**: pull the last frame and confirm the end state matches the guide.

```bash
ffmpeg -loglevel error -y -sseof -2.5 -i out/<name>.mp4 -frames:v 1 /tmp/<name>_end.png
```

### 4. Publish to the Lab Companion

1. `cp media/out/<name>.mp4 lab-companion/public/media/`
2. In the module README, under the step: `Media: <name>.mp4 | <one-line caption>`
3. `cd lab-companion && node scripts/sync-content.mjs` (fails if the file is missing)
4. Ask before redeploying. Then `snow app deploy --connection hvennf --role HOL_ADMIN`, and re-grant `USAGE ON APPLICATION SERVICE BARCLAYS_HOL.LAB.LAB_COMPANION` to `HOL_PARTICIPANT` and `HOL_RESTRICTED`.

## Snowsight quirks (already handled in snowsight.mjs)

- The Workspaces UI is in an iframe; Snowsight remembers the last workspace, folder state and chat.
- Form fields: match `button[aria-label="<label>"]`. The accessible name includes the current value, and a "<label> help" icon button has the same prefix.
- Multi-select lists toggle on each click; Escape, Tab or an outside click clears the choice.
- The left nav flyout stays open unless the mouse moves away.
- The notebook form remembers the last choices, and the default service name moves on (`USER_SERVICE_2`) once `USER_SERVICE_1` exists.

## Stopping points

- Before redeploying the Lab Companion.

## Output

The clip path and size, its end frame checked against the guide, and the README step it is attached to.
