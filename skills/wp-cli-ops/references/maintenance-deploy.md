Deep reference for maintenance-deploy. Loaded on demand from `skills/wp-cli-ops/SKILL.md`.

# WP-CLI Maintenance and Deploy Operations

Maintenance mode activation, cron execution, cache flushing, and transient cleanup — the standard deploy-day WP-CLI sequence.

## Maintenance Mode

```bash
# Activate maintenance mode
lando wp maintenance-mode activate

# Deactivate maintenance mode
lando wp maintenance-mode deactivate

# Check current status
lando wp maintenance-mode status
```

If maintenance mode gets stuck (`.maintenance` file not removed after a failed deploy):

```bash
lando wp maintenance-mode deactivate
# Or manually remove:
# lando php -r "unlink(ABSPATH . '.maintenance');"
```

## Cache and Transients

```bash
# Flush the object cache (Redis/Memcached or in-process)
lando wp cache flush

# Delete all transients
lando wp transient delete --all

# Delete expired transients only (safer on production)
lando wp transient delete --expired

# Flush rewrite rules
lando wp rewrite flush
```

## Cron Management

```bash
# List all scheduled cron events
lando wp cron event list

# Run all due cron events immediately
lando wp cron event run --due-now

# Run a specific hook
lando wp cron event run <hook-name>

# Schedule a one-time event
lando wp cron event schedule <hook-name> 'now'

# Test wp-cron connectivity
lando wp cron test
```

## Standard Deploy Sequence

```bash
#!/bin/bash
set -euo pipefail

echo "=== Starting deployment ==="

# 1. Backup current database
lando wp db export "backup-$(date +%Y%m%d-%H%M%S).sql"

# 2. Pull latest code
git pull origin main

# 3. Install PHP dependencies
lando composer install --no-dev --optimize-autoloader

# 4. Install theme dependencies
lando theme-composer install --no-dev --optimize-autoloader

# 5. Build frontend assets
lando yarn --cwd web/app/themes/<theme-name> build

# 6. Run database migrations (if using Acorn migrations)
lando wp acorn migrate --force

# 7. Clear all caches
lando wp cache flush
lando wp transient delete --all
lando wp acorn cache:clear
lando wp acorn view:clear

# 8. Flush rewrite rules
lando wp rewrite flush

# 9. Deactivate maintenance mode
lando wp maintenance-mode deactivate

echo "=== Deployment complete ==="
```

## Diagnostic Commands

```bash
# Check WordPress version
lando wp core version

# Verify core file integrity
lando wp core verify-checksums

# Check PHP and server info
lando wp --info

# Export site configuration
lando wp config list

# Check site health
lando wp site health
```

## Custom Acorn CLI Commands

```bash
lando wp acorn <command-name>
lando wp acorn list
```

Cross-reference the **acorn-commands** skill for creating custom Acorn commands.
