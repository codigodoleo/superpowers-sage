#!/usr/bin/env bash
# Installs roots/acorn-ai + wordpress/mcp-adapter in the current Lando project.
# Usage: bash scripts/install-ai-stack.sh [--project-path /path/to/project]
set -e

PROJECT_PATH="$(pwd)"
if [[ "$1" == "--project-path" ]]; then
  PROJECT_PATH="$2"
fi

cd "$PROJECT_PATH"

echo "==> Installing roots/acorn-ai + wordpress/mcp-adapter..."
lando composer require roots/acorn-ai wordpress/mcp-adapter

echo "==> Publishing Acorn AI config..."
lando wp acorn vendor:publish --tag=acorn-ai

echo "==> Done. Next: add ANTHROPIC_API_KEY (or OPENAI_API_KEY) to your .env"
echo "    Then run: node <plugin-path>/scripts/generate-project-mcp.mjs --path ."
