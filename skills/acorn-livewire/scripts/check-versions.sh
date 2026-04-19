#!/usr/bin/env bash
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2; exit 1
fi
lando composer show livewire/livewire --format=json 2>/dev/null | grep '"version"' | head -1 | sed 's/.*: "\(.*\)".*/Livewire: \1/'
lando composer show roots/acorn --format=json 2>/dev/null | grep '"version"' | head -1 | sed 's/.*: "\(.*\)".*/Acorn: \1/'
lando php -r 'echo "PHP: " . PHP_VERSION . "\n";'
