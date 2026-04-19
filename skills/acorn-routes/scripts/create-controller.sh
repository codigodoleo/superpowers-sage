#!/usr/bin/env bash
set -euo pipefail
NAME="${1:?usage: create-controller.sh <Name> [--resource|--api|--invokable]}"
FLAG="${2:-}"
if [[ ! "$NAME" =~ ^[A-Z][A-Za-z0-9]*$ ]]; then
    echo "Name must be PascalCase (e.g. HomeController)" >&2; exit 1
fi
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2; exit 1
fi
case "$FLAG" in
    --resource)  lando acorn make:controller "$NAME" --resource ;;
    --api)       lando acorn make:controller "$NAME" --api ;;
    --invokable) lando acorn make:controller "$NAME" --invokable ;;
    *)           lando acorn make:controller "$NAME" ;;
esac
echo "Created: app/Http/Controllers/${NAME}.php"
echo "Next: add route in routes/web.php"
