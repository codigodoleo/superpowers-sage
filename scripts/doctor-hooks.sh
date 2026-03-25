#!/usr/bin/env bash
# Hook diagnostics and troubleshooting script for superpowers-sage
# Usage: scripts/doctor-hooks.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOOKS_DIR="${ROOT_DIR}/hooks"

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Superpowers Sage Hooks Diagnostics ===${NC}\n"

# 1. Check Lando setup
echo -e "${BLUE}1. Checking Lando environment${NC}"
if [ -f ".lando.yml" ]; then
  echo -e "${GREEN}✓ .lando.yml found${NC}"
else
  echo -e "${YELLOW}⚠ .lando.yml not found in project root${NC}"
fi

if command -v lando >/dev/null 2>&1; then
  LANDO_VERSION=$(lando --version 2>/dev/null || echo "unknown")
  echo -e "${GREEN}✓ lando installed: $LANDO_VERSION${NC}"
else
  echo -e "${RED}✗ lando not found in PATH${NC}"
fi

echo ""

# 2. Check required tools
echo -e "${BLUE}2. Checking required tools${NC}"
for cmd in node bash sed grep; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ $cmd available${NC}"
  else
    echo -e "${RED}✗ $cmd not found${NC}"
  fi
done

echo ""

# 3. Check hook scripts
echo -e "${BLUE}3. Checking hook scripts${NC}"
hooks=("session-start.sh" "post-edit.sh" "pre-commit.sh" "post-compact.sh" "post-stop.sh" "post-subagent.sh" "lib.sh")

for hook in "${hooks[@]}"; do
  hook_file="${HOOKS_DIR}/${hook}"
  if [ -f "$hook_file" ]; then
    if [ -x "$hook_file" ]; then
      echo -e "${GREEN}✓ $hook (executable)${NC}"
    else
      echo -e "${YELLOW}⚠ $hook exists but not executable${NC}"
      echo "  Run: chmod +x $hook_file"
    fi
  else
    echo -e "${RED}✗ $hook not found${NC}"
  fi
done

echo ""

# 4. Check hooks manifest
echo -e "${BLUE}4. Checking hook manifests${NC}"
for manifest in "hooks.json" "cursor-hooks.json"; do
  manifest_file="${HOOKS_DIR}/${manifest}"
  if [ -f "$manifest_file" ]; then
    echo -e "${GREEN}✓ $manifest found${NC}"
    # Try to validate JSON
    if command -v node >/dev/null 2>&1; then
      if node -e "require('$manifest_file')" 2>/dev/null; then
        echo -e "${GREEN}  → Valid JSON${NC}"
      else
        echo -e "${RED}  → Invalid JSON syntax${NC}"
      fi
    fi
  else
    echo -e "${YELLOW}⚠ $manifest not found${NC}"
  fi
done

echo ""

# 5. Check plan structure
echo -e "${BLUE}5. Checking plan structure${NC}"
if [ -d "./docs/plans" ]; then
  PLAN_COUNT=$(ls -1d "./docs/plans"/*/ 2>/dev/null | wc -l || echo "0")
  echo -e "${GREEN}✓ docs/plans directory found ($PLAN_COUNT plans)${NC}"
  
  # Check for in-progress plan
  ACTIVE=$(find "./docs/plans" -name "plan.md" -type f -exec grep -l "status: in-progress" {} \; 2>/dev/null | head -1)
  if [ -n "$ACTIVE" ]; then
    PLAN_DIR=$(dirname "$ACTIVE")
    echo -e "${GREEN}✓ Active plan found: $PLAN_DIR${NC}"
    
    if [ -d "${PLAN_DIR}/assets" ]; then
      ASSET_COUNT=$(ls -1 "${PLAN_DIR}/assets"/*.png 2>/dev/null | wc -l || echo "0")
      echo -e "${GREEN}  → Assets: $ASSET_COUNT PNG files${NC}"
    else
      echo -e "${YELLOW}  ⚠ No assets directory in active plan${NC}"
    fi
  else
    echo -e "${YELLOW}⚠ No active plan (status: in-progress) found${NC}"
  fi
else
  echo -e "${YELLOW}⚠ docs/plans directory not found${NC}"
fi

echo ""

# 6. Check hook logging configuration
echo -e "${BLUE}6. Hook logging configuration${NC}"
if [ "${SUPERPOWERS_SAGE_HOOK_DEBUG:-0}" = "1" ]; then
  echo -e "${GREEN}✓ Hook debug enabled (SUPERPOWERS_SAGE_HOOK_DEBUG=1)${NC}"
else
  echo -e "${YELLOW}⚠ Hook debug disabled${NC}"
  echo "  Enable with: export SUPERPOWERS_SAGE_HOOK_DEBUG=1"
fi

LOG_FILE="${SUPERPOWERS_SAGE_HOOK_LOG:-.superpowers-sage/hooks.log}"
echo -e "  Log file: $LOG_FILE"
if [ -f "$LOG_FILE" ]; then
  LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
  echo -e "${GREEN}  → $LINES log entries${NC}"
  echo -e "${YELLOW}  Recent entries:${NC}"
  tail -5 "$LOG_FILE" | sed 's/^/    /'
else
  echo -e "${YELLOW}  → No log file yet (logs appear after hook execution)${NC}"
fi

echo ""

# 7. Test hook simulation
echo -e "${BLUE}7. Hook simulation${NC}"
echo "To manually test hooks, you can:"
echo ""
echo "  post-edit hook:"
echo "    TOOL_INPUT='{\"file_path\": \"resources/css/app.css\"}' bash hooks/post-edit.sh"
echo ""
echo "  pre-commit hook:"
echo "    bash hooks/pre-commit.sh 'git commit -m test'"
echo ""
echo "  post-compact hook:"
echo "    bash hooks/post-compact.sh"
echo ""

# 8. Common warnings reference
echo -e "${BLUE}8. Common warnings and troubleshooting${NC}"
echo ""
echo -e "${YELLOW}If you see: 'skip: lando CLI not found in PATH'${NC}"
echo "  → Lando is not installed or not in your PATH"
echo "  → Fix: brew install lando (or platform-specific installer)"
echo ""
echo -e "${YELLOW}If you see: 'skip: file_path not found in payload'${NC}"
echo "  → Post-edit hook couldn't extract the edited file path"
echo "  → This is expected for non-file actions"
echo ""
echo -e "${YELLOW}If you see: 'skip: no active plan (status: in-progress) found'${NC}"
echo "  → No plan with 'status: in-progress' exists in docs/plans/"
echo "  → Fix: Create a plan with /architecture-discovery then /plan-generator, or run /building with an existing plan"
echo ""
echo -e "${YELLOW}If you see: 'skip: .lando.yml not found' (in post-edit)${NC}"
echo "  → Project is not a Lando project or .lando.yml is misconfigured"
echo "  → post-edit automation only runs in Lando projects"
echo ""

echo -e "${BLUE}=== Diagnostics complete ===${NC}"
echo ""
echo "For detailed help, see README.md section 'Hook warnings and diagnostico rapido' or run:"
echo "  export SUPERPOWERS_SAGE_HOOK_DEBUG=1"
echo "  export SUPERPOWERS_SAGE_HOOK_LOG=.superpowers-sage/hooks.log"
echo ""
echo "Then reproduce the action (edit file / commit / etc) and inspect the log."
