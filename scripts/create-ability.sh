#!/usr/bin/env bash
# Wrapper for lando wp acorn make:ability
# Usage: bash scripts/create-ability.sh <AbilityName> [--project-path /path/to/project]
set -e

ABILITY_NAME="${1:?Usage: create-ability.sh <AbilityName>}"
PROJECT_PATH="$(pwd)"

if [[ "$2" == "--project-path" ]]; then
  PROJECT_PATH="$3"
fi

cd "$PROJECT_PATH"
lando wp acorn make:ability "$ABILITY_NAME"
echo "Created app/Abilities/${ABILITY_NAME}Ability.php"
echo "Register it in app/Providers/AbilitiesServiceProvider.php"
