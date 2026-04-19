Deep reference for PHP profiling in Lando-based WordPress/Sage projects. Loaded on demand from `skills/wp-performance/SKILL.md`.

# PHP Profiling

Xdebug profiling mode generates callgrind files that identify which functions consume the most time in a WordPress/Sage request.

## Xdebug in Lando

Lando's `php` service includes Xdebug. Enable it for profiling mode:

```yaml
# .lando.yml
services:
  appserver:
    xdebug: profile
    config:
      php: .lando/php.ini
```

`.lando/php.ini`:

```ini
[xdebug]
xdebug.mode = profile
xdebug.output_dir = /tmp/xdebug
xdebug.profiler_output_name = cachegrind.out.%p
```

Trigger profiling for a specific request by appending `?XDEBUG_PROFILE=1` to the URL.
The `.cachegrind` output file is written to `/tmp/xdebug` inside the container.

Copy the output file to the host for analysis:

```bash
lando ssh -c "cat /tmp/xdebug/cachegrind.out.*" > /tmp/profile.cachegrind
```

Open in KCacheGrind, QCacheGrind (macOS), or Webgrind.

## microtime() Profiling

For targeted profiling without Xdebug, use `microtime()`:

```php
$start = microtime(true);

$result = $this->expensiveOperation();

$elapsed = microtime(true) - $start;
do_action('qm/info', sprintf('expensiveOperation took %.4fs', $elapsed));
```

For memory profiling:

```php
$memBefore = memory_get_usage(true);

$result = $this->expensiveOperation();

$memAfter  = memory_get_usage(true);
$peak      = memory_get_peak_usage(true);
do_action('qm/info', sprintf(
    'Memory delta: %s, Peak: %s',
    size_format($memAfter - $memBefore),
    size_format($peak)
));
```

## WP Profiling Hooks

### pre_get_posts — Profile WP_Query configuration

```php
add_action('pre_get_posts', function (\WP_Query $query): void {
    if (! $query->is_main_query() || is_admin()) return;

    do_action('qm/start', 'main-query');
});

add_action('the_posts', function (array $posts, \WP_Query $query): array {
    if (! $query->is_main_query()) return $posts;

    do_action('qm/stop', 'main-query');
    do_action('qm/info', 'Main query returned ' . count($posts) . ' posts');
    return $posts;
}, 10, 2);
```

### save_post — Detect unexpected writes

```php
add_action('save_post', function (int $postId): void {
    do_action('qm/warning', 'save_post triggered for post ' . $postId);
    do_action('qm/debug', new \Exception('Stack trace for save_post'));
});
```

Useful for finding plugins that trigger `save_post` on GET requests.

### wp_loaded / init — Bootstrap timing

```php
add_action('init', function (): void {
    do_action('qm/start', 'init-hook');
}, 0);

add_action('init', function (): void {
    do_action('qm/stop', 'init-hook');
}, PHP_INT_MAX);
```

## Profiling Acorn Service Providers

Measure boot time for individual Acorn Service Providers:

```php
// In AppServiceProvider::boot()
do_action('qm/start', 'theme-boot');

parent::boot();

// ... your boot logic ...

do_action('qm/stop', 'theme-boot');
```

## Profiling Order — Isolate the Bottleneck

Follow this sequence:

1. **Bootstrap** — plugins, mu-plugins, Acorn boot
   - QM Hooks panel for `plugins_loaded`, `after_setup_theme` timing
   - QM Queries panel for early queries (autoloaded options)

2. **Main query** — primary `WP_Query` for the current request
   - QM Queries panel for main query execution time and parameter validation

3. **Template rendering** — Blade rendering, view composers, component hydration
   - QM Template panel for template/parts load order
   - QM Queries panel for N+1 queries triggered during rendering

4. **Frontend** — asset loading, paint timing
   - QM Scripts & Styles panel for asset count/size
   - Lighthouse / PageSpeed Insights for CWV metrics

## When to Use Xdebug vs microtime()

| Tool | Best for |
|---|---|
| `microtime()` | Targeted timing of a known slow operation |
| QM timers (`qm/start`) | Hierarchical profiling visible in the toolbar |
| Xdebug profiler | Full call-graph analysis — finding unexpected hotspots |
| Blackfire.io | Production-safe profiling with timeline visualization |

> **Never** run Xdebug profiler in production — it significantly degrades performance.
> For production-level profiling, use Blackfire.io or New Relic APM.
