#!/usr/bin/env bash
# Search-replace across WordPress DB with dry-run guard.
# Usage: search-replace.sh <from> <to> [--live]
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2
    exit 1
fi
FROM="${1:?usage: search-replace.sh <from> <to> [--live]}"
TO="${2:?usage: search-replace.sh <from> <to> [--live]}"
LIVE="${3:-}"
if [[ "$LIVE" != "--live" ]]; then
    echo "DRY RUN (pass --live to apply):"
    lando wp search-replace "$FROM" "$TO" --precise --dry-run --report-changed-only
else
    lando wp search-replace "$FROM" "$TO" --precise --report-changed-only
fi
