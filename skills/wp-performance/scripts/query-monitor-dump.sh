#!/usr/bin/env bash
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2; exit 1
fi
URL="${1:-}"
if [[ -z "$URL" ]]; then
    DOMAIN=$(basename "$(pwd)")
    URL="https://${DOMAIN}.lndo.site"
fi
echo "Fetching QM data from: $URL"
lando ssh -c "curl -s '$URL?qm-dump=1' 2>/dev/null" | head -500
