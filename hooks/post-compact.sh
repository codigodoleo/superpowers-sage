#!/usr/bin/env bash
# PostCompact hook: inject design reference reminder after context compression
# Prevents design drift by anchoring the agent to plan assets on disk

set -uo pipefail

# Source shared hook utilities
HOOK_NAME="post-compact"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

# Find active plan (most recent with status: in-progress)
PLANS_DIR="./docs/plans"
if ! hook_require_file "$PLANS_DIR" "Plan directory"; then
  hook_warn "No plans directory found; skipping post-compact injection"
  exit 0
fi

ACTIVE_PLAN=""
PLAN_TITLE=""
HAS_ASSETS="false"

# Iterate plan directories in reverse chronological order
for dir in $(ls -1d "${PLANS_DIR}"/*/  2>/dev/null | sort -r); do
  plan_file="${dir}plan.md"
  [ -f "$plan_file" ] || continue

  if grep -q "status: in-progress" "$plan_file" 2>/dev/null; then
    ACTIVE_PLAN="${dir%/}"
    PLAN_TITLE=$(grep -m1 "^title:" "$plan_file" | sed 's/^title:\s*//' | sed 's/^"//' | sed 's/"$//' 2>/dev/null || echo "Unknown")
    [ -d "${dir}assets" ] && HAS_ASSETS="true"
    hook_info "Found active plan: $ACTIVE_PLAN ($PLAN_TITLE)"
    break
  fi
done

if [ -z "$ACTIVE_PLAN" ]; then
  hook_warn "No active plan (status: in-progress) found"
  exit 0
fi

# Build reminder message
ASSETS_MSG=""
if [ "$HAS_ASSETS" = "true" ]; then
  ASSET_COUNT=$(ls -1 "${ACTIVE_PLAN}/assets/"*.png 2>/dev/null | wc -l || echo "0")
  ASSETS_MSG="Design assets available: ${ASSET_COUNT} reference images in ${ACTIVE_PLAN}/assets/. RE-READ section assets before implementing any component."
  hook_info "Found $ASSET_COUNT design assets in plan"
else
  ASSETS_MSG="No design assets found. Use /designing to capture references or add screenshots manually to ${ACTIVE_PLAN}/assets/."
  hook_warn "No design assets found in plan directory"
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostCompact",
    "additionalContext": "ACTIVE PLAN: ${ACTIVE_PLAN}/plan.md (${PLAN_TITLE}). ${ASSETS_MSG}"
  }
}
EOF

exit 0
