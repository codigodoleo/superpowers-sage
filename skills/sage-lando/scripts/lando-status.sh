#!/usr/bin/env bash
# Print current Lando project status and Sage theme info.
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2
    exit 1
fi
echo "=== Lando Info ==="
lando info --format=table 2>/dev/null || lando info
echo ""
echo "=== WordPress Version ==="
lando wp core version 2>/dev/null || echo "WP-CLI unavailable"
echo ""
echo "=== Active Theme ==="
lando wp theme list --status=active --format=table 2>/dev/null || echo "WP-CLI unavailable"
