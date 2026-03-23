#!/usr/bin/env bash
# PreToolUse hook: remind about visual verification before git commit
# Only triggers on Bash tool calls that contain "git commit"

set -uo pipefail

# Check if this is a git commit command
INPUT="${1:-}"
if ! echo "$INPUT" | grep -q "git commit" 2>/dev/null; then
  exit 0
fi

# Check for active plan
PLANS_DIR="./docs/plans"
[ -d "$PLANS_DIR" ] || exit 0

for dir in $(ls -1d "${PLANS_DIR}"/*/  2>/dev/null | sort -r); do
  plan_file="${dir}plan.md"
  [ -f "$plan_file" ] || continue

  if grep -q "status: in-progress" "$plan_file" 2>/dev/null; then
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

exit 0
