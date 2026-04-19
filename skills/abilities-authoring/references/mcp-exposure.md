# MCP Exposure Reference

## How the adapter discovers Abilities

`wordpress/mcp-adapter` queries the `AbilityRegistry` when Claude calls `discover-abilities`.
Abilities registered via `AbilityRegistry::register()` are automatically exposed.

## Viewing registered Abilities

In a Claude Code session with `.mcp.json` configured:
```
discover-abilities                # lists all Abilities
execute-ability projects/list     # calls a specific Ability
```

## `.mcp.json` requirement

The adapter runs via stdio — Claude Code calls `lando wp mcp-adapter serve` as a subprocess.
Generate the config entry with:

```bash
node <plugin-path>/scripts/generate-project-mcp.mjs --path .
```

## After registration changes

Claude Code caches `discover-abilities` — restart Claude Code (or reopen the project) to see newly registered Abilities.
