#!/usr/bin/env bash
# Create a new Acorn CLI command via Lando.
# Usage: create-command.sh <CommandName>
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2
    exit 1
fi
NAME="${1:?usage: create-command.sh <CommandName>}"
if [[ "$NAME" =~ ^[a-z] ]]; then
    echo "Error: CommandName must be PascalCase (e.g. ImportProducts)" >&2
    exit 1
fi
lando acorn make:command "$NAME"
echo "Created: app/Console/Commands/${NAME}.php"
echo "Register in: app/Providers/AppServiceProvider.php → boot() → \$this->commands([...])"
