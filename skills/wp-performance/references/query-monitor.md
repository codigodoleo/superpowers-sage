Deep reference for Query Monitor setup and usage in Lando. Loaded on demand from `skills/wp-performance/SKILL.md`.

# Query Monitor

Query Monitor is the primary debugging tool for inspecting slow queries, hooks, transients, and HTTP requests in a Lando Sage project.

## Installation in Lando

```bash
lando wp plugin install query-monitor --activate
```

#### Enable the db.php drop-in

Query Monitor symlinks a `db.php` into `wp-content/` on activation. This enables
logging of all database queries (including pre-plugin-load queries), full stack
trace collection, and affected-row capture.

If the symlink fails (permissions):

```bash
lando ssh -c "ln -sf /app/wp/wp-content/plugins/query-monitor/wp-content/db.php /app/wp/wp-content/db.php"
```

#### Configuration constants (Bedrock: add to `config/application.php`)

| Constant | Default | Effect |
|---|---|---|
| `QM_DB_EXPENSIVE` | `0.05` | Threshold in seconds for "slow" query highlighting |
| `QM_DISABLED` | `false` | Completely disable Query Monitor |
| `QM_ENABLE_CAPS_PANEL` | `false` | Enable Capability Checks panel (logs every `current_user_can()`) |
| `QM_HIDE_CORE_ACTIONS` | `false` | Hide WordPress core hooks in the Hooks panel |
| `QM_SHOW_ALL_HOOKS` | `false` | Show every hook with attached actions (verbose) |
| `QM_HIDE_SELF` | `true` | Hide QM's own queries/hooks from panels |
| `QM_DB_SYMLINK` | `true` | Allow db.php symlink on activation |

```php
Config::define('QM_DB_EXPENSIVE', 0.05);
Config::define('QM_ENABLE_CAPS_PANEL', true);
```

## Reading the QM Panel

The toolbar shows four key metrics: **page generation time**, **peak memory**,
**SQL query duration**, and **total query count**.

### Database Queries panel

Use when TTFB is high, query count is excessive, or a specific page is slow.

**Workflow:**
1. Sort by **time** (descending) — find the slowest queries
2. Switch to **Queries by Component** — identify which plugin/theme is the offender
3. Check **duplicate queries** — same query executed multiple times indicates N+1
4. Check for queries **without indexes** (full table scans)

### Hooks & Actions panel

Use when debugging execution flow or finding slow hooks.

1. Enable `QM_SHOW_ALL_HOOKS` for complete hook list
2. Filter by theme name — see only your hooks
3. Check for hooks firing in unexpected places (e.g. `save_post` on GET requests)

### HTTP API Calls panel

Use when page load includes external API calls (REST, license checks, webhooks).
Shows every server-side HTTP request with timing and response codes. Look for:
- Plugin license checks on every admin page load
- Uncached API calls to external services
- Timeouts blocking page load

### Scripts & Styles panel

Use when frontend performance is poor.
Shows all enqueued assets with handles, URLs, versions, and broken dependencies.
Look for assets without version strings (cache-busting issues).

### Block Content panel

Use when debugging ACF blocks rendering. Shows all blocks with render output.
Check that `with()` methods aren't making expensive per-block queries (N+1 risk).

### Object Cache panel

Shows whether persistent caching is active (Redis/Memcached) and hit rates.
Target: >90% hit rate.

### Transients panel

Shows all transients set during the request with timeout values and call stacks.

## Filtering Slow Queries

In the Database Queries panel, use the filter input to search by component,
query text, or caller. Sort by the "Time" column to surface the slowest queries.
Queries above `QM_DB_EXPENSIVE` are highlighted in red.

## QM Timers (Custom Profiling)

```php
do_action('qm/start', 'my-operation');
$result = $this->expensiveComputation();
do_action('qm/stop', 'my-operation');
```

Results appear in the **Timings** panel with elapsed time and memory.

For loops with lap tracking:

```php
do_action('qm/start', 'process-items');
foreach ($items as $item) {
    $this->processItem($item);
    do_action('qm/lap', 'process-items');
}
do_action('qm/stop', 'process-items');
```

## QM Logging

```php
do_action('qm/debug', 'Cache miss for post ' . $postId);
do_action('qm/warning', 'API response slow: ' . $elapsed . 's');
do_action('qm/error', 'Failed to process payment');

// Variable interpolation
do_action('qm/warning', 'Unexpected value of {foo}', ['foo' => $value]);

// Pass exceptions directly
do_action('qm/error', $exception);
```

Levels `warning` and above trigger toolbar notifications.

## Exporting QM Data as JSON

Query Monitor exposes debugging data in response headers for authenticated
REST API requests and jQuery AJAX. For a full JSON dump, use the dump script:

```bash
bash skills/wp-performance/scripts/query-monitor-dump.sh
# or with a specific URL:
bash skills/wp-performance/scripts/query-monitor-dump.sh https://mysite.lndo.site
```

## AJAX and REST API Debugging

QM injects debugging headers into:
- **jQuery AJAX responses** — PHP errors appear in browser console
- **Authenticated REST API responses** — debugging headers in response
- **Redirects** — `X-QM-Redirect` header with call stack

For REST profiling: visit the endpoint URL directly in the browser while logged in.
