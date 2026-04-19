# Install Steps — Detailed Reference

Deep reference for `/ai-setup`. Loaded on demand.

## Package installation

```bash
lando composer require roots/acorn-ai wordpress/mcp-adapter
```

This adds both packages to `composer.json` and `composer.lock`, installs them, and runs their post-install scripts.

**If you get a version conflict:**
- `roots/acorn-ai` requires Acorn ≥ 4.x. Run `lando composer require roots/acorn` to update first.
- `wordpress/mcp-adapter` requires WP ≥ 6.9. If WP is older, upgrade via `lando composer update roots/wordpress`.

## Config publish

```bash
lando wp acorn vendor:publish --tag=acorn-ai
```

Creates `config/ai.php` in the theme. If the file already exists, the command will ask before overwriting.

## What `config/ai.php` contains

```php
return [
    'default' => env('AI_PROVIDER', 'anthropic'),
    'providers' => [
        'anthropic' => [
            'api_key' => env('ANTHROPIC_API_KEY'),
        ],
    ],
];
```

Edit this file to add additional providers or change defaults.

## MCP Adapter registration

`wordpress/mcp-adapter` registers a WP CLI command: `wp mcp-adapter`. After installing:

```bash
lando wp mcp-adapter list            # list registered servers
lando wp mcp-adapter serve           # start stdio server (called by Claude Code via .mcp.json)
```

The adapter auto-discovers registered Abilities when it starts.
