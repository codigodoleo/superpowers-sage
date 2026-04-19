#!/usr/bin/env bash
# Stop hook: optional PHPCS quality gate + session end logging.
# SUPERPOWERS_SAGE_QUALITY_GATE=strict|warn|off (default: warn)

set -uo pipefail

HOOK_NAME="post-stop"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

QUALITY_GATE="${SUPERPOWERS_SAGE_QUALITY_GATE:-warn}"

# --- PHPCS Quality Gate ---
if [ "$QUALITY_GATE" != "off" ] && command -v lando >/dev/null 2>&1; then
  PHPCS_OUTPUT=""
  PHPCS_EXIT=0
  PHPCS_OUTPUT=$(lando phpcs 2>&1) || PHPCS_EXIT=$?

  if [ "$PHPCS_EXIT" -ne 0 ]; then
    if [ "$QUALITY_GATE" = "strict" ]; then
      hook_error "PHPCS gate: errors found (strict mode — blocking)"
      SAFE_OUTPUT="$(echo "$PHPCS_OUTPUT" | head -10 | tr '"' "'" | tr '\n' ' ')"
      printf '{"decision":"block","reason":"PHPCS errors found. Fix before completing: %s"}\n' "$SAFE_OUTPUT"
      exit 2
    else
      hook_warn "PHPCS gate: errors found (warn mode — not blocking)"
    fi
  else
    hook_info "PHPCS gate: clean"
  fi
fi

# --- Session end logging ---
PLANS_DIR="./docs/plans"
if [ ! -d "$PLANS_DIR" ]; then
  hook_warn "No plans directory; skipping session logging"
  exit 0
fi

for dir in $(ls -1d "${PLANS_DIR}"/*/ 2>/dev/null | sort -r); do
  plan_file="${dir}plan.md"
  [ -f "$plan_file" ] || continue

  if grep -q "status: in-progress" "$plan_file" 2>/dev/null; then
    LOG_DIR="${dir}logs"
    mkdir -p "$LOG_DIR" 2>/dev/null || {
      hook_error "Could not create log directory at $LOG_DIR"
      exit 0
    }

    TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "$(date)")
    echo "[$TIMESTAMP] Session ended" >> "${LOG_DIR}/activity.log"
    hook_info "Session end logged to ${LOG_DIR}/activity.log"
    exit 0
  fi
done

hook_warn "No active plan (status: in-progress) found; session not logged"
exit 0
