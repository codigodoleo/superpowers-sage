#!/usr/bin/env bash
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2; exit 1
fi
lando acorn migrate "${@}"
