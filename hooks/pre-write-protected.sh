#!/usr/bin/env bash
# PreToolUse hook: block writes/edits to protected Bedrock/Trellis files.
# Output: {"decision":"block","reason":"..."} + exit 2 for protected paths.

set -uo pipefail

HOOK_NAME="pre-write-protected"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

INPUT="$(cat)"

# Extract file_path from nested tool_input object
FILE_PATH="$(echo "$INPUT" | grep -o '"file_path":[[:space:]]*"[^"]*"' | head -1 \
  | sed 's/"file_path":[[:space:]]*"//' | sed 's/"$//')"

[ -z "$FILE_PATH" ] && exit 0

BASENAME="$(basename "$FILE_PATH")"

is_protected() {
  local path="$1"
  local base="$2"

  # .env.example is explicitly allowed
  [ "$base" = ".env.example" ] && return 1

  # .env (exact) or .env.* (dotenv variants)
  [[ "$base" = ".env" || "$base" = .env.* ]] && return 0

  # wp-config.php
  [ "$base" = "wp-config.php" ] && return 0

  # bedrock/config/environments/*.php
  echo "$path" | grep -qE 'bedrock/config/environments/[^/]+\.php$' && return 0

  # trellis/group_vars/*/vault.yml
  echo "$path" | grep -qE 'trellis/group_vars/[^/]+/vault\.yml$' && return 0

  return 1
}

if is_protected "$FILE_PATH" "$BASENAME"; then
  REASON="Protected file: ${FILE_PATH}. Use ansible-vault edit or the Bedrock .env pattern instead."
  printf '{"decision":"block","reason":"%s"}\n' "$REASON"
  hook_info "Blocked write to protected file: $FILE_PATH"
  exit 2
fi

exit 0
