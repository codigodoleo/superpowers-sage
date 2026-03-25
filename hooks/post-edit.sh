#!/usr/bin/env bash
# PostToolUse hook: auto-flush cache and rebuild assets after file edits
# Triggered on Write|Edit tool use in Sage/Acorn projects
# Zero-token automation — pure shell, no LLM involvement

set -uo pipefail

# Source shared hook utilities
HOOK_NAME="post-edit"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

# Check prerequisites
if ! hook_require_file ".lando.yml" "Lando config"; then
  exit 0
fi

if ! hook_require_cmd "lando"; then
  exit 0
fi

# Extract file path from tool result (passed as $ARGUMENTS or stdin)
FILE_PATH=""
if [ -n "${1:-}" ]; then
  # Try to extract file_path from JSON argument
  FILE_PATH=$(echo "$1" | grep -o '"file_path":\s*"[^"]*"' | head -1 | sed 's/"file_path":\s*"//' | sed 's/"$//' 2>/dev/null || true)
fi

# If we couldn't extract the path, check the tool_input
if [ -z "$FILE_PATH" ] && [ -n "${TOOL_INPUT:-}" ]; then
  FILE_PATH=$(echo "$TOOL_INPUT" | grep -o '"file_path":\s*"[^"]*"' | head -1 | sed 's/"file_path":\s*"//' | sed 's/"$//' 2>/dev/null || true)
fi

if [ -z "$FILE_PATH" ]; then
  hook_warn "file_path not found in payload"
  exit 0
fi

# Determine action based on file type
case "$FILE_PATH" in
  *.blade.php|*.php)
    # Check if it's a theme file (not vendor, not WordPress core)
    if echo "$FILE_PATH" | grep -qE '(content/themes|app/|resources/)'; then
      hook_info "Triggering lando flush for PHP file: $FILE_PATH"
      hook_run "lando flush" "lando flush" || true
    else
      hook_warn "Skipping lando flush: file is not in theme/app/resources directory ($FILE_PATH)"
    fi
    ;;
  *.css|*.js|*.ts|*.jsx|*.tsx|vite.config.*)
    if echo "$FILE_PATH" | grep -qE '(content/themes|resources/)'; then
      hook_info "Triggering lando theme-build for asset file: $FILE_PATH"
      hook_run "lando theme-build" "lando theme-build" || true
    else
      hook_warn "Skipping lando theme-build: file is not in theme/resources directory ($FILE_PATH)"
    fi
    ;;
  */composer.json)
    if echo "$FILE_PATH" | grep -qE 'content/themes'; then
      hook_info "Triggering lando theme-composer dump-autoload for: $FILE_PATH"
      hook_run "lando theme-composer dump-autoload" "lando theme-composer dump-autoload" || true
    else
      hook_warn "Skipping lando theme-composer: file is not in theme directory ($FILE_PATH)"
    fi
    ;;
  *)
    hook_warn "File type $FILE_PATH does not match any automation trigger"
    ;;
esac

exit 0
