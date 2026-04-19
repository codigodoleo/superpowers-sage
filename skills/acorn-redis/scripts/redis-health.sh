#!/usr/bin/env bash
# Check Redis health in the current Lando project.
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2
    exit 1
fi
echo "=== Redis PING ==="
lando redis-cli ping
echo "=== Object Cache Status ==="
lando wp cache type 2>/dev/null || echo "WP-CLI unavailable"
echo "=== Memory Usage ==="
lando redis-cli info memory | grep used_memory_human
