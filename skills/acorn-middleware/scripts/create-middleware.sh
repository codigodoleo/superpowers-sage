#!/usr/bin/env bash
# Create a new Acorn middleware via Lando.
# Usage: create-middleware.sh <Name> [--type=auth|filter]

set -euo pipefail

NAME="${1:?usage: create-middleware.sh <Name> [--type=auth|filter]}"
TYPE="filter"
for arg in "$@"; do
    case "$arg" in
        --type=*) TYPE="${arg#*=}" ;;
    esac
done

if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2
    exit 1
fi

lando acorn make:middleware "$NAME"

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET="app/Http/Middleware/${NAME}.php"

case "$TYPE" in
    auth)
        TPL="$PLUGIN_ROOT/skills/acorn-middleware/assets/middleware-auth.php.tpl"
        ;;
    filter|*)
        TPL="$PLUGIN_ROOT/skills/acorn-middleware/assets/middleware-filter.php.tpl"
        ;;
esac

if [ -f "$TPL" ] && [ -f "$TARGET" ]; then
    sed "s/{{CLASS_NAME}}/$NAME/g" "$TPL" > "$TARGET"
    echo "Applied ${TYPE} template to ${TARGET}"
fi

echo "Created middleware: ${TARGET}"
echo "Next: register in app/Http/Kernel.php (middleware groups or route middleware aliases)"
