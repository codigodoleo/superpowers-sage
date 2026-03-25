#!/usr/bin/env bash
# PreToolUse hook: remind about visual verification before git commit
# Only triggers on Bash tool calls that contain "git commit"

set -uo pipefail

# Source shared hook utilities
HOOK_NAME="pre-commit"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

# Check if this is a git commit command
INPUT="${1:-}"
if ! echo "$INPUT" | grep -q "git commit" 2>/dev/null; then
  hook_info "Skipped: not a git commit command"
  exit 0
fi

hook_info "Detected git commit, checking for active plan"

# Check for active plan
PLANS_DIR="./docs/plans"
if ! hook_require_file "$PLANS_DIR" "Plan directory"; then
  exit 0
fi

for dir in $(ls -1d "${PLANS_DIR}"/*/  2>/dev/null | sort -r); do
  plan_file="${dir}plan.md"
  [ -f "$plan_file" ] || continue

  if grep -q "status: in-progress" "$plan_file" 2>/dev/null; then
    hook_info "Found active plan: ${dir%/}"
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "COMMIT CHECK: Active plan at ${dir%/}. Before committing, verify: have all changed components been visually verified against design reference in assets/?"
  }
}
EOF
    exit 0
  fi
done

hook_warn "No active plan found in $PLANS_DIR"
exit 0
