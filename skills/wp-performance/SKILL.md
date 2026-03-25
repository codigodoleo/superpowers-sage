---
name: wp-performance
description: "WordPress performance optimization — Query Monitor deep integration, profiling, hook analysis, caching, N+1 detection, autoload audit, Core Web Vitals"
user-invocable: false
---

# WordPress Performance Optimization

## When to use

- Page load times are slow or degrading
- Core Web Vitals scores are poor (LCP, FID, CLS)
- Database queries are excessive or slow
- Frontend assets are large or render-blocking
- Object cache hit rates are low
- Autoloaded options table is bloated
- N+1 query patterns detected in Eloquent models
- Hook execution is slow or excessive
- REST API responses are slow
- Block rendering is underperforming

## Inputs required

- Observed performance symptom (slow page, high TTFB, poor CWV score)
- Which environment to profile (Lando local, staging, production)
- Whether Query Monitor is already installed
- Current caching strategy in use (Redis, transients, none)

## Procedure

### 1. Install and configure Query Monitor

**Always profile before optimizing. Never optimize blind.**

```bash
lando wp plugin install query-monitor --activate
```

#### Enable the db.php drop-in

Query Monitor symlinks a `db.php` file into `wp-content/` on activation. This enables:
- Logging of **all** database queries (including pre-plugin-load queries)
- Full stack trace collection for query attribution
- Affected rows and error message capture

If the symlink fails (permissions), manually create it:

```bash
lando ssh -c "ln -sf /app/wp/wp-content/plugins/query-monitor/wp-content/db.php /app/wp/wp-content/db.php"
```

#### Configuration constants (add to `wp-config.php` or `.env` via Bedrock)

| Constant | Default | Effect |
|---|---|---|
| `QM_DB_EXPENSIVE` | `0.05` | Threshold in seconds for "slow" query highlighting |
| `QM_DISABLED` | `false` | Completely disable Query Monitor |
| `QM_DISABLE_ERROR_HANDLER` | `false` | Disable PHP error handling |
| `QM_ENABLE_CAPS_PANEL` | `false` | Enable the Capability Checks panel (logs every `current_user_can()` call) |
| `QM_HIDE_CORE_ACTIONS` | `false` | Hide WordPress core hooks in the Hooks & Actions panel |
| `QM_SHOW_ALL_HOOKS` | `false` | Show every hook with attached actions (verbose) |
| `QM_HIDE_SELF` | `true` | Hide Query Monitor's own queries/hooks from panels |
| `QM_DB_SYMLINK` | `true` | Allow db.php symlink on activation |

For Sage/Bedrock, add to `config/application.php`:

```php
Config::define('QM_DB_EXPENSIVE', 0.05);
Config::define('QM_ENABLE_CAPS_PANEL', true);
```

### 2. Query Monitor panels — what to check and when

The toolbar displays four key metrics: **page generation time**, **peak memory**, **SQL query duration**, and **total query count**. Drill into panels based on the symptom.

#### 2.1 Database Queries panel

**When:** TTFB is high, query count is excessive, or specific pages are slow.

What it shows:
- Every SQL query executed during the request
- Execution time, affected rows, and caller (plugin/theme/function)
- Queries grouped by **component** (which plugin/theme triggered them)
- **Duplicate queries** highlighted (same query executed multiple times)
- **Slow queries** highlighted (above `QM_DB_EXPENSIVE` threshold)
- Queries with **errors** flagged

**Profiling workflow:**
1. Open the Queries panel
2. Sort by **time** (descending) to find slowest queries
3. Switch to **Queries by Component** to identify which plugin/theme is the worst offender
4. Check for **duplicate queries** — these often indicate N+1 patterns
5. Check for queries **without indexes** — look for full table scans

#### 2.2 Hooks & Actions panel

**When:** You need to understand execution flow, find slow hooks, or debug unexpected behavior.

What it shows:
- All hooks fired during the page load
- Action/filter callbacks attached to each hook, with priorities
- Component attribution (which plugin/theme added each callback)
- Filterable by component or hook name

**Profiling workflow:**
1. Enable `QM_SHOW_ALL_HOOKS` to see every hook
2. Filter by your theme name to see only your hooks
3. Check for hooks with many callbacks at the same priority (ordering issues)
4. Look for hooks that fire in unexpected places (e.g., `save_post` during a GET request)

**Related hooks per panel:** Query Monitor tracks panel-specific hooks automatically:
- **Request panel** — hooks related to rewrite rules, query parsing, request handling
- **Template panel** — hooks related to template loading (`pre_option_stylesheet`, etc.)
- **Capabilities panel** — hooks affecting role/capability handling

#### 2.3 HTTP API Calls panel

**When:** Page load includes external API calls (REST, webhooks, license checks).

What it shows:
- Every server-side HTTP request via `wp_remote_get/post/request`
- Response codes, timeouts, response sizes, timing
- Erroneous responses highlighted

**Common issues:**
- Plugin license checks on every admin page load
- Uncached API calls to external services
- Timeouts to unreachable endpoints blocking page load

#### 2.4 PHP Errors panel

**When:** Yellow/red indicator appears in the toolbar.

What it shows:
- PHP warnings, notices, deprecation messages
- Component attribution (which plugin/theme caused it)
- Full call stack

Color coding:
- **Red** — warnings (code operating unexpectedly)
- **Orange** — notices (poorly written code)
- **Deprecated** — using deprecated WordPress functions

#### 2.5 Scripts & Styles panel

**When:** Frontend performance is poor, many assets loading.

What it shows:
- All enqueued JavaScript and CSS files with handles, URLs, versions
- Dependencies and dependents for each asset
- **Broken dependencies** highlighted
- WordPress 6.5+ script modules support

**Look for:**
- High asset count (suggests need for bundling — Vite handles this for Sage)
- Assets without version strings (cache-busting issues)
- Broken dependency chains

#### 2.6 Template panel

**When:** Debugging which template is rendering, or template parts loading unexpectedly.

What it shows:
- Active template file and complete template hierarchy
- Requested template parts with load status (loaded/not found)
- Available body classes
- Compatible with block themes and FSE

#### 2.7 Block Content panel

**When:** Debugging Gutenberg blocks or ACF blocks rendering.

What it shows:
- All blocks in the post content with metadata
- Block render output
- FSE template inspection

**For ACF blocks:** Check that your block's `with()` method isn't making expensive queries. Each ACF block renders individually — N+1 patterns here are common.

#### 2.8 Transients panel

**When:** Investigating cached data or stale transients.

What it shows:
- All transients set during the request
- Timeout values, components, call stacks

#### 2.9 Object Cache panel

**When:** Checking cache effectiveness.

What it shows:
- Whether persistent caching is active (Redis/Memcached)
- Cache hit rates
- Non-persistent caching warning (limits performance across requests)

#### 2.10 Capability Checks panel

**When:** Debugging authorization issues or auditing capability usage.

Requires `QM_ENABLE_CAPS_PANEL` to be `true`.

What it shows:
- Every `current_user_can()` call during the request
- Results (granted/denied) and parameters
- Component attribution

#### 2.11 Request panel

What it shows:
- Matched URL rewrite rule
- Query variables
- Custom query variables

#### 2.12 Environment panel

What it shows:
- PHP version, memory limits, error reporting levels
- MySQL/MariaDB configuration and performance settings
- WordPress version and server information

### 3. Custom profiling with QM timers

Use Query Monitor's action hooks to profile specific code sections in your Sage theme.

#### Basic timer

```php
// In a Service class, Composer, or Controller
do_action('qm/start', 'my-expensive-operation');

$result = $this->expensiveComputation();

do_action('qm/stop', 'my-expensive-operation');
```

Results appear in the **Timings** panel showing elapsed time and approximate memory consumption.

#### Lap tracking for loops

```php
do_action('qm/start', 'process-items');

foreach ($items as $item) {
    $this->processItem($item);
    do_action('qm/lap', 'process-items');
}

do_action('qm/stop', 'process-items');
```

Each lap records an intermediate checkpoint — useful for identifying which iteration is slow.

#### Nested timers

Timers can be stacked for hierarchical profiling:

```php
do_action('qm/start', 'total-render');

do_action('qm/start', 'fetch-data');
$data = $this->fetchData();
do_action('qm/stop', 'fetch-data');

do_action('qm/start', 'render-template');
$html = view('partials.results', $data)->render();
do_action('qm/stop', 'render-template');

do_action('qm/stop', 'total-render');
```

> **Note:** Nested timers reduce memory calculation accuracy.

### 4. Custom logging with QM

Query Monitor supports PSR-3 compatible logging — use it instead of `error_log()`.

#### Log levels

```php
do_action('qm/debug', 'Cache miss for post ' . $postId);
do_action('qm/info', 'Processing batch of ' . count($items) . ' items');
do_action('qm/notice', 'Deprecated method called');
do_action('qm/warning', 'API response slow: ' . $elapsed . 's');
do_action('qm/error', 'Failed to process payment');
do_action('qm/critical', 'Database connection lost');
do_action('qm/alert', 'Disk space below 10%');
do_action('qm/emergency', 'System is unusable');
```

Levels `warning` and above trigger toolbar notifications.

#### Variable interpolation

```php
do_action('qm/warning', 'Unexpected value of {foo} for post {post_id}', [
    'foo' => $value,
    'post_id' => $postId,
]);
```

#### Logging objects

Pass `WP_Error`, `Exception`, and `Throwable` objects directly:

```php
try {
    $this->riskyOperation();
} catch (\Exception $e) {
    do_action('qm/error', $e);
}
```

#### Static method alternative

```php
QM::debug('message');
QM::warning('slow query detected');
```

> **Caution:** Never log very large values (arrays of post objects, raw HTTP responses). Use Xdebug step debugging for those.

### 5. Profiling order — isolate the bottleneck

Follow this sequence to identify where time is spent:

1. **Bootstrap** — WordPress core load, plugins, theme initialization (mu-plugins, Acorn boot)
   - Check: Hooks panel for `plugins_loaded`, `after_setup_theme` timing
   - Check: Queries panel for early queries (autoloaded options)
2. **Main query** — the primary `WP_Query` for the current request
   - Check: Queries panel for the main query execution time
3. **Template rendering** — Blade rendering, view composers, component hydration
   - Check: Template panel for which template/parts load
   - Check: Queries panel for queries triggered during rendering (N+1)
4. **Frontend** — assets loading, paint timing
   - Check: Scripts & Styles panel for asset count/size
   - Check: Lighthouse for CWV metrics

### 6. N+1 query detection in Eloquent

N+1 queries are the most common performance issue in Eloquent-based Sage themes.

#### Enable lazy loading prevention in development

In `app/Providers/AppServiceProvider.php`:

```php
use Illuminate\Database\Eloquent\Model;

public function boot(): void
{
    Model::preventLazyLoading(! app()->isProduction());
}
```

#### Fix with eager loading

```php
// Bad — N+1 (1 query for posts + N queries for authors)
$posts = Post::all();
foreach ($posts as $post) {
    echo $post->author->name;
}

// Good — eager loaded (2 queries total)
$posts = Post::with('author')->get();
```

#### Common N+1 patterns in Sage

| Location | Pattern | Fix |
|---|---|---|
| View Composer | Looping posts and accessing relationships | `->with('relation')` in query |
| ACF Block `with()` | `get_field('relationship')` per block | Cache or batch-load in provider |
| Blade `@foreach` | Accessing post meta inside loop | Eager load or use `wp_cache_get` |

### 7. Redis object cache configuration

Configure persistent object cache via Redis. Cross-reference the **acorn-redis** skill for full setup.

- Verify Redis: `lando redis-cli ping` → `PONG`
- Monitor hit rates via QM's Object Cache panel
- Target: **>90% hit rate**
- Separate Redis databases: cache (db 0), sessions (db 1), object cache (db 2)

### 8. Autoloaded options audit

Large autoloaded options slow every page load — they're loaded on every request.

```bash
# List all autoloaded options sorted by size
lando wp option list --autoload=yes --format=csv --fields=option_name,size_bytes | sort -t, -k2 -rn | head -20
```

Look for:
- Options larger than 10KB
- Stale transients stored as autoloaded options
- Plugin options that don't need autoloading

Fix:

```bash
lando wp option update <option_name> --autoload=no
```

### 9. Caching strategy selection

| Strategy | Use when | TTL | Persistence |
|---|---|---|---|
| **Transients** | Data shared across requests, no Redis | Explicit | Database (or object cache if available) |
| **Object cache (Redis)** | Frequently accessed data, low-latency | Request or explicit | Redis server |
| **Application cache** | Computed results, API responses | Explicit | Configured cache driver |

- Transients for data that must survive cache flushes with natural expiration
- Redis object cache for high-frequency reads (menus, options, query results)
- `Cache::remember()` for expensive computations in Services

### 10. Vite code splitting for frontend performance

- Dynamic imports for conditionally loaded modules: `const module = await import('./heavy-module.js')`
- Split large vendor libraries into separate chunks
- Use `@vite` directive in Blade — Sage handles asset enqueuing
- Ensure `modulepreload` is working for critical chunks

### 11. Database query optimization

- Add indexes for columns used in `WHERE`, `ORDER BY`, `JOIN`
- Always use `$wpdb->prepare()` for raw queries
- Use Eloquent query scopes to encapsulate reusable logic
- Avoid `SELECT *` — specify columns with `->select()`
- Check QM for duplicate queries and optimize with caching

### 12. Image optimization

- Use `srcset` and `sizes` attributes (WordPress generates these for media library images)
- Add `loading="lazy"` to below-the-fold images
- Serve WebP format via server-level conversion or plugin
- Set explicit `width` and `height` to prevent CLS

### 13. Cron: Action Scheduler vs wp-cron

- **wp-cron**: pseudo-cron triggered by page visits, unreliable under low traffic
- **Action Scheduler**: robust queue-based system, retries, logging, concurrent processing
- Development: `lando wp cron event run --due-now`
- Production: disable wp-cron (`DISABLE_WP_CRON`) and use real system cron

### 14. Core Web Vitals measurement

| Metric | Target | Common causes in Sage |
|---|---|---|
| **LCP** (Largest Contentful Paint) | < 2.5s | Large hero images, render-blocking CSS, slow TTFB |
| **INP** (Interaction to Next Paint) | < 200ms | Heavy JS bundles, long main-thread tasks, Livewire hydration |
| **CLS** (Cumulative Layout Shift) | < 0.1 | Images without dimensions, dynamically injected content, web fonts |

Measure with Lighthouse, PageSpeed Insights, or `web-vitals` JS library.

### 15. AJAX and REST API debugging with QM

Query Monitor includes debugging headers in:
- **jQuery AJAX responses** — PHP errors output to browser developer console
- **Authenticated REST API responses** — debugging headers in response
- **Redirects** — `X-QM-Redirect` header with call stack (trace via browser dev tools)

For REST API profiling:
1. Make an authenticated request to your endpoint
2. Check response headers for QM debug info
3. For full panel access, visit the endpoint URL directly in the browser while logged in

## Verification

- [ ] Query Monitor shows no duplicate queries and no queries > 50ms
- [ ] Autoloaded options total size is under 500KB
- [ ] No N+1 patterns reported (lazy loading prevention triggers no exceptions)
- [ ] Redis object cache hit rate is above 90%
- [ ] Core Web Vitals pass: LCP < 2.5s, INP < 200ms, CLS < 0.1
- [ ] Page load time improved from baseline measurement
- [ ] Vite bundle sizes are reasonable (no single chunk > 200KB gzipped)
- [ ] No slow queries highlighted in QM (above `QM_DB_EXPENSIVE` threshold)
- [ ] HTTP API Calls panel shows no timeouts or errors
- [ ] PHP Errors panel is clean (no warnings or deprecations from theme)

## Failure modes

| Symptom | Likely cause | Fix |
|---|---|---|
| TTFB > 1s | Slow database or no object cache | Enable Redis, audit autoloaded options |
| Query count > 50 per page | N+1 queries or missing eager loading | Add `->with()`, check view composers |
| LCP > 4s | Large unoptimized hero image | Compress, serve WebP, add preload hint |
| CLS > 0.25 | Images without explicit dimensions | Add `width`/`height` attributes |
| Redis connection refused | Redis not running in Lando | Check `.lando.yml` for Redis service, `lando rebuild` |
| Object cache not working | Drop-in not installed | Cross-ref acorn-redis skill |
| Stale cached data | Cache not invalidated on update | Implement cache-busting on save hooks |
| QM toolbar not visible | Not logged in as admin | Set QM auth cookie via Settings |
| QM db.php symlink missing | Permissions issue | Manually symlink, see step 1 |
| QM panels empty | `QM_DISABLED` is true | Check wp-config.php constants |
| Slow hooks detected | Expensive callbacks on frequent hooks | Move logic to queue/async, use QM timers to measure |
| Many HTTP API calls | Plugins making uncached external requests | Cache responses with transients, disable unnecessary calls |

## Escalation

- If performance issues persist after all optimizations, profile with Xdebug or Blackfire
- For database bottlenecks beyond query optimization, consult a DBA about schema changes or read replicas
- If Core Web Vitals cannot be met due to third-party scripts, document the constraint and escalate to project lead
- For infrastructure-level issues (server response time, CDN), escalate to hosting/DevOps team
- For QM add-on needs (Guzzle HTTP tracking, etc.), check [Query Monitor add-ons](https://querymonitor.com/)
