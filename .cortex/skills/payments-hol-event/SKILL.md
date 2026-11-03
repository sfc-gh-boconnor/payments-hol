---
name: payments-hol-event
description: "Create, check, fix and end a DataOps.live event for the Payments Operations hands-on lab (Lab Companion + payments-hol Workspace). Use when the HOL team needs a new lab event, wants to know if attendee accounts are ready, or needs to re-run or decommission an event. Triggers: create HOL event, new payments lab event, set up DataOps event, event accounts ready, decommission event, end event."
---

# Payments HOL: DataOps event

Creates a DataOps.live event that provisions attendee accounts with the full lab: Iceberg sources, HOL roles, dbt project, **Lab Companion** app and the **payments-hol** Workspace. Every action goes through `dataops-integration/hol_event.py` (stdlib Python), which wraps the DataOps admin API with the settings tested on the reference events.

## How the event works (read once)

- **Configure project:** `snowflake/hands-on-lab-drafts/RO-barclays-test` (DataOps GitLab). Each account's pipeline runs *Configure Attendee Account*: platform setup (users, MFA policy, Cortex), then the lab from https://github.com/sfc-gh-boconnor/payments-hol via `setup/provision_account.sh`, then exports `LAB_COMPANION_URL`. *Deploy Workspace* then creates the payments-hol Workspace.
- **Instructions page** (`go.dataops.live/<slug>/instructions`) comes from `dataops-integration/event_instructions.md`. It is stored **per event**, so `create` applies it. It shows the login and two buttons, **Open Lab Companion** and **Open Snowflake**. The page only reads variables from the *Configure Attendee Account* job, and captures them when an account is **allocated** to an attendee.
- There is **no Open Instructions box**, because the project has no Build Homepage job. Don't add that job back.
- A fresh account takes about **15 minutes** to reach `ready`. Most of that is the first Lab Companion build inside Snowflake.

## Prerequisites

1. A DataOps personal access token with `api` scope, from app.dataops.live (**User settings > Access tokens**). The script reads `DATAOPS_TOKEN`, or the macOS keychain item `dataops-token`. To store it without echoing:
   `security add-generic-password -U -s dataops-token -a "$USER" -w`
2. Run from the repo root (the script resolves `event_instructions.md` next to itself).

Check the token works before anything else: `python3 dataops-integration/hol_event.py status test-payments-hol-roconnor`. A 401 error means the token is missing or expired.

## Workflow

### 1. Gather event details

Ask the user, with `ask_user_question`, for:
- **slug**: the URL name (`go.dataops.live/<slug>`). Lowercase and hyphens. It must be new, because creating with an existing slug fails.
- **name**: the display name.
- **pool**: the number of attendee accounts. Expected attendees plus about 10% spare, because a failed account can be rerun but allocations can't be moved.
- **start / end**: UTC, or ISO with an offset.
- Optional: **domains** (allowed attendee email domains, e.g. `barclays.com snowflake.com`), **region** (default `aws_us_west_2`), **build** time (default 24 h before start).

### 2. Dry run and confirm

```bash
python3 dataops-integration/hol_event.py create <slug> --name "<name>" --pool <n> \
  --start <start> --end <end> [--domains ...] [--region ...] --dry-run
```

Show the printed settings and **stop for confirmation**. Creating an event provisions Snowflake accounts, which cost money, and they can't be deleted, only decommissioned.

### 3. Create

Run the same command without `--dry-run`. Add `--wait` if the build time is now, so the script polls until every account is `ready`. The script approves the event too; if approval is refused, tell the user a DataOps admin must approve it.

Give the user the registration link, `https://go.dataops.live/<slug>`.

### 4. Check readiness before attendees register

```bash
python3 dataops-integration/hol_event.py status <slug>
```

Every account should be `ready` with a `LAB_COMPANION_URL`. Don't open registration until they are: an attendee allocated to an unfinished account gets an instructions page with an empty Lab Companion link, and that never refreshes.

If an account is in `error`:
1. Open its `latest_pipeline_url` (shown by `status`) and read the failed job's log. The log ends with the failing setup step and its SQL error.
2. Fix the cause in the lab repo (push to both remotes: `origin` and `public`) or in the DataOps project.
3. `python3 dataops-integration/hol_event.py rerun <slug>`

### 5. On the day

In each account, the facilitator can run `CALL BARCLAYS_HOL.LAB.WAKE_LAB();`, so the Lab Companion is warm before the start. DataOps doesn't pass the event times to the pipeline, so the wake tasks aren't scheduled automatically.

### 6. End the event

```bash
python3 dataops-integration/hol_event.py end <slug>          # shows what will be decommissioned
python3 dataops-integration/hol_event.py end <slug> --yes    # decommissions (irreversible)
```

**Stop for explicit confirmation** before `--yes`. There is no delete endpoint: the script decommissions every account and moves the end and decommission dates to now. The API can return 500 even when decommissioning started. Trust the final status table.

## Other commands

- `instructions <slug>`: re-apply `event_instructions.md` after editing it (it affects new allocations only).
- `rerun <slug>`: re-run the configure pipeline for every live account.

## Stopping points

- After the dry run in step 2: before creating anything.
- Before `end --yes`.

## Output

The event slug and registration URL, the account readiness table (each account's status and Lab Companion URL), and any accounts that need a rerun.
