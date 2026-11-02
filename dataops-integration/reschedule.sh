#!/usr/bin/env bash
# Re-run only the wake schedule on an already provisioned account. See README.md.
set -euo pipefail

CONN="${1:?usage: reschedule.sh <snow-connection-name>}"
LAB_START="${LAB_START:-${EVENT_START_DATETIME:?EVENT_START_DATETIME or LAB_START not set}}"
LAB_END="${LAB_END:-${EVENT_END_DATETIME:?EVENT_END_DATETIME or LAB_END not set}}"
LEAD="${LAB_WAKE_LEAD_MINUTES:-30}"

[[ "$LEAD" =~ ^[0-9]+$ ]] || { echo "LAB_WAKE_LEAD_MINUTES must be a whole number"; exit 1; }
for t in "$LAB_START" "$LAB_END"; do
  [[ "$t" =~ ^[0-9TZ:.+\ -]+$ ]] || { echo "Invalid lab time: '$t' (expected e.g. 2026-12-01 09:30:00 +00:00)"; exit 1; }
done

snow sql -c "$CONN" --role HOL_ADMIN -D "lab_start=$LAB_START" -D "lab_end=$LAB_END" \
  -q "CALL BARCLAYS_HOL.LAB.SCHEDULE_LAB(TRY_TO_TIMESTAMP_TZ('<% lab_start %>'), TRY_TO_TIMESTAMP_TZ('<% lab_end %>'), $LEAD)"
