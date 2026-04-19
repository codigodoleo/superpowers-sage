Deep reference for Acorn Service Providers and dependency injection. Loaded on demand from `skills/sage-lando/SKILL.md`.

# Service Providers & Dependency Injection

How Acorn's Laravel IoC container works in WordPress — registering bindings, booting hooks, and injecting services via `AppServiceProvider` and `SageServiceProvider`.

## The Mental Model

Acorn brings Laravel's IoC (Inversion of Control) container into WordPress. Instead of scattering `new ClassName()` calls, you register services in the container and let it resolve dependencies automatically.

**Lifecycle:**
1. WordPress loads → Acorn boots → `register()` runs on all providers → `boot()` runs on all providers
2. `register()` — wire up bindings. The container isn't fully ready yet. No hooks here.
3. `boot()` — all bindings are registered. Safe to resolve services, add hooks, use the container.

## `SageServiceProvider` vs `ServiceProvider`

Always extend `Roots\Acorn\Sage\SageServiceProvider` in your theme's main provider. It handles:
- Registering the theme's view paths (so Blade finds your templates)
- Auto-discovering View Composers in `app/View/Composers/`
- Auto-discovering View Components in `app/View/Components/`
- Registering the theme's config directory

```php
namespace App\Providers;

use Roots\Acorn\Sage\SageServiceProvider;

class ThemeServiceProvider extends SageServiceProvider
{
    public function register(): void
    {
        parent::register();
        // Your bindings here
    }

    public function boot(): void
    {
        parent::boot();
        // Your hooks here
    }
}
```

**Rule:** If you create additional providers (e.g., `MailServiceProvider`), those CAN extend the base `Illuminate\Support\ServiceProvider` since they don't need Sage's view registration. Only the main theme provider needs `SageServiceProvider`.

## Container Bindings

### `singleton()` — one instance shared across the entire request

```php
public function register(): void
{
    parent::register();

    $this->app->singleton(\App\Services\NewsletterService::class, function ($app) {
        return new \App\Services\NewsletterService(
            apiKey: config('services.newsletter.api_key'),
            listId: config('services.newsletter.list_id'),
        );
    });
}
```

Use for: API clients, services with configuration, anything expensive to instantiate.

### `bind()` — new instance every time it's resolved

```php
$this->app->bind(\App\Services\FormProcessor::class, function ($app) {
    return new \App\Services\FormProcessor(
        validator: $app->make(\App\Services\ValidationService::class),
    );
});
```

Use for: stateful objects that shouldn't be shared, processors that accumulate state.

### `instance()` — bind an already-created object

```php
$settings = new \App\Services\SiteSettings(get_fields('option') ?: []);
$this->app->instance(\App\Services\SiteSettings::class, $settings);
```

Use for: objects that depend on runtime data (like ACF options loaded at boot time).

### When to use each

| Method | New instance each time? | When to use |
|---|---|---|
| `singleton()` | No — shared | Stateless services, API clients, config-heavy objects |
| `bind()` | Yes — fresh | Stateful processors, objects that accumulate data |
| `instance()` | No — exact object | Pre-built objects, runtime data |

**Default behavior:** If a class has no explicit binding but its constructor dependencies are type-hinted, the container auto-resolves it. You only need explicit bindings when constructor args aren't type-hintable (strings, config values, etc.).

## Dependency Resolution

The container auto-resolves type-hinted constructor parameters. This works in:
- View Composers
- Blade Components
- Console Commands
- Other service classes

```php
namespace App\View\Composers;

use App\Services\NewsletterService;
use Roots\Acorn\View\Composer;

class Homepage extends Composer
{
    protected static $views = ['front-page'];

    public function __construct(
        protected NewsletterService $newsletter,
    ) {}

    public function with(): array
    {
        return [
            'subscriberCount' => $this->newsletter->getSubscriberCount(),
        ];
    }
}
```

The container sees `NewsletterService` in the constructor, finds the singleton binding, and injects it automatically.

## Creating Services

Services live in `app/Services/`. They encapsulate business logic and are decoupled from WordPress.

```php
namespace App\Services;

class FeaturedContentService
{
    public function __construct(
        protected int $limit = 6,
    ) {}

    public function getFeatured(string $postType = 'post'): array
    {
        return get_posts([
            'post_type' => $postType,
            'posts_per_page' => $this->limit,
            'meta_key' => 'is_featured',
            'meta_value' => '1',
        ]);
    }

    public function count(string $postType = 'post'): int
    {
        return count($this->getFeatured($postType));
    }
}
```

**Guidelines:**
- One responsibility per service
- Accept configuration via constructor (inject via provider binding)
- Return data, don't echo HTML
- WordPress functions (`get_posts`, `get_field`) are fine here — these aren't Laravel apps
- Keep services testable: avoid global state, prefer parameters over hard-coded values

## Custom Facades

Create a Facade for frequently used services to allow static-style access:

```php
// app/Facades/FeaturedContent.php
namespace App\Facades;

use Illuminate\Support\Facades\Facade;
use App\Services\FeaturedContentService;

class FeaturedContent extends Facade
{
    protected static function getFacadeAccessor(): string
    {
        return FeaturedContentService::class;
    }
}
```

Register the alias in `ThemeServiceProvider::register()`:

```php
$this->app->booting(function () {
    $loader = \Illuminate\Foundation\AliasLoader::getInstance();
    $loader->alias('FeaturedContent', \App\Facades\FeaturedContent::class);
});
```

Usage: `FeaturedContent::getFeatured('post')`

**When to use Facades vs DI:** Prefer constructor injection in classes (Composers, Components, Services). Use Facades in Blade templates or one-off procedural code where injection isn't available.

## WordPress Hooks in `boot()`

```php
public function boot(): void
{
    parent::boot();

    // Simple hook — no dependencies
    add_action('wp_head', function () {
        echo '<meta name="theme-color" content="#1a365d">';
    });

    // Hook that uses a container service
    add_action('save_post_subscriber', function (int $postId) {
        $this->app->make(\App\Services\NewsletterService::class)
            ->syncSubscriber($postId);
    });

    // Filter with injected service
    add_filter('the_content', function (string $content) {
        return $this->app->make(\App\Services\ContentEnhancer::class)
            ->process($content);
    });
}
```

**Never use `$this->app->make()` in `register()`** — the service might not be bound yet.

## Multiple Providers

Create additional providers when a domain grows complex:

```php
// app/Providers/ApiServiceProvider.php
namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class ApiServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(\App\Services\ExternalApiClient::class, function () {
            return new \App\Services\ExternalApiClient(
                baseUrl: config('services.api.base_url'),
                token: config('services.api.token'),
            );
        });
    }
}
```

Register it in `config/app.php`:
```php
'providers' => [
    // ...
    App\Providers\ApiServiceProvider::class,
],
```

**When to split providers:**
- The domain has 3+ related bindings
- The service has its own config requirements
- You want to enable/disable a feature by toggling a provider

For most themes, a single `ThemeServiceProvider` is sufficient.

## Gotcha — `load_theme_textdomain()` Silently Fails in Acorn boot()

In WP 6.9+, calling `load_theme_textdomain()` inside `ThemeServiceProvider::boot()` returns `true` but does **not** actually register the text domain. Strings remain untranslated with no warning or error.

**Symptom:** `__('text', 'sage')` returns the original string unchanged even though `.mo` files exist.

**Root cause:** `load_theme_textdomain()` internally calls `get_template_directory()` which in Acorn's boot context resolves before WordPress's theme setup is complete.

**Fix:** Use `load_textdomain()` with an explicit path:

```php
public function boot(): void
{
    parent::boot();

    load_textdomain(
        'sage',
        get_template_directory() . '/resources/lang/' . get_locale() . '.mo'
    );
}
```

**Sanity check:**
```bash
lando wp eval "echo load_textdomain('sage', get_template_directory() . '/resources/lang/pt_BR.mo') ? 'OK' : 'FAIL';"
```
