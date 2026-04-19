#!/usr/bin/env bash
# {{DESCRIPTION}}
# Usage: {{SCRIPT_NAME}} <{{REQUIRED_ARG}}>
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2
    exit 1
fi
ARG="${1:?usage: {{SCRIPT_NAME}} <{{REQUIRED_ARG}}>}"
# --- implementation ---
lando {{COMMAND}} "$ARG"
echo "Done: {{SUCCESS_MESSAGE}}"
