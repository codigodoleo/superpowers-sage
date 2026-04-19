Deep reference for acorn-hook-patterns. Loaded on demand from `skills/wp-hooks-lifecycle/SKILL.md`.

# Acorn Hook Patterns

The three correct places to hook in Acorn — `register()`, `boot()`, and dedicated provider classes — and which hook category belongs where.

## The Three Hook Locations

### 1. `boot()` Method in a ServiceProvider — Primary Pattern

The `boot()` method is the correct place for all WordPress hook registrations in Sage:

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
        // register_post_type() calls here
    }
}
```

### 2. `register()` Method — Container Bindings Only

The `register()` method runs during the container build phase. WordPress is not yet fully initialized. Use it only for service container bindings, never for WordPress hooks:

```php
public function register(): void
{
    // ✅ Correct — container binding
    $this->app->singleton(ProjectService::class, function ($app) {
        return new ProjectService($app->make(CacheService::class));
    });

    // ❌ Wrong — WordPress not ready yet
    // add_action('init', [$this, 'registerPostTypes']);
}
```

### 3. Dedicated Provider Classes

For complex feature areas, create dedicated providers rather than cramming everything into one:

```php
// config/app.php
'providers' => [
    App\Providers\ThemeServiceProvider::class,
    App\Providers\PostTypeServiceProvider::class,
    App\Providers\RestApiServiceProvider::class,
    App\Providers\BlockServiceProvider::class,
],
```

## What Goes Where

| Hook category | Correct location |
|---|---|
| CPT and taxonomy registration | `boot()` via `add_action('init', ...)` |
| Theme supports, nav menus | `boot()` via `add_action('after_setup_theme', ...)` |
| Asset enqueue | `boot()` via `add_action('wp_enqueue_scripts', ...)` |
| REST route registration | `boot()` via `add_action('rest_api_init', ...)` |
| Content filters | `boot()` via `add_filter('the_content', ...)` |
| Service bindings | `register()` |
| Early plugin compat hooks | `boot()` via `add_action('plugins_loaded', ..., 20)` |

## Dependency Injection in Hook Callbacks

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

Or use a typed method directly (the provider instance is already resolved):

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

## Acceptable: `setup.php` for Theme Setup

For simple theme-level hooks that don't need dependency injection, `app/setup.php` is acceptable:

```php
// app/setup.php — theme supports, nav menus, image sizes
add_action('after_setup_theme', function () {
    add_theme_support('post-thumbnails');
    register_nav_menus(['primary_navigation' => __('Primary Navigation')]);
    add_image_size('hero', 1920, 800, true);
});
```

## Avoid: `actions.php` / `filters.php`

These are legacy Sage patterns. Consolidate hooks into ServiceProviders for better organization and testability.

## Anti-Patterns

- **Hooks in constructors:** ServiceProvider constructors run during `register()` phase. Place hooks in `boot()`.
- **Wrong priority for removal:** Trying to `remove_action()` before the target hook was added. Always use a later priority.
- **Forgetting `$accepted_args`:** If your callback needs 3 parameters but you only declared `$accepted_args` as 1 (default), you get nulls.
- **Heavy processing in early hooks:** Avoid expensive operations in `plugins_loaded` or `init` that run on every request. Defer to later hooks or use conditional checks.
- **Provider not registered:** Hooks added in a ServiceProvider will not fire if the provider is not listed in `config/app.php` under `providers`.
