# Superpowers Sage — Universal Rules

Rules applied in every session where this plugin is active. These take
precedence over skill-local guidance unless a skill explicitly overrides.

## Environment

- All `wp`, `composer`, `artisan`, `yarn`, `npm` commands run via `lando <cmd>`.
  Never invoke these binaries directly on the host.
- Sage projects use Bedrock. Custom code lives in `web/app/`, never in `web/wp/`.
- The plugin supports Claude Code, VS Code Copilot, and Cursor.
  When contributing to this plugin — adding or updating automation hooks —
  keep both `hooks/hooks.json` and `hooks/cursor-hooks.json` in sync via
  `scripts/sync-cursor-hooks.mjs`.

## Protected files (never edit directly)

- `.env`, `wp-config.php` — managed by Bedrock/Trellis Vault. Suggest
  `ansible-vault edit` or Bedrock `.env` pattern instead.
- `bedrock/config/environments/*.php` — environment-specific config.
- `trellis/group_vars/*/vault.yml` — secrets.

If Claude needs to modify these, it MUST ask the user first with a concrete
alternative path.

## Tailwind v4

- `tailwind.config.js` does NOT exist in this stack. Use `@theme` directives
  inside `resources/css/app.css`.
- Prefer utility composition over `@apply`. `@apply` is allowed only for
  truly reusable component primitives.
- Source of truth for design tokens is the `@theme` block in `app.css`.

## Routing & content

- HTTP routes go through Acorn Routes (`routes/web.php`), not
  `register_rest_route()` directly.
- Custom post types go through Poet (`config/poet.php`), not
  `register_post_type()`.
- Fields and blocks go through ACF Composer classes, not the ACF GUI.

## Interactive UI

- Interactive components use Livewire. Avoid custom JS for anything Livewire
  can model.
- Static UI uses Blade components, not shortcodes.

## Background work

- Scheduled/recurring work goes through Action Scheduler or Laravel queue
  jobs, never raw WP-Cron scripts.

## When in doubt

- Query the WordPress MCP Adapter (if available) via `discover-abilities`
  and `execute-ability` before generating code that references post types,
  routes, fields, or Livewire components. Consult the `sageing` skill for
  MCP query patterns when available.
- If the AI stack is not installed, ask the user instead of guessing.
