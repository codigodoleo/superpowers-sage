#!/usr/bin/env bash
# SubagentStop hook: log subagent completion to active plan directory
# Keeps a record of subagent activity for plan tracking

set -uo pipefail

# Source shared hook utilities
HOOK_NAME="post-subagent"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

# Find active plan
PLANS_DIR="./docs/plans"
if ! hook_require_file "$PLANS_DIR" "Plan directory"; then
  hook_warn "No plans directory; skipping subagent activity logging"
  exit 0
fi

for dir in $(ls -1d "${PLANS_DIR}"/*/  2>/dev/null | sort -r); do
  plan_file="${dir}plan.md"
  [ -f "$plan_file" ] || continue

  if grep -q "status: in-progress" "$plan_file" 2>/dev/null; then
    LOG_DIR="${dir}logs"
    mkdir -p "$LOG_DIR" 2>/dev/null || {
      hook_error "Could not create log directory at $LOG_DIR"
      exit 0
    }
    
    TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "$(date)")
    echo "[$TIMESTAMP] Subagent completed" >> "${LOG_DIR}/activity.log"
    hook_info "Subagent activity logged to ${LOG_DIR}/activity.log"
    exit 0
  fi
done

hook_warn "No active plan (status: in-progress) found; subagent activity not logged"
exit 0
