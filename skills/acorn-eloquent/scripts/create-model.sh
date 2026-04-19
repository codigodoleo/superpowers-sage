#!/usr/bin/env bash
set -euo pipefail
NAME="${1:?usage: create-model.sh <Name> [--migration]}"
FLAG="${2:-}"
if [[ ! "$NAME" =~ ^[A-Z][A-Za-z0-9]*$ ]]; then
    echo "Name must be PascalCase (e.g. Project)" >&2; exit 1
fi
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2; exit 1
fi
if [[ "$FLAG" == "--migration" ]]; then
    lando acorn make:model "$NAME" --migration
else
    lando acorn make:model "$NAME"
fi
echo "Created: app/Models/${NAME}.php"
[[ "$FLAG" == "--migration" ]] && echo "Migration: database/migrations/$(date +%Y_%m_%d)_*_create_$(echo "$NAME" | tr '[:upper:]' '[:lower:]')s_table.php"
