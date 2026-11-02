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
# Needs: Snowflake CLI 3.26+ (snow) and python3. Node.js is not needed locally -
# the Lab Companion app is built inside Snowflake.
# The connection must use a user with ACCOUNTADMIN.
# =====================================================
set -euo pipefail

CONN="${1:?usage: provision_account.sh <snow-connection-name> [--with-reference-build]}"
REFERENCE_BUILD="${2:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

step() { printf '\n==> %s\n' "$*"; }
run_sql() { snow sql -c "$CONN" -f "$1" > "/tmp/hol_$(basename "$1").log" 2>&1 || { echo "FAILED: $1 (see /tmp/hol_$(basename "$1").log)"; exit 1; }
            if grep -q "─ Error" "/tmp/hol_$(basename "$1").log"; then echo "ERRORS in $1:"; grep -A3 "─ Error" "/tmp/hol_$(basename "$1").log" | head -20; exit 1; fi; }

step "1/6 Roles, database, warehouse, Marketplace knowledge extension"
run_sql setup/00_admin_provision.sql

step "2/6 Synthetic source data"
run_sql setup/01_seed_synthetic_data.sql

step "3/6 Publish sources as Snowflake-managed Iceberg"
run_sql setup/02_publish_iceberg.sql

step "4/6 dbt project (BARCLAYS_HOL.ANALYTICS.BARCLAYS_DBT)"
snow dbt deploy BARCLAYS_DBT --source dbt --database BARCLAYS_HOL --schema ANALYTICS --role HOL_PARTICIPANT -c "$CONN" > /tmp/hol_dbt.log 2>&1 \
  || { echo "FAILED: dbt deploy (see /tmp/hol_dbt.log)"; exit 1; }

if [[ "$REFERENCE_BUILD" == "--with-reference-build" ]]; then
  step "4b Reference build (catch-up scripts, DA1, OPS1)"
  run_sql setup/catchup/core_analytics.sql
  run_sql setup/catchup/semantic_view_and_agent.sql
  run_sql vignettes/da1_semantic_view_analyst/da1.sql
  run_sql vignettes/ops1_payments_360_agent/ops1.sql
fi

step "5/6 Lab Companion prerequisites"
run_sql setup/04_lab_companion.sql

step "6/6 Lab Companion app (built inside Snowflake, ~5 min)"
( cd lab-companion && snow app deploy --connection "$CONN" --role HOL_ADMIN ) > /tmp/hol_app.log 2>&1 \
  || { echo "FAILED: app deploy (see /tmp/hol_app.log)"; exit 1; }
snow sql -c "$CONN" --role HOL_ADMIN -q "GRANT USAGE ON APPLICATION SERVICE BARCLAYS_HOL.LAB.LAB_COMPANION TO ROLE HOL_PARTICIPANT" > /dev/null

URL=$(snow sql -c "$CONN" --role HOL_ADMIN --format json -q "SHOW APPLICATION SERVICES LIKE 'LAB_COMPANION' IN SCHEMA BARCLAYS_HOL.LAB" 2>/dev/null \
      | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['url'])")
printf '\nDone. Lab Companion: https://%s\n' "$URL"
printf 'Attendees: grant HOL_PARTICIPANT to each user (setup/03_add_participants.sql).\n'
