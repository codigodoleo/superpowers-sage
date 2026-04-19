Deep reference for preflight-checks. Loaded on demand from `skills/wp-cli-ops/SKILL.md`.

# WP-CLI Preflight Checks for Destructive Operations

Mandatory verification steps before any WP-CLI command that modifies or deletes data — backup, dry-run, and rollback confirmation.

## General Rules

1. **Always back up first.** Run `lando wp db export` before any destructive operation.
2. **Always dry-run first.** Use `--dry-run` on `search-replace`; inspect counts before committing.
3. **Confirm rollback path.** Know the exact `db-import` command before proceeding.

## Preflight: `wp_update_post` Rejects Posts with Invalid `_wp_page_template` Meta

If a post was created under a prior theme that defined page templates, it may carry a stale `_wp_page_template` meta value pointing to a template that no longer exists. WordPress validates template existence on `wp_update_post` and rejects the operation with "Invalid page template."

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
  echo "Post $POST_ID has orphan template: $TEMPLATE"
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

## Preflight: `wp post update` with `--post_content` Strips Backslashes

WordPress runs content through `wp_slash()` internally on save. Literal backslashes (regex patterns, LaTeX, Windows paths in prose) are stripped.

**Fix:** escape backslashes or pipe content via stdin:

```bash
# ✅ Correct — pipe content via stdin
cat content.html | lando wp post update 5 --post_content=-
```

## Preflight: Serialized Option Updates with `wp option update`

Options stored as serialized PHP arrays must be passed through `--format=json`:

```bash
# ✅ Correct — JSON parsed then PHP-serialized by WP
lando wp option update my_option '{"key":"value"}' --format=json

# ❌ Wrong — stored as literal string, breaks on read
lando wp option update my_option '{"key":"value"}'
```

## Preflight: Revision Inflation During Bulk Migrations

Every `wp_update_post` creates a revision. For migrations looping over hundreds of posts, disable revisions temporarily:

```bash
lando wp eval 'remove_action("post_updated", "wp_save_post_revision");'
# ... run migration ...
lando wp eval 'add_action("post_updated", "wp_save_post_revision", 10, 1);'
```

Or set `define('WP_POST_REVISIONS', false)` temporarily in `wp-config.php` and restore after.

## Preflight: Search-Replace Dry Run

Before any domain migration or URL replacement:

```bash
# 1. Dry run first — inspect row/cell counts
lando wp search-replace 'https://old.com' 'https://new.com' \
    --dry-run --precise --all-tables --report-changed-only

# 2. Only if dry-run output looks correct, apply
lando wp search-replace 'https://old.com' 'https://new.com' \
    --precise --all-tables --report-changed-only
```

## Rollback Checklist

- [ ] `lando wp db export backup-TIMESTAMP.sql` completed successfully
- [ ] Dry-run output reviewed and row counts are expected
- [ ] Know the exact `lando db-import backup-TIMESTAMP.sql` command to run if rollback needed
- [ ] Maintenance mode activated before starting destructive batch
- [ ] After completion: verify with `lando wp post list` or `lando wp option get` that data looks correct
