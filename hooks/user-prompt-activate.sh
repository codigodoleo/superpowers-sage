#!/usr/bin/env bash
# UserPromptSubmit hook: inject skill context when prompt matches exactly one skill keyword.
# Output: {"additionalContext":"..."} for a unique match. Silent on no-match or multi-match.

set -uo pipefail

HOOK_NAME="user-prompt-activate"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

INPUT="$(cat)"

# Extract prompt field — graceful on malformed JSON
PROMPT="$(echo "$INPUT" | grep -o '"prompt":[[:space:]]*"[^"]*"' | head -1 \
  | sed 's/"prompt":[[:space:]]*"//' | sed 's/"$//')" || PROMPT=""

[ -z "$PROMPT" ] && exit 0

PROMPT_LOWER="$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')"

# Format: "keyword1|keyword2:skill-name"
KEYWORD_MAP=(
  "livewire|livewire component|livewire-new:acorn-livewire"
  "eloquent|model class|database schema|migration:acorn-eloquent"
  "gutenberg block|register block|block.json|block scaffold|scaffold:block-scaffolding"
  "lando|lando start|lando stop|lando restart:sage-lando"
  "queue|dispatch job|action scheduler|horizon:acorn-queues"
  "middleware|http kernel|acorn middleware:acorn-middleware"
  "redis|cache tags|cache driver:acorn-redis"
  "log channel|monolog|logging config:acorn-logging"
  "acorn route|routes/web|register route:acorn-routes"
  "phpcs|php codesniffer|phpstan:wp-phpstan"
  "rest api|wp_rest|rest endpoint:wp-rest-api"
  "design token|@theme block|tailwind token:sage-design-system"
  "block refactor|block evolution|block migration:block-refactoring"
  "ai-setup|acorn ai|mcp adapter|discover-abilities|install mcp:ai-setup"
  "abilities|make:ability|abilities-authoring|execute-ability|acorn ability|mcp endpoint|wp ability:abilities-authoring"
)

MATCHED_SKILL=""
MATCH_COUNT=0

for entry in "${KEYWORD_MAP[@]}"; do
  keywords="${entry%%:*}"
  skill="${entry##*:}"
  IFS='|' read -ra kw_list <<< "$keywords"
  for kw in "${kw_list[@]}"; do
    if echo "$PROMPT_LOWER" | grep -qF "$kw" 2>/dev/null; then
      if [ "$MATCHED_SKILL" != "$skill" ]; then
        MATCHED_SKILL="$skill"
        MATCH_COUNT=$((MATCH_COUNT + 1))
      fi
      break
    fi
  done
done

if [ "$MATCH_COUNT" -ne 1 ]; then
  hook_info "Skill activation: $MATCH_COUNT match(es) — no injection"
  exit 0
fi

hook_info "Skill activation: injecting $MATCHED_SKILL"
printf '{"additionalContext":"Skill hint: %s skill is relevant. Invoke it if not already active."}\n' "$MATCHED_SKILL"
exit 0
