Deep reference for db-operations. Loaded on demand from `skills/wp-cli-ops/SKILL.md`.

# WP-CLI Database Operations

Database backup, restore, and search-replace workflows using `lando wp db` with preflight safety checks.

## Export a Backup

Always back up before any destructive operation.

```bash
lando wp db export "backup-$(date +%Y%m%d-%H%M%S).sql"
```

Use `--porcelain` to get only the filename on stdout (useful in scripts):

```bash
FILE=$(lando wp db export --porcelain)
echo "Backup written: $FILE"
```

## Import a Database

```bash
lando db-import backup.sql
```

If the file is large, check `max_allowed_packet` first:

```bash
lando wp db query "SHOW VARIABLES LIKE 'max_allowed_packet';"
```

On charset mismatch errors, verify the export and target collation match:

```bash
lando wp db query "SELECT DEFAULT_CHARACTER_SET_NAME, DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = DATABASE();"
```

## Optimize Tables

```bash
lando wp db optimize
```

## Raw SQL Queries

```bash
# Inspect bloated autoloaded options
lando wp db query "SELECT option_name, length(option_value) as size FROM wp_options WHERE autoload='yes' ORDER BY size DESC LIMIT 20;"
```

## Search and Replace

**Always run `--dry-run` first.**

```bash
# Dry run — inspect what will change
lando wp search-replace 'https://old-domain.com' 'https://new-domain.com' \
    --dry-run --precise --all-tables --report-changed-only

# Execute after verifying dry run output
lando wp search-replace 'https://old-domain.com' 'https://new-domain.com' \
    --precise --all-tables --report-changed-only
```

Flag reference:

| Flag | Purpose |
|---|---|
| `--dry-run` | Report changes without applying them |
| `--precise` | PHP serialization-safe replacement (handles serialized data) |
| `--all-tables` | Include non-standard WordPress tables (custom plugins, Eloquent tables) |
| `--skip-columns=<col>` | Exclude specific columns if needed |
| `--report-changed-only` | Suppress unchanged-table lines in output |

## Failure Modes

| Symptom | Cause | Fix |
|---|---|---|
| Search-replace corrupts serialized data | Missing `--precise` flag | Restore from backup, re-run with `--precise` |
| Database import fails | SQL file too large or charset mismatch | Split the file, check `max_allowed_packet`, verify charset |
| Import silently truncates data | Charset mismatch | Export with explicit `--default-character-set=utf8mb4` |
