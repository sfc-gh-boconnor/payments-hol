---
name: hol-step-layout
description: "Lay out and rewrite Payments HOL module steps (core/C1_README.md, vignettes/*/README.md) so they're easy to read in the Lab Companion: short sentences, bullets, numbered actions, spacing, no walls of text. Use when writing or editing any lab step, when a step feels dense, compact or overwhelming, or when asked to tidy, simplify or format a module. Triggers: too much text, hard to read, bullet this, tidy the steps, format the module, make it easier to read."
---

# Payments HOL: step layout

Attendees read steps beside Snowsight, often mid-click. Every step must be scannable in a few seconds: **what to do** first, the background second, and none of it in long paragraphs.

## How a step renders (Lab Companion)

Inside a `### Step title` block, `lab-companion/scripts/sync-content.mjs` and `components/lab/step-body.tsx` support:

| Write | Renders as |
| --- | --- |
| `Where: ...` | the grey location line under the title |
| `Media: clip.mp4 \| caption` | a looping clip (see the hol-step-clips skill) |
| a plain line | its own paragraph, with space around it |
| `1. ...` lines | a numbered list (the actions) |
| `- ...` lines | bullets; straight after a numbered item they're indented under it |
| `\| a \| b \|` rows | a table (first row is the header) |
| ` ```prompt ` fence | the Paste into Cortex Code card |
| `Expect:` / `Check:` | the "What you should see" line and the check link |

Each line is its own block, so never wrap a sentence across two lines.

## Rules

1. **Actions are numbered.** Anything the attendee clicks or types is a `1.` list, one action per item, in screen order. Put the UI label in **bold**, exactly as Snowsight shows it.
2. **One idea per line.** At most 2 short sentences per paragraph, and about 25 words per sentence. Split anything longer.
3. **Bullets for anything listed.** Options, features, tips, "what's here": bullets of a few words, not commas in a sentence.
4. **Why after what.** Background goes after the actions, in 1-2 short lines or a bullet list, never before them.
5. **Call out the trap.** If there's a common mistake (wrong workspace, toggle on the wrong side), give it its own line starting with **Tip:** or **Important:**.
6. **Tables for settings.** Three or more settings to choose = a `Setting | Value` table.
7. **No repetition.** Don't repeat the `Where:` line in the body. Say each thing once.
8. **Plain words.** UK spelling, no jargon the attendee hasn't met yet, no emoji, no em dashes.
9. **Keep the machinery.** Don't change prompts, `Check:` ids, `Media:` lines or anchors unless asked.

## Example

Before (hard to read):

```
Switch the toggle back to **Home** first: Workspaces is only on the Home side, so you won't find it while you're in CoCo. Then open **Projects > Workspaces** and pick **payments-hol** from the **My Workspace** dropdown. This shared Workspace is where you'll build ... Take a quick tour: **Home** and the **+** button list everything you can create here (SQL file, Notebook, ...).
```

After:

```
1. Switch the toggle at the top left back to **Home**.
2. Open **Projects > Workspaces**.
3. Open the **My Workspace** dropdown (top left) and pick **payments-hol**.
**Important:** go back to **Home** first. Workspaces isn't on the CoCo side.
What's in the Workspace:
- **+** creates SQL files, notebooks, dbt projects, Streamlit apps and more
- the file explorer (left) holds the lab: `dbt/`, `notebooks/`, `vignettes/`
```

## Workflow

1. Read the module README(s) the user names (all of `core/C1_README.md` and `vignettes/*/README.md` if they say "all").
2. Rewrite each step body to the rules. Keep the facts; drop only repetition.
3. Run `cd lab-companion && node scripts/sync-content.mjs` (it fails on a missing clip).
4. Show the user one rewritten step before/after. For more than one module, stop for approval after the first before doing the rest.
5. Ask before redeploying the Lab Companion. Deploy as in the hol-step-clips skill.

## Stopping points

- After the first module when doing several.
- Before redeploying.

## Output

The modules and steps rewritten, a before/after sample, and whether the app was redeployed.
