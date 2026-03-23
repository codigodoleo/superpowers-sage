#!/usr/bin/env bash
# PostToolUse hook: auto-flush cache and rebuild assets after file edits
# Triggered on Write|Edit tool use in Sage/Acorn projects
# Zero-token automation — pure shell, no LLM involvement

set -uo pipefail

# Only run if we're in a Lando project
[ -f ".lando.yml" ] || exit 0

# Check if lando CLI is available
command -v lando >/dev/null 2>&1 || exit 0

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

[ -z "$FILE_PATH" ] && exit 0

# Determine action based on file type
case "$FILE_PATH" in
  *.blade.php|*.php)
    # Check if it's a theme file (not vendor, not WordPress core)
    if echo "$FILE_PATH" | grep -qE '(content/themes|app/|resources/)'; then
      lando flush 2>/dev/null || true
    fi
    ;;
  *.css|*.js|*.ts|*.jsx|*.tsx|vite.config.*)
    if echo "$FILE_PATH" | grep -qE '(content/themes|resources/)'; then
      lando theme-build 2>/dev/null || true
    fi
    ;;
  */composer.json)
    if echo "$FILE_PATH" | grep -qE 'content/themes'; then
      lando theme-composer dump-autoload 2>/dev/null || true
    fi
    ;;
esac

exit 0
