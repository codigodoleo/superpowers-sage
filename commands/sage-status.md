# /sage-status

Reports Lando health, stack versions, active plan, and design tools for the current Sage project.

## What it runs

1. `lando info` — container status for each service.
2. Key stack versions: WordPress, PHP, Acorn, Node.
3. Active plan detection: first `docs/plans/*/plan.md` file with `status: in-progress`.
4. Design tools: `node scripts/detect-design-tools.mjs` from the plugin root.

## Output format (≤ 20 lines total)

```
### Lando Status
<output of `lando info --format=table` trimmed to service + status>

### Stack Versions
WordPress: <lando wp core version>
PHP:       <lando php -r "echo PHP_VERSION;">
Acorn:     <lando theme-composer show roots/acorn | grep versions>
Node:      <lando node --version>

### Active Plan
<plan directory name or "No active plan found">

### Design Tools
<node scripts/detect-design-tools.mjs — single-line summary>
```

## Instructions

Run each command with `lando <cmd>`. If a command fails, show "unavailable" for that entry. Present all four sections within 20 output lines total.
