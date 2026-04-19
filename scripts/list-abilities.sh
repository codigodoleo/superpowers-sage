#!/usr/bin/env bash
# Lists registered Abilities via the WP MCP Adapter
# Usage: bash scripts/list-abilities.sh [--project-path /path/to/project]
set -e

PROJECT_PATH="$(pwd)"
if [[ "$1" == "--project-path" ]]; then
  PROJECT_PATH="$2"
fi

cd "$PROJECT_PATH"
echo "==> Registered MCP servers:"
lando wp mcp-adapter list
echo ""
echo "==> To discover abilities in Claude Code, use the 'discover-abilities' MCP tool."
