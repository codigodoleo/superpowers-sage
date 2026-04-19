#!/usr/bin/env bash
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2; exit 1
fi
echo "=== Autoload options > 1KB, sorted by size ==="
lando wp db query "SELECT option_name, LENGTH(option_value) AS size_bytes FROM $(lando wp db prefix 2>/dev/null || echo 'wp_')options WHERE autoload='yes' AND LENGTH(option_value) > 1024 ORDER BY size_bytes DESC LIMIT 20 FORMAT TABLE" 2>/dev/null \
    || lando wp db query "SELECT option_name, LENGTH(option_value) AS size_bytes FROM wp_options WHERE autoload='yes' AND LENGTH(option_value) > 1024 ORDER BY size_bytes DESC LIMIT 20" --skip-column-names
