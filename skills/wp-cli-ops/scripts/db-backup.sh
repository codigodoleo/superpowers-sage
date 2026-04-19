#!/usr/bin/env bash
# Backup the WordPress database via Lando WP-CLI.
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2
    exit 1
fi
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILE="db-backup-${TIMESTAMP}.sql"
lando wp db export "$FILE" --porcelain
echo "Backup written: $FILE"
