# Step clips

Small looping MP4s of Snowsight UI steps for the Lab Companion, recorded locally with Playwright.

## Setup (once)

```bash
cd media
npm install
npm run login            # sign in in the Chrome window; it closes when done
npm run login -- --keep  # or keep the browser open
```

The session is saved in `.auth/profile` (not committed). Rerun `login` when it expires.
The account is set by `snowsightUrl` in `config.json`.

## Record

```bash
npm run record -- de1_dbt_tab            # one clip, headless
npm run record -- de1_dbt_tab --headed   # watch it, to fix selectors
npm run record -- --all                  # every script
```

Clips are written to `out/<name>.mp4`. Each line reports the size, and `TOO BIG` means it's over `output.maxKb`.
Use the MP4s: they're about a tenth the size of a GIF. `--gif` still exists, but only for places that can't play video.
A `FAILED` script usually means Snowsight has changed, so check that step's wording too.

## Add a clip

Build it from the steps in `snowsight.mjs` (open the workspace, open a notebook, create its service, pick dropdown options, paste into Cortex Code). For a per-module variant, copy `scripts/da2_notebook_service.mjs`. Then:

- call `mark()` just before the actions you want to show (everything before it is trimmed);
- use `clickWithHighlight()` so viewers see what's clicked;
- set `crop` to the panel involved, keeping clips small (800 px wide, 10 fps, under 500 KB).

The Cortex Code skill `.cortex/skills/hol-step-clips` walks through recording, checking and publishing a clip.
