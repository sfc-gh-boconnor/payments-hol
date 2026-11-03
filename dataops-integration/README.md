# DataOps integration

When the hands-on lab team provisions trial accounts through DataOps, each
account's configure pipeline can run this repo's provisioning and schedule the
Lab Companion to wake up before the event.

## What the pipeline runs

```bash
./dataops-integration/configure_account.sh <snow-connection-name>
```

This calls `setup/provision_account.sh` with the DataOps event times:

| DataOps variable | Used as | Example |
|---|---|---|
| `EVENT_START_DATETIME` | `LAB_START` | `2026-12-01 09:30:00 +00:00` |
| `EVENT_END_DATETIME` | `LAB_END` | `2026-12-01 13:30:00 +00:00` |
| `LAB_WAKE_LEAD_MINUTES` (optional) | minutes before start to wake the app | `30` |
| `REFERENCE_BUILD` (optional) | `true` adds `--with-reference-build` | `true` |

Times need an explicit UTC offset; the schedule is computed in UTC.

## Rescheduling an account

If the event moves after provisioning, only the schedule needs re-running:

```bash
EVENT_START_DATETIME='2026-12-02 09:30:00 +00:00' \
EVENT_END_DATETIME='2026-12-02 13:30:00 +00:00' \
./dataops-integration/reschedule.sh <snow-connection-name>
```

## On the day

The tasks `BARCLAYS_HOL.LAB.LAB_WAKE_TASK` and `LAB_SLEEP_TASK` run once each.
Manual override: `CALL BARCLAYS_HOL.LAB.WAKE_LAB();`

## Event instructions page

[`event_instructions.md`](event_instructions.md) is the attendee instructions template. It has two buttons, **Open Lab Companion** (`{{vars.LAB_COMPANION_URL}}`) and **Open Snowflake**, each opening in its own tab. Apply it to an event with the admin API:

```bash
curl -X PATCH -H "Authorization: Bearer $DATAOPS_TOKEN" -H "Content-Type: application/json" \
  -d "$(python3 -c "import json; print(json.dumps({'instructions': open('dataops-integration/event_instructions.md').read()}))")" \
  https://admin.dataops.live/api/v1/event_management/<event-slug>
```

The page only reads variables from the **Configure Attendee Account** job's dotenv, so the HOL v2 install (which exports `LAB_COMPANION_URL`) runs inside that job.
