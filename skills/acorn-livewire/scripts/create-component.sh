#!/usr/bin/env bash
set -euo pipefail
NAME="${1:?usage: create-component.sh <ComponentName>}"
if [[ ! "$NAME" =~ ^[A-Z][A-Za-z0-9]*$ ]]; then
    echo "Name must be PascalCase (e.g. ContactForm)" >&2; exit 1
fi
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2; exit 1
fi
lando acorn make:livewire "$NAME"
SLUG=$(echo "$NAME" | sed 's/\([A-Z]\)/-\1/g' | sed 's/^-//' | tr '[:upper:]' '[:lower:]')
echo "Created: app/Livewire/${NAME}.php"
echo "View:    resources/views/livewire/${SLUG}.blade.php"
