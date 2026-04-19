Deep reference for Lando command reference for Sage projects. Loaded on demand from `skills/sage-lando/SKILL.md`.

# Lando Command Reference

Quick-reference table of all Lando commands used in Sage/Acorn development — organized by category.

## Theme-level tooling (runs inside `content/themes/{theme}/`)

| Command | Purpose |
|---|---|
| `lando theme-composer require <package>` | Install a PHP package into the theme |
| `lando theme-composer remove <package>` | Uninstall a theme package |
| `lando theme-composer update` | Update theme dependencies |
| `lando theme-yarn add <package>` | Install a JS package into the theme |
| `lando theme-yarn add -D <package>` | Install a dev-only JS package |
| `lando theme-build` | Production build via Vite — exits 0 when successful |
| `lando theme-dev` / `lando vite` | Vite dev server with HMR |

## Acorn (artisan-style)

| Command | Purpose |
|---|---|
| `lando acorn make:command <Name>` | Scaffold a console command |
| `lando acorn make:provider <Name>` | Scaffold a service provider |
| `lando acorn make:controller <Name>` | Scaffold a controller |
| `lando acorn make:livewire <Name>` | Scaffold a Livewire component |
| `lando acorn make:job <Name>` | Scaffold a queue job |
| `lando acorn queue:work` | Run queue workers |
| `lando acorn route:list` | List all registered Acorn routes |
| `lando acorn schedule:run` | Execute scheduled tasks once |
| `lando acorn config:cache` | Cache all config for production |
| `lando acorn config:clear` | Clear config cache |
| `lando acorn vendor:publish --tag=<tag>` | Publish package config/assets |

## ACF Composer

| Command | Purpose |
|---|---|
| `lando acorn acf:block <Name> --localize` | Scaffold an ACF block localization-ready |
| `lando acorn acf:field <Name>` | Scaffold a field group class |
| `lando acorn acf:partial <Name>` | Scaffold a reusable field partial |
| `lando acorn acf:options <Name>` | Scaffold an ACF Options Page |
| `lando acorn acf:widget <Name>` | Scaffold an ACF widget |

## WordPress CLI

| Command | Purpose |
|---|---|
| `lando wp <any wp-cli command>` | Run WP-CLI inside the container |
| `lando wp shell` | Interactive PHP shell with WP loaded |
| `lando wp eval '<php>'` | Run PHP snippet with WP context |
| `lando wp db export <file>` | Export DB to SQL file |
| `lando wp db import <file>` | Import SQL file into DB |
| `lando wp search-replace <from> <to> --precise --dry-run` | Safe search-replace with serialized data |

For full WP-CLI patterns see `@wp-cli-ops`.

## Cache and build management

| Command | Purpose |
|---|---|
| `lando flush` | Clear Acorn + Blade + OPcache — **run after every PHP change** |
| `lando theme-build` | Production Vite build — **run after every CSS/JS change** |
| `lando restart` | Restart Lando services (rarely needed) |

## Direct project-root tools

| Command | Purpose |
|---|---|
| `lando composer <any>` | Project-root Composer (WP core, root deps) |
| `lando php <any>` | PHP in container — debug snippets, version check |

**Never run `composer` or `php` on the host.** Always use `lando` wrappers to ensure correct PHP version, extensions, database connection, and paths.

## Full Lando reference

For deep Lando setup (recipe config, services, proxy, databases, host mapping, custom tooling authoring), see `references/lando-setup.md`.
