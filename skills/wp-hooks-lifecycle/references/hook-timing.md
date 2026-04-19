Deep reference for hook-timing. Loaded on demand from `skills/wp-hooks-lifecycle/SKILL.md`.

# WordPress Hook Timing Reference

WordPress boot sequence and which hooks fire when — the timing reference for registering CPTs, enqueuing assets, and running Acorn boot.

## Full Boot Sequence

```
muplugins_loaded          # MU plugins loaded
plugins_loaded            # Regular plugins loaded
after_setup_theme         # Theme setup (theme supports, menus, image sizes)
init                      # Post types, taxonomies, shortcodes, rewrite rules
widgets_init              # Widget registration
wp_loaded                 # Everything loaded, before headers sent
admin_init                # Admin-specific initialization
template_redirect         # Decide which template to load (redirects happen here)
wp_enqueue_scripts        # Front-end CSS/JS enqueue
wp_head                   # <head> output
the_content               # Filter post content
wp_footer                 # Before </body> output
shutdown                  # After response sent
```

## What Belongs Where

| Task | Correct hook | Notes |
|---|---|---|
| Register CPTs and taxonomies | `init` | Must be before `wp_loaded` |
| Register nav menus, image sizes | `after_setup_theme` | Theme setup context |
| Enqueue front-end assets | `wp_enqueue_scripts` | |
| Enqueue admin assets | `admin_enqueue_scripts` | |
| Register REST routes | `rest_api_init` | |
| Admin settings registration | `admin_init` | |
| Access control / redirects | `template_redirect` | Before headers sent |
| Run after all plugins/theme loaded | `wp_loaded` | Safe to access any registered type |

## Early vs Late Hook Guidance

**Early hooks** (`muplugins_loaded`, `plugins_loaded`):
- Only use for plugin compatibility checks or very early bootstrapping
- Service container is not fully available in Acorn at this stage
- Avoid expensive operations — runs on every request including AJAX and REST

**`after_setup_theme`:**
- Correct place for `add_theme_support()`, `register_nav_menus()`, `add_image_size()`
- Fires once per request after the child theme functions.php runs

**`init`:**
- The primary hook for all content-type registration
- Post types, taxonomies, shortcodes, rewrite rules
- Most ServiceProvider `boot()` registrations target `init`

**Late hooks** (`wp_loaded` and after):
- By `wp_loaded`, all plugins and the theme have initialized
- Safe to call functions that depend on CPTs or taxonomies being registered
- `template_redirect` is the last chance to redirect before template output begins

## Removing Hooks

Timing is critical — you can only remove a hook after it has been added:

```php
// Remove a plugin's hook — must run AFTER the plugin adds it
add_action('plugins_loaded', function () {
    remove_action('wp_head', 'wp_generator');
}, 20);  // Priority 20 ensures it runs after the plugin's plugins_loaded at 10
```

If the original hook was added with an anonymous closure, it cannot be removed.

## Priority System

```php
// Default priority is 10, default accepted_args is 1
add_action('save_post', [$this, 'onSave'], 10, 3);

// Lower number = runs earlier
add_action('init', [$this, 'earlyInit'], 5);    // Runs before priority 10
add_action('init', [$this, 'lateInit'], 20);     // Runs after priority 10

// accepted_args must match callback parameters
add_filter('the_title', function (string $title, int $post_id) {
    return $title . ' #' . $post_id;
}, 10, 2);  // 2 = receives both $title and $post_id
```

## Debugging Hook Timing

```php
// Check if an action has fired
if (did_action('init')) {
    // init has already fired — too late to add hooks for it
}

// Check how many times an action has fired
$count = did_action('save_post'); // Returns count

// List all callbacks on a hook (debug only)
global $wp_filter;
dd($wp_filter['the_content']);
```

**Query Monitor:** Install Query Monitor to see all hooks, their callbacks, execution time, and order in the "Hooks & Actions" panel.
