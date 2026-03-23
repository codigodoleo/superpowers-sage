#!/usr/bin/env bash
# Stop hook: log session end to active plan directory
# Records when a conversation ends for plan tracking

set -uo pipefail

# Find active plan
PLANS_DIR="./docs/plans"
[ -d "$PLANS_DIR" ] || exit 0

for dir in $(ls -1d "${PLANS_DIR}"/*/ 2>/dev/null | sort -r); do
  plan_file="${dir}plan.md"
  [ -f "$plan_file" ] || continue

  if grep -q "status: in-progress" "$plan_file" 2>/dev/null; then
    LOG_DIR="${dir}logs"
    mkdir -p "$LOG_DIR"
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] Session ended" >> "${LOG_DIR}/activity.log"
    exit 0
  fi
done

exit 0
