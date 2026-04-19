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
echo "Created middleware: app/Http/Middleware/${NAME}.php"
echo "Next: register in app/Providers/RouteServiceProvider.php"
