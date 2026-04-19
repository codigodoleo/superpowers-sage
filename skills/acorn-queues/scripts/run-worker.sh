#!/usr/bin/env bash
set -euo pipefail
QUEUE="${1:-default}"
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2; exit 1
fi
lando acorn queue:work --queue="$QUEUE" --tries=3 --backoff=60
