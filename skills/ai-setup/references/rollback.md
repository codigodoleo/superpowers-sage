# Rollback Guide — /ai-setup

If any step fails, here is how to reverse it.

## Rollback: package installation

```bash
lando composer remove roots/acorn-ai wordpress/mcp-adapter
```

## Rollback: published config

```bash
rm config/ai.php
```

No side effects — it is a static config file.

## Rollback: API key

Remove the key line from `.env`. No packages read it until a request is made.

## Rollback: `.mcp.json`

The generator adds only the `mcpServers.wordpress` key. To remove:

```bash
jq 'del(.mcpServers.wordpress)' .mcp.json > .mcp.json.tmp && mv .mcp.json.tmp .mcp.json
```

If `.mcp.json` did not exist before, delete it entirely.
