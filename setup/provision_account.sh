#!/usr/bin/env bash
# =====================================================
# BARCLAYS PAYMENTS HOL v2 - PROVISION ONE TRIAL ACCOUNT
#
# Run from a clone of this GitHub repo, once per trial account, before the event:
#   ./setup/provision_account.sh <snow-connection-name> [--with-reference-build]
#
#   --with-reference-build  also pre-builds the analytics layer, semantic views and
#                           agents (use for the Payments Ops pathway or demos)
#
# Optional wake schedule (step 7): set LAB_START and LAB_END (any timestamp with an
# offset, e.g. '2026-12-01 09:30:00 +00:00'), or the DataOps EVENT_START_DATETIME /
# EVENT_END_DATETIME. LAB_WAKE_LEAD_MINUTES defaults to 30.
#
# Needs: Snowflake CLI 3.26+ (snow). The lab data loads inside Snowflake from the
# lab's public GitHub repo (LAB.LOAD_LAB_DATA), so nothing is uploaded from here. Node.js is not needed locally -
# the Lab Companion app is built inside Snowflake.
# The connection must use a user with ACCOUNTADMIN.
# =====================================================
set -euo pipefail

CONN="${1:?usage: provision_account.sh <snow-connection-name> [--with-reference-build]}"
REFERENCE_BUILD="${2:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

step() { printf '\n==> %s\n' "$*"; }
run_sql() { snow sql -c "$CONN" -f "$1" > "/tmp/hol_$(basename "$1").log" 2>&1 || { echo "FAILED: $1"; tail -25 "/tmp/hol_$(basename "$1").log"; exit 1; }
            if grep -q "─ Error" "/tmp/hol_$(basename "$1").log"; then echo "ERRORS in $1:"; grep -A3 "─ Error" "/tmp/hol_$(basename "$1").log" | head -20; exit 1; fi; }
# Like run_sql, but returns non-zero instead of stopping the script
try_sql() { snow sql -c "$CONN" -f "$1" > "/tmp/hol_$(basename "$1").log" 2>&1 && ! grep -q "─ Error" "/tmp/hol_$(basename "$1").log"; }

step "1/7 Roles, database, warehouse, compute pools, Marketplace knowledge extension"
run_sql setup/00_admin_provision.sql

step "2/7 Connect the lab Git repository (the data loader reads it)"
run_sql setup/git_repo.sql

step "3/7 Load every lab data set inside Snowflake (LAB.LOAD_LAB_DATA, ~2-3 min)"
# One CALL instead of an upload and a script per data set: the procedure copies the
# committed data from the Git repository and runs the seed scripts in Snowflake.
run_sql setup/11_lab_data_loader.sql
SEARCH_FLAG=$([[ "${HOL_ENABLE_SEARCH:-1}" == "1" ]] && echo TRUE || echo FALSE)
[[ "$SEARCH_FLAG" == "FALSE" ]] && echo "  Cortex Search lab off (HOL_ENABLE_SEARCH=0): AI5 will show as skippable"
snow sql -c "$CONN" --role HOL_ADMIN -q "USE WAREHOUSE BARCLAYS_WH; CALL BARCLAYS_HOL.LAB.LOAD_LAB_DATA('ALL', $SEARCH_FLAG)" > /tmp/hol_load_lab_data.log 2>&1 \
  && ! grep -q "─ Error" /tmp/hol_load_lab_data.log \
  || { echo "FAILED: LOAD_LAB_DATA (see /tmp/hol_load_lab_data.log; failing step in BARCLAYS_HOL.LAB.DATA_LOAD_LOG)"; grep -A8 "─ Error" /tmp/hol_load_lab_data.log | head -12; exit 1; }
grep -o "Loaded ALL lab data[^|]*" /tmp/hol_load_lab_data.log || true

step "3b Executive demo (its own BARCLAYS_DEMO database, cloned from the lab data, ~5 min)"
snow sql -c "$CONN" --role HOL_ADMIN -q "USE WAREHOUSE BARCLAYS_WH; CALL BARCLAYS_HOL.LAB.LOAD_LAB_DATA('DEMO', $SEARCH_FLAG)" > /tmp/hol_load_demo.log 2>&1 \
  && ! grep -q "─ Error" /tmp/hol_load_demo.log \
  || { echo "FAILED: executive demo (see /tmp/hol_load_demo.log; failing step in BARCLAYS_HOL.LAB.DATA_LOAD_LOG)"; grep -A8 "─ Error" /tmp/hol_load_demo.log | head -12; exit 1; }
grep -o "Loaded DEMO lab data[^|]*" /tmp/hol_load_demo.log || true

step "4/7 dbt project, audit pack and CoWork agent (one session, from the Git repository)"
REPO="@BARCLAYS_HOL_SETUP.PUBLIC.HOL_REPO/branches/main"
cat > /tmp/hol_lab_objects.sql <<SQL
EXECUTE IMMEDIATE FROM $REPO/setup/06_audit_pack.sql;
EXECUTE IMMEDIATE FROM $REPO/setup/09_cowork_pack.sql;
USE ROLE HOL_PARTICIPANT;
USE WAREHOUSE BARCLAYS_WH;
CREATE OR REPLACE DBT PROJECT BARCLAYS_HOL.ANALYTICS.BARCLAYS_DBT FROM '$REPO/dbt' COMMENT = 'Barclays Payments HOL dbt project';
SQL
run_sql /tmp/hol_lab_objects.sql

if [[ "$REFERENCE_BUILD" == "--with-reference-build" ]]; then
  step "4b Reference build (catch-up scripts, DA1, OPS1)"
  run_sql setup/catchup/core_analytics.sql
  run_sql setup/catchup/semantic_view_and_agent.sql
  run_sql vignettes/da1_semantic_view_analyst/da1.sql
  run_sql vignettes/ops1_payments_360_agent/ops1.sql
fi

step "5/7 Lab Companion prerequisites"
run_sql setup/04_lab_companion.sql

step "6/7 Lab Companion app (built inside Snowflake, ~5 min)"
bash "$ROOT/setup/install_lab_companion.sh" "$CONN" | tee /tmp/hol_companion_url.log

step "7/7 Wake schedule (WAKE_LAB / SLEEP_LAB / SCHEDULE_LAB)"
run_sql setup/05_wake_schedule.sql
LAB_START="${LAB_START:-${EVENT_START_DATETIME:-}}"
LAB_END="${LAB_END:-${EVENT_END_DATETIME:-}}"
LEAD="${LAB_WAKE_LEAD_MINUTES:-30}"
if [[ -n "$LAB_START" && -n "$LAB_END" ]]; then
  [[ "$LEAD" =~ ^[0-9]+$ ]] || { echo "LAB_WAKE_LEAD_MINUTES must be a whole number"; exit 1; }
  for t in "$LAB_START" "$LAB_END"; do
    [[ "$t" =~ ^[0-9TZ:.+\ -]+$ ]] || { echo "Invalid lab time: '$t' (expected e.g. 2026-12-01 09:30:00 +00:00)"; exit 1; }
  done
  snow sql -c "$CONN" --role HOL_ADMIN -D "lab_start=$LAB_START" -D "lab_end=$LAB_END" \
    -q "CALL BARCLAYS_HOL.LAB.SCHEDULE_LAB(TRY_TO_TIMESTAMP_TZ('<% lab_start %>'), TRY_TO_TIMESTAMP_TZ('<% lab_end %>'), $LEAD)" \
    > /tmp/hol_schedule.log 2>&1 || { echo "FAILED: SCHEDULE_LAB (see /tmp/hol_schedule.log)"; exit 1; }
  grep -o "Wake .* UTC" /tmp/hol_schedule.log || cat /tmp/hol_schedule.log
else
  echo "No LAB_START/LAB_END set: wake tasks not scheduled. On the day: CALL BARCLAYS_HOL.LAB.WAKE_LAB();"
fi

printf '\nDone. %s\n' "$(grep 'Lab Companion:' /tmp/hol_companion_url.log)"
printf 'Attendees: grant HOL_PARTICIPANT to each user (setup/03_add_participants.sql).\n'
