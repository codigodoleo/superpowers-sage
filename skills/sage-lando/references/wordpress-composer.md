Deep reference for WordPress Composer packages in Bedrock. Loaded on demand from `skills/sage-lando/SKILL.md`.

# WordPress Composer Packages

Installing WordPress plugins and themes via Composer from `wp-packages.org`, WPackagist, or local `.zip` packages — never via `lando wp plugin install`.

## Overview

All WordPress plugins and themes in this ecosystem are managed through Composer.

- Never use `lando wp plugin install` to add new plugins.
- Always run Composer inside Lando.
- Root `composer.json` manages WordPress core, plugins, and themes.

## Public packages from wp-packages.org

The project uses `https://repo.wp-packages.org` as the Composer repository for WordPress.org packages.

### Ensure repository exists

```bash
lando composer config repositories.wp-packages composer https://repo.wp-packages.org
```

### Require packages

```bash
# Plugin
lando composer require wp-plugin/plugin-slug

# Theme
lando composer require wp-theme/theme-slug
```

Examples:

```bash
lando composer require wp-plugin/akismet
lando composer require wp-theme/twentytwentyfour
```

## Local .zip plugin packages

For premium or private plugins not present on WordPress.org, install from local zip files.

### 1) Place zip in packages

Put the archive at `./packages/plugin-name.zip` (project root).

### 2) Add package repository in composer.json

Add a `type: package` repository entry:

- Regular plugin: `type: wordpress-plugin`, package `local/plugin-name`
- MU plugin: zip should be prefixed with `mu-`, package type `wordpress-muplugin`, package `local/plugin-name`

Example regular plugin:

```json
{
  "type": "package",
  "package": {
    "name": "local/plugin-name",
    "version": "1.0.0",
    "type": "wordpress-plugin",
    "dist": {
      "url": "./packages/plugin-name.zip",
      "type": "zip"
    }
  }
}
```

Example MU plugin:

```json
{
  "type": "package",
  "package": {
    "name": "local/my-muplugin",
    "version": "1.0.0",
    "type": "wordpress-muplugin",
    "dist": {
      "url": "./packages/mu-my-muplugin.zip",
      "type": "zip"
    }
  }
}
```

### 3) Require the local package

```bash
lando composer require local/plugin-name
```

## Verification

```bash
# Check installed package metadata
lando composer show wp-plugin/plugin-slug

# Check plugin visibility in WordPress
lando wp plugin list
```

Activate after install if needed:

```bash
lando wp plugin activate plugin-slug
```

## Guardrails

- Always run `lando composer require ...` from the project root.
- Never commit secrets in Composer auth files.
- For ACF Pro, use the private ACF repository flow (see `acf-composer.md`).
