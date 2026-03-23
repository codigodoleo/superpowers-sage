#!/usr/bin/env bash
# PostCompact hook: inject design reference reminder after context compression
# Prevents design drift by anchoring the agent to plan assets on disk

set -uo pipefail

# Find active plan (most recent with status: in-progress)
PLANS_DIR="./docs/plans"
[ -d "$PLANS_DIR" ] || exit 0

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
    break
  fi
done

[ -z "$ACTIVE_PLAN" ] && exit 0

# Build reminder message
ASSETS_MSG=""
if [ "$HAS_ASSETS" = "true" ]; then
  ASSET_COUNT=$(ls -1 "${ACTIVE_PLAN}/assets/"*.png 2>/dev/null | wc -l || echo "0")
  ASSETS_MSG="Design assets available: ${ASSET_COUNT} reference images in ${ACTIVE_PLAN}/assets/. RE-READ section assets before implementing any component."
else
  ASSETS_MSG="No design assets found. Use /designing to capture references or add screenshots manually to ${ACTIVE_PLAN}/assets/."
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
