#!/usr/bin/env bash
# Standard Lando availability check — paste at top of every skill script.
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH — run this from inside a Lando project" >&2
    exit 1
fi
