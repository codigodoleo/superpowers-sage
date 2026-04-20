# Install Steps — Detailed Reference

Deep reference for `/ai-setup`. Loaded on demand.

## Package installation

The two packages belong to different layers and must be installed separately:

| Package | Type | Target |
|---|---|---|
| `roots/acorn-ai` | library | Theme — `lando theme-composer require roots/acorn-ai` |
| `wordpress/mcp-adapter` | wordpress-plugin | Bedrock root — `lando composer require wordpress/mcp-adapter` |

```bash
# Laravel AI bridge — theme Composer so it lands in theme/vendor/
lando theme-composer require roots/acorn-ai

# WP plugin — Bedrock root Composer so installer-paths places it in content/plugins/
lando composer require wordpress/mcp-adapter
```

If you install `wordpress/mcp-adapter` via theme Composer it ends up in `theme/vendor/wordpress/mcp-adapter/`
with no `installer-paths` mapping and WordPress never loads it.

**If you get a version conflict:**
- `roots/acorn-ai` requires Acorn ≥ 4.x. Run `lando theme-composer require roots/acorn` to update first.
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

---

## Bedrock + installer-paths: autoloader silently broken

### Symptom

```bash
lando wp plugin list          # → mcp-adapter  Active ✓
lando wp mcp-adapter list     # → "not a registered wp command" ✗
```

No error in logs, no admin notice. Plugin appears active but registers no hooks.

### Cause

`wordpress/mcp-adapter` has an internal autoloader guard:

```php
$autoloader = WP_MCP_DIR . '/vendor/autoload.php';
self::$is_loaded = self::require_autoloader($autoloader); // false → Plugin::instance() never called
```

In Bedrock with `installer-paths` the plugin files land in `content/plugins/mcp-adapter/` but the
Composer autoloading lives in the root `vendor/`. The plugin-local `vendor/autoload.php` never
exists, so the guard returns `false` and the entire plugin is a no-op.

### Diagnosis

```bash
lando wp eval "
\$ref = new ReflectionClass('WP\MCP\Plugin');
var_dump(\$ref->getStaticProperties());
// array(0) {} → Plugin::instance() was never called
"
```

### Fix — create a stub that satisfies the guard

```bash
mkdir -p content/plugins/mcp-adapter/vendor
echo '<?php return true;' > content/plugins/mcp-adapter/vendor/autoload.php
```

The stub satisfies the guard without duplicating autoloading (classes are already registered via
root `vendor/`).

**Persist across installs** — add to root `composer.json`:

```json
"scripts": {
    "post-install-cmd": ["@create-mcp-adapter-stub"],
    "post-update-cmd":  ["@create-mcp-adapter-stub"],
    "create-mcp-adapter-stub": "mkdir -p content/plugins/mcp-adapter/vendor && echo '<?php return true;' > content/plugins/mcp-adapter/vendor/autoload.php"
}
```

Then run:

```bash
lando composer install   # triggers post-install-cmd
lando wp mcp-adapter list  # → mcp-adapter-default-server ✓
```

> **Note:** This is a design gap in `wordpress/mcp-adapter` — it does not account for
> Bedrock-style projects where the plugin-level `vendor/` is absent. Consider filing an upstream issue.
