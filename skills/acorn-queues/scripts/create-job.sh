#!/usr/bin/env bash
set -euo pipefail
NAME="${1:?usage: create-job.sh <JobName>}"
if [[ ! "$NAME" =~ ^[A-Z][A-Za-z0-9]*$ ]]; then
    echo "Name must be PascalCase (e.g. SendWelcomeEmail)" >&2; exit 1
fi
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2; exit 1
fi
lando acorn make:job "$NAME"
echo "Created: app/Jobs/${NAME}.php"
