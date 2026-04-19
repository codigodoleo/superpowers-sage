#!/usr/bin/env bash
# Verify Sage/Acorn/Lando stack versions.
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2
    exit 1
fi
echo "PHP:      $(lando php --version 2>/dev/null | head -1 || echo 'N/A')"
echo "WP:       $(lando wp core version 2>/dev/null || echo 'N/A')"
echo "Acorn:    $(lando theme-composer show roots/acorn 2>/dev/null | grep 'versions' | head -1 || echo 'not installed')"
echo "Composer: $(lando composer --version 2>/dev/null | head -1 || echo 'N/A')"
echo "Node:     $(lando node --version 2>/dev/null || echo 'N/A')"
