Deep reference for content-ops. Loaded on demand from `skills/wp-cli-ops/SKILL.md`.

# WP-CLI Content Operations

User creation, capability assignment, bulk post operations, and option manipulation via `lando wp`.

## User Management

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

## Post Operations

```bash
# List posts by type and status
lando wp post list --post_type=project --post_status=draft --fields=ID,post_title

# Update a single post field
lando wp post update 42 --post_status=publish

# Update post content via stdin (avoids backslash stripping — see preflight-checks)
cat content.html | lando wp post update 5 --post_content=-

# Bulk update: loop over IDs
lando wp post list --post_type=project --format=ids | xargs -d' ' -I{} lando wp post update {} --post_status=publish
```

### Backslash Stripping Trap

WordPress runs content through `wp_slash()` internally on save. Literal backslashes in content are stripped.

```bash
# ❌ Wrong — single backslash disappears
lando wp post update 5 --post_content='\nLine one\nLine two'

# ✅ Correct — pipe content via stdin
cat content.html | lando wp post update 5 --post_content=-
```

### Revision Inflation During Bulk Migrations

Every `wp_update_post` creates a revision. For bulk migrations over hundreds of posts, disable revisions temporarily:

```bash
lando wp eval 'remove_action("post_updated", "wp_save_post_revision"); /* run migration */; add_action("post_updated", "wp_save_post_revision", 10, 1);'
```

Or set `define('WP_POST_REVISIONS', false)` temporarily in `wp-config.php`.

## Option Operations

```bash
# Read an option
lando wp option get blogname

# Update a scalar option
lando wp option update blogname 'My Site'

# Update a serialized option (must use --format=json to survive serialization)
# ✅ Correct — JSON parsed then PHP-serialized by WP
lando wp option update my_option '{"key":"value"}' --format=json

# ❌ Wrong — stored as literal string, breaks on read
lando wp option update my_option '{"key":"value"}'

# Delete an option
lando wp option delete my_option
```

## Plugin and Theme Management

```bash
# List plugins with status
lando wp plugin list

# Activate a plugin installed via Composer
lando wp plugin activate <plugin-slug>

# Deactivate a plugin
lando wp plugin deactivate <plugin-slug>

# Check for available updates
lando wp plugin list --update=available

# Theme operations
lando wp theme list
lando wp theme activate <theme-slug>
```

> Installations in this ecosystem are Composer-first. Use `/install-plugin` to add new plugins, then use WP-CLI for runtime operations.
