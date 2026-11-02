#!/usr/bin/env bash
# =====================================================
# BARCLAYS PAYMENTS HOL v2 - INSTALL THE LAB COMPANION
#
# Builds and deploys the Lab Companion (React app on Snowflake App Runtime),
# shares it with attendees and prints its URL. Run after the lab objects
# exist (INSTALL.sql, or steps 1-5 of provision_account.sh):
#   ./setup/install_lab_companion.sh <snow-connection-name>
#
# Needs: Snowflake CLI 3.26+ (snow) and python3; Node.js is not needed locally -
# the app is built inside Snowflake. The connection must use a user with
# ACCOUNTADMIN, and the account must support Snowflake App Runtime.
# =====================================================
set -euo pipefail

CONN="${1:?usage: install_lab_companion.sh <snow-connection-name>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Building and deploying the Lab Companion inside Snowflake (~5 min)..."
( cd "$ROOT/lab-companion" && snow app deploy --connection "$CONN" --role HOL_ADMIN ) > /tmp/hol_app.log 2>&1 || {
  echo "FAILED: Lab Companion deploy (see /tmp/hol_app.log)."
  echo "If the log mentions App Runtime not being available, this account does not support it."
  exit 1
}
snow sql -c "$CONN" --role HOL_ADMIN -q "GRANT USAGE ON APPLICATION SERVICE BARCLAYS_HOL.LAB.LAB_COMPANION TO ROLE HOL_PARTICIPANT" > /dev/null

URL=$(snow sql -c "$CONN" --role HOL_ADMIN --format json -q "SHOW APPLICATION SERVICES LIKE 'LAB_COMPANION' IN SCHEMA BARCLAYS_HOL.LAB" 2>/dev/null \
      | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['url'])")
printf 'Lab Companion: https://%s\n' "$URL"
