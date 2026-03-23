---
name: wp-hooks-lifecycle
description: "WordPress hooks and lifecycle — action/filter patterns, hook placement in Sage providers, priority, debugging hooks"
user-invocable: false
---
# WordPress Hooks and Lifecycle

## When to use

When adding, modifying, or debugging WordPress hooks (actions and filters) within a Sage/Acorn project. This covers where to place hooks in the Sage architecture, understanding execution order, managing priority, using dependency injection in callbacks, and diagnosing hook-related issues.

## Inputs required

- The behavior to implement or modify (what the hook should accomplish)
- Whether the task requires an action (side effect) or a filter (data transformation)
- The appropriate lifecycle stage for the hook

## Procedure

### 1. Understand actions vs filters

- **Actions** perform side effects: register post types, enqueue scripts, send emails, flush caches.
  - `add_action('hook_name', $callback, $priority, $accepted_args)`
  - Callback returns nothing (return value is ignored).
- **Filters** transform data: modify queries, alter output, change settings.
  - `add_filter('hook_name', $callback, $priority, $accepted_args)`
  - Callback MUST return the filtered value.

### 2. WordPress lifecycle order

Understanding execution order is critical for correct hook placement:

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

### 3. Where to place hooks in Sage

**Preferred: `boot()` method in a ServiceProvider**

```php
namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class ProjectServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        // Actions
        add_action('init', [$this, 'registerPostTypes']);
        add_action('wp_enqueue_scripts', [$this, 'enqueueAssets']);
        add_action('save_post_project', [$this, 'handleProjectSave'], 10, 3);

        // Filters
        add_filter('the_content', [$this, 'appendProjectMeta']);
        add_filter('pre_get_posts', [$this, 'modifyProjectQuery']);
    }

    public function registerPostTypes(): void
    {
        // ...
    }
}
```

**Acceptable: `setup.php` for theme setup**

```php
// app/setup.php — theme supports, nav menus, image sizes
add_action('after_setup_theme', function () {
    add_theme_support('post-thumbnails');
    register_nav_menus(['primary_navigation' => __('Primary Navigation')]);
    add_image_size('hero', 1920, 800, true);
});
```

**Avoid: `actions.php` / `filters.php`**

These are legacy Sage patterns. Consolidate hooks into ServiceProviders for better organization and testability.

### 4. Priority and argument count

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

### 5. Removing hooks

Timing is critical: you can only remove a hook after it has been added.

```php
// Remove a plugin's hook — must run AFTER the plugin adds it
add_action('plugins_loaded', function () {
    remove_action('wp_head', 'wp_generator');
}, 20);  // Priority 20 ensures it runs after the plugin's plugins_loaded at 10

// Removing a class method hook — must match exact instance or use global reference
// This is notoriously tricky. If the original used an anonymous closure, it cannot be removed.
```

### 6. Dependency injection in hook callbacks

Use the Acorn container to resolve dependencies inside hook callbacks:

```php
public function boot(): void
{
    add_action('save_post', function (int $post_id) {
        $service = $this->app->make(\App\Services\ProjectService::class);
        $service->onSave($post_id);
    });
}
```

Or use method injection in the ServiceProvider itself:

```php
public function handleProjectSave(int $post_id, \WP_Post $post, bool $update): void
{
    if (wp_is_post_autosave($post_id) || wp_is_post_revision($post_id)) {
        return;
    }

    $cache = $this->app->make(\App\Services\CacheService::class);
    $cache->invalidate("project:{$post_id}");
}
```

### 7. Common hooks for Sage projects

| Hook | Type | Typical use |
|---|---|---|
| `after_setup_theme` | Action | Theme supports, nav menus, image sizes |
| `wp_enqueue_scripts` | Action | Enqueue front-end CSS/JS |
| `init` | Action | Register CPTs, taxonomies, shortcodes |
| `admin_init` | Action | Admin-specific setup, settings registration |
| `save_post` | Action | Post save side effects (cache invalidation, sync) |
| `pre_get_posts` | Action | Modify main query before execution |
| `the_content` | Filter | Modify post content output |
| `template_redirect` | Action | Redirects, access control before template loads |
| `rest_api_init` | Action | Register REST routes |
| `wp_head` | Action | Inject meta tags, structured data |
| `admin_enqueue_scripts` | Action | Enqueue admin CSS/JS |

### 8. Debugging hooks

```php
// Check if an action has fired
if (did_action('init')) {
    // init has already fired — too late to add hooks for it
}

// Check how many times an action has fired
$count = did_action('save_post'); // Returns count

// Check if a filter/action has callbacks
if (has_filter('the_content')) {
    // Something is filtering the_content
}

// List all callbacks on a hook (debug only)
global $wp_filter;
dd($wp_filter['the_content']);
```

**Query Monitor:** Install Query Monitor to see all hooks, their callbacks, execution time, and order in the "Hooks & Actions" panel.

### 9. Anti-patterns to avoid

- **Hooks in constructors:** ServiceProvider constructors run during `register()` phase, before the application is fully booted. Place hooks in `boot()`.
- **Wrong priority for removal:** Trying to `remove_action()` before the target hook was added. Always use a later priority.
- **Forgetting `$accepted_args`:** If your callback needs 3 parameters but you only declared `$accepted_args` as 1 (default), you get nulls.
- **Returning nothing from a filter:** Filters MUST return a value. Forgetting the return statement silently nullifies the data.
- **Hooks inside hooks:** Adding `add_action('init', ...)` inside another `add_action('init', ...)` callback means the inner hook never fires (init already happened).
- **Heavy processing in early hooks:** Avoid expensive operations in `plugins_loaded` or `init` that run on every request. Defer to later hooks or use conditional checks.

## Verification

1. Use Query Monitor to verify hooks fire in the expected order and with expected callbacks.
2. Confirm `did_action('hook_name')` returns the expected count at the point in code where you need it.
3. For filters, log input and output values to confirm data transformation is correct.
4. Test hook removal by verifying the target callback no longer appears in Query Monitor.
5. Run the full page lifecycle and check that no "doing it wrong" notices appear in the debug log.

## Failure modes

- **Hook never fires:** Registered too late (after WordPress already fired it). Check lifecycle order.
- **Filter returns null:** Missing `return` statement in filter callback. All data for that filter becomes null/empty.
- **Hook fires multiple times:** Common with `save_post` (autosaves, revisions). Guard with `wp_is_post_autosave()` and `wp_is_post_revision()`.
- **Cannot remove hook:** Original was added with anonymous closure or different object instance. Cannot be removed without modifying the source.
- **Wrong number of arguments:** Callback receives fewer arguments than expected. Check `$accepted_args` parameter matches.
- **Infinite loop:** Filter modifies data that triggers the same filter (e.g., calling `wp_update_post` inside `save_post`). Use `remove_action` before the triggering call, then re-add.

## Escalation

- If a hook fires in unexpected order, dump `$wp_filter['hook_name']` to see all registered callbacks and their priorities.
- If hooks added in a ServiceProvider are not firing, verify the provider is listed in `config/app.php` under `providers`.
- For complex hook interaction debugging, enable `WP_DEBUG_LOG` and use `error_log()` with timestamps at each hook point to trace execution flow.
