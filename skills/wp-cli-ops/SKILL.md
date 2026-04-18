---
name: wp-cli-ops
description: "WP-CLI operations via Lando — database management, search-replace, user management, deploy scripts, maintenance"
user-invocable: false
---

# WP-CLI Operations via Lando

## When to use

- Performing database operations (export, import, optimize, search-replace)
- Managing plugins, themes, or users from the command line
- Running maintenance tasks (cache flush, rewrite flush, cron)
- Building or executing deployment scripts
- Troubleshooting WordPress configuration issues

## Inputs required

- The specific operation to perform
- For search-replace: old and new values, scope (all tables or specific)
- For user management: user details (email, role, username)
- For deploy scripts: target environment and deployment steps
- Confirmation that backups exist before destructive operations

## Procedure

**All WP-CLI commands must be prefixed with `lando wp`** to execute inside the Lando container.

### 1. Database management

#### Export a backup

Always back up before any destructive operation.

```bash
lando db-export backup.sql
```

#### Import a database

```bash
lando db-import backup.sql
```

#### Optimize tables

```bash
lando wp db optimize
```

#### Raw SQL query

```bash
lando wp db query "SELECT option_name, length(option_value) as size FROM wp_options WHERE autoload='yes' ORDER BY size DESC LIMIT 20;"
```

### 2. Search and replace

**Always run `--dry-run` first.**

```bash
# Dry run — inspect what will change
lando wp search-replace 'https://old-domain.com' 'https://new-domain.com' --dry-run --precise --all-tables

# Execute after verifying dry run output
lando wp search-replace 'https://old-domain.com' 'https://new-domain.com' --precise --all-tables
```

Flags:

- `--dry-run` — report changes without applying them
- `--precise` — use PHP serialization-safe replacement (handles serialized data)
- `--all-tables` — include non-standard WordPress tables (custom plugins, Eloquent tables)
- `--skip-columns=<col>` — exclude specific columns if needed

### 3. Plugin and theme management

Installations in this ecosystem are Composer-first. Use `/install-plugin` to add new plugins from `wp-packages.org` or local `.zip` files, then use WP-CLI for runtime operations.

```bash
# List plugins with status
lando wp plugin list

# Activate a plugin installed via Composer
lando wp plugin activate <plugin-slug>

# Deactivate a plugin
lando wp plugin deactivate <plugin-slug>

# Update all plugins
lando wp plugin update --all

# Check for available updates
lando wp plugin list --update=available

# Theme operations
lando wp theme list
lando wp theme activate <theme-slug>
```

### 4. User management

```bash
# List users
lando wp user list

# Create a new user
lando wp user create <username> <email> --role=<role> --user_pass=<password>

# Update user role
lando wp user set-role <user-id-or-login> <role>

# Reset a user password
lando wp user update <user-id-or-login> --user_pass=<new-password>

# Delete a user (reassign content to another user)
lando wp user delete <user-id-or-login> --reassign=<reassign-user-id>

# List user meta
lando wp user meta list <user-id-or-login>
```

### 5. Cron management

```bash
# List all scheduled cron events
lando wp cron event list

# Run all due cron events
lando wp cron event run --due-now

# Run a specific cron event
lando wp cron event run <hook-name>

# Schedule a one-time cron event
lando wp cron event schedule <hook-name> 'now'

# Test wp-cron connectivity
lando wp cron test
```

### 6. Maintenance mode

```bash
# Activate maintenance mode
lando wp maintenance-mode activate

# Deactivate maintenance mode
lando wp maintenance-mode deactivate

# Check current status
lando wp maintenance-mode status
```

### 7. Cache and transients

```bash
# Flush the object cache
lando wp cache flush

# Delete all transients
lando wp transient delete --all

# Delete expired transients only
lando wp transient delete --expired

# Flush rewrite rules
lando wp rewrite flush
```

### 8. Custom Acorn CLI commands

Cross-reference the **acorn-commands** skill for creating and running custom Acorn artisan commands within Lando:

```bash
lando wp acorn <command-name>
lando wp acorn list
```

### 9. Deploy script template

A standard deployment sequence. Adapt to the specific project requirements.

```bash
#!/bin/bash
set -euo pipefail

echo "=== Starting deployment ==="

# 1. Backup current database
echo "Backing up database..."
lando wp db export "backup-$(date +%Y%m%d-%H%M%S).sql"

# 2. Pull latest code
echo "Pulling latest code..."
git pull origin main

# 3. Install PHP dependencies
echo "Installing Composer dependencies..."
lando composer install --no-dev --optimize-autoloader

# 4. Install theme dependencies
echo "Installing theme dependencies..."
lando theme-composer install --no-dev --optimize-autoloader

# 5. Build frontend assets
echo "Building frontend assets..."
lando yarn --cwd web/app/themes/<theme-name> build

# 6. Run database migrations (if using Acorn migrations)
echo "Running migrations..."
lando wp acorn migrate --force

# 7. Clear caches
echo "Clearing caches..."
lando wp cache flush
lando wp transient delete --all
lando wp acorn cache:clear
lando wp acorn view:clear

# 8. Flush rewrite rules
echo "Flushing rewrite rules..."
lando wp rewrite flush

# 9. Deactivate maintenance mode
echo "Deactivating maintenance mode..."
lando wp maintenance-mode deactivate

echo "=== Deployment complete ==="
```

### 10. Useful diagnostic commands

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

## Verification

- [ ] Dry-run output reviewed before executing any search-replace
- [ ] Database backup exists before any destructive operation
- [ ] Plugin/theme activation confirmed with `lando wp plugin list` or `lando wp theme list`
- [ ] Cron events listed and verified after scheduling changes
- [ ] Rewrite rules flushed after permalink or route changes
- [ ] Cache cleared after configuration or content changes
- [ ] Deploy script steps completed without errors

## Failure modes

| Symptom                                 | Likely cause                              | Fix                                                                |
| --------------------------------------- | ----------------------------------------- | ------------------------------------------------------------------ |
| `lando wp` command not found            | Lando not running or misconfigured        | Run `lando start`, check `.lando.yml` tooling                      |
| Search-replace corrupts serialized data | Missing `--precise` flag                  | Restore from backup, re-run with `--precise`                       |
| Database import fails                   | SQL file too large or charset mismatch    | Split the file, check `max_allowed_packet`, verify charset         |
| Plugin activation fatal error           | PHP compatibility or dependency conflict  | Check PHP version, review error log with `lando logs`              |
| Cron events not firing                  | `DISABLE_WP_CRON` set without system cron | Add system cron or remove the constant in dev                      |
| Maintenance mode stuck                  | `.maintenance` file not removed           | `lando wp maintenance-mode deactivate` or manually remove the file |
| `wp acorn` commands fail                | Acorn not bootstrapped                    | Verify Acorn is installed and activated, check `app/Providers/`    |

## Escalation

- If WP-CLI commands consistently fail inside Lando, check Lando service health with `lando info` and `lando logs`
- For database corruption beyond simple import/export, consult a DBA or restore from a known-good backup
- If search-replace produces unexpected results after dry-run looked clean, restore from backup immediately and investigate serialized data structures
- For deploy script failures in staging or production, halt the deployment, restore from backup, and debug in the Lando local environment first

---

## Preflight checks for destructive operations

### `wp_update_post` rejects posts with invalid `_wp_page_template` meta

If a post was created under a prior theme that defined page templates, it may carry a
stale `_wp_page_template` meta value pointing to a template that no longer exists in
the current theme. WordPress validates template existence on `wp_update_post` and
rejects the operation with "Invalid page template."

**Symptoms:**
- Migration scripts fail on random posts with "Modelo de página inválido" / "Invalid page template"
- `wp post update` returns without updating; content unchanged
- Error only surfaces in migrations, not in the admin (admin uses a different code path)

**Preflight — always run before bulk `wp_update_post`:**

```bash
# List all posts with a non-default template meta
lando wp post meta list --all --meta-key=_wp_page_template --format=json | jq '.[].post_id'

# For each post about to be updated, check whether the template file exists
POST_ID=8
TEMPLATE=$(lando wp post meta get "$POST_ID" _wp_page_template)
if [ -n "$TEMPLATE" ] && [ ! -f "wp-content/themes/$(lando wp option get stylesheet)/${TEMPLATE}" ]; then
  echo "⚠️  Post $POST_ID has orphan template: $TEMPLATE"
fi
```

**Fix options:**

```bash
# Clear the orphan meta entirely
lando wp post meta delete "$POST_ID" _wp_page_template

# OR set to 'default'
lando wp post meta update "$POST_ID" _wp_page_template 'default'
```

Only after clearing should `wp_update_post` proceed safely.

### `wp post update` with `--post_content` strips backslashes

WordPress runs content through `wp_slash()` internally on save. If your content
contains literal backslashes (regex patterns, LaTeX, Windows paths in prose), they
are stripped.

**Fix:** escape backslashes in the content before passing to WP-CLI:

```bash
# ❌ Wrong — single backslash disappears
lando wp post update 5 --post_content='\nLine one\nLine two'

# ✅ Correct — double-escape for wp_slash passthrough
lando wp post update 5 --post_content='\nLine one\nLine two'
```

Or pipe content via stdin:

```bash
cat content.html | lando wp post update 5 --post_content=-
```

### Serialized option updates with `wp option update`

Options stored as serialized PHP arrays (`wp_options.option_value`) must be passed
through `--format=json` to survive serialization round-trips:

```bash
# ✅ Correct — JSON parsed then PHP-serialized by WP
lando wp option update my_option '{"key":"value"}' --format=json

# ❌ Wrong — stored as literal string, breaks on read
lando wp option update my_option '{"key":"value"}'
```

### Revision-aware updates

Every `wp_update_post` creates a revision. For bulk migrations that loop over hundreds
of posts, this inflates the revisions table fast.

**Disable revisions during migration:**

```bash
lando wp eval 'remove_action("post_updated", "wp_save_post_revision"); /* run migration */; add_action("post_updated", "wp_save_post_revision", 10, 1);'
```

Or set `define('WP_POST_REVISIONS', false)` temporarily in `wp-config.php` and restore
after.
