---
name: superpowers-sage:acorn-redis
description: Redis caching, sessions, and object cache in WordPress via Acorn; configuration with Lando, cache tags, and Laravel's Redis facade
user-invocable: false
---

# Redis with Acorn in WordPress

## Redis in the Stack

Lando provides Redis as a service. Acorn connects to it through Laravel's Redis integration (`illuminate/redis`). Three primary uses:

- **Cache driver** — store computed values, query results, rendered partials
- **Session driver** — user sessions backed by Redis instead of filesystem
- **Queue driver** — background job processing (see `sage:acorn-queues`)

## Lando Configuration

The Redis service is already defined in `.lando.yml` (see `sage:roots-sage-lando` lando-setup reference):

```yaml
services:
  cache:
    type: redis:6
```

Add to your `.env`:

```env
REDIS_HOST=cache
REDIS_PORT=6379
REDIS_PASSWORD=null

CACHE_DRIVER=redis
SESSION_DRIVER=redis
```

The hostname is `cache` because that is the Lando service name. Lando DNS resolves service names automatically.

## Cache Configuration

`config/cache.php` — register the Redis store:

```php
return [
    'default' => env('CACHE_DRIVER', 'file'),

    'stores' => [
        'redis' => [
            'driver' => 'redis',
            'connection' => 'cache',
            'lock_connection' => 'default',
        ],
    ],

    'prefix' => env('CACHE_PREFIX', Str::slug(env('APP_NAME', 'sage'), '_') . '_cache_'),
];
```

`config/database.php` — Redis connections:

```php
'redis' => [
    'client' => env('REDIS_CLIENT', 'phpredis'),

    'default' => [
        'host' => env('REDIS_HOST', '127.0.0.1'),
        'password' => env('REDIS_PASSWORD'),
        'port' => env('REDIS_PORT', '6379'),
        'database' => env('REDIS_DB', '0'),
    ],

    'cache' => [
        'host' => env('REDIS_HOST', '127.0.0.1'),
        'password' => env('REDIS_PASSWORD'),
        'port' => env('REDIS_PORT', '6379'),
        'database' => env('REDIS_CACHE_DB', '1'),
    ],
],
```

Separate databases (`0` for general, `1` for cache) prevent `FLUSHDB` on cache from wiping session data.

## Using the Cache

```php
use Illuminate\Support\Facades\Cache;

// Basic get/set
Cache::put('featured_ids', $ids, now()->addMinutes(30));
$ids = Cache::get('featured_ids');

// Recommended: remember pattern — fetch from cache or compute and store
$posts = Cache::remember('homepage:featured', now()->addHour(), function (): array {
    return get_posts(['post_type' => 'post', 'posts_per_page' => 6]);
});

// Forever (no TTL) — use sparingly, invalidate explicitly
Cache::forever('site:settings', $settings);

// Remove
Cache::forget('homepage:featured');

// Check existence
if (Cache::has('featured_ids')) {
    // ...
}

// Increment/decrement (atomic)
Cache::increment('page:views:' . $postId);
```

Always prefer `Cache::remember()` over manual get-then-set. It is atomic and avoids race conditions.

## Cache Tags

Tags group related entries for bulk invalidation. Requires a tag-aware driver (Redis supports this).

```php
// Store with tags
Cache::tags(['posts', 'homepage'])->remember('homepage:grid', now()->addHour(), fn () =>
    get_posts(['posts_per_page' => 12])
);

Cache::tags(['posts', 'archive'])->put('archive:page:1', $archiveData, now()->addMinutes(30));

// Flush everything tagged "posts" — clears both homepage and archive caches
Cache::tags(['posts'])->flush();

// Flush only homepage-related caches
Cache::tags(['homepage'])->flush();
```

Invalidate tags in a service provider or save_post hook:

```php
add_action('save_post', function (int $postId): void {
    Cache::tags(['posts'])->flush();
});
```

## Session Configuration

`config/session.php`:

```php
return [
    'driver' => env('SESSION_DRIVER', 'redis'),
    'lifetime' => env('SESSION_LIFETIME', 120),
    'connection' => env('SESSION_CONNECTION', 'default'),
    'cookie' => env('SESSION_COOKIE', Str::slug(env('APP_NAME', 'sage'), '_') . '_session'),
];
```

Sessions use the `default` Redis connection (database `0`), separate from cache (database `1`).

## Queue Driver

Set `QUEUE_CONNECTION=redis` in `.env`. Queue configuration lives in `config/queue.php`. See `sage:acorn-queues` for job dispatching, workers, and retry strategies.

```env
QUEUE_CONNECTION=redis
```

## WordPress Object Cache

Acorn's `Cache` facade and WordPress's object cache (`wp_cache_get`, `wp_cache_set`) are separate layers.

For WordPress core and plugins to use Redis, install an object cache drop-in:

- **`wp-redis`** — adds `object-cache.php` drop-in to `wp-content/`
- **`redis-cache`** — popular alternative with admin UI

This is independent of Acorn. Both can coexist pointing at the same Redis instance on different databases.

```env
# For wp-redis (in .env or wp-config.php)
WP_REDIS_HOST=cache
WP_REDIS_PORT=6379
WP_REDIS_DATABASE=2
```

Use database `2` to isolate WordPress object cache from Acorn cache (`1`) and sessions (`0`).

## Direct Redis Usage

When the Cache facade abstractions are not enough — pub/sub, Lua scripts, atomic pipelines:

```php
use Illuminate\Support\Facades\Redis;

// Direct key operations
Redis::set('lock:import', 'running', 'EX', 300);
$status = Redis::get('lock:import');
Redis::del('lock:import');

// Pipeline for batch operations
Redis::pipeline(function ($pipe): void {
    for ($i = 0; $i < 100; $i++) {
        $pipe->set("batch:{$i}", "value-{$i}");
    }
});

// Pub/sub (useful for inter-process signaling)
Redis::publish('cache-cleared', json_encode(['by' => 'deploy']));
```

Prefer the `Cache` facade for standard get/set/remember. Use `Redis` directly only for operations the Cache API does not support.

## Lando Redis CLI

```bash
# Open interactive Redis CLI
lando redis-cli -h cache

# Watch all commands in real time (useful for debugging cache hits/misses)
lando redis-cli -h cache MONITOR

# List all keys (dev only — never in production)
lando redis-cli -h cache KEYS '*'

# Count keys by pattern
lando redis-cli -h cache KEYS 'sage_cache_*' | wc -l

# Inspect a key's TTL
lando redis-cli -h cache TTL "sage_cache:homepage:featured"

# Flush a specific database
lando redis-cli -h cache -n 1 FLUSHDB

# Flush everything (dev only)
lando redis-cli -h cache FLUSHALL

# Check memory usage
lando redis-cli -h cache INFO memory
```

## Best Practices

1. **Use `Cache::remember()` by default** — avoids manual get/set boilerplate and handles race conditions.
2. **Set explicit TTLs** — never rely on implicit expiration. Use `now()->addMinutes(30)` or `now()->addHour()`.
3. **Prefix keys with context** — `homepage:featured`, `user:{id}:preferences` — avoids collisions across features.
4. **Never cache user-specific data in global keys** — tag or key by user ID if caching per-user data.
5. **Separate Redis databases** — `0` sessions, `1` cache, `2` WP object cache. Prevents one `FLUSHDB` from nuking everything.
6. **Invalidate on write, not on read** — hook into `save_post`, model events, or deploy scripts to flush stale caches.
7. **Use cache tags for related groups** — easier to invalidate "all post caches" than tracking individual keys.
8. **Monitor in development** — `lando redis-cli -h cache MONITOR` shows exactly what hits Redis and when.

## Verification

- Run `lando redis-cli -h cache PING` and confirm it returns `PONG` -- this verifies the Redis service is running and accessible.
- Test cache operations by setting and retrieving a value: `Cache::put('test', 'hello', 60)` then `Cache::get('test')` should return `'hello'`.
- Run `lando redis-cli -h cache INFO memory` to confirm Redis is accepting connections and check memory usage.

## Failure modes

### Problem: Connection refused (Redis not running)
- **Cause:** The Redis service in Lando is not started, or the `REDIS_HOST` in `.env` does not match the Lando service name.
- **Fix:** Run `lando restart` to restart all services including Redis. Verify `.env` has `REDIS_HOST=cache` (matching the service name in `.lando.yml`). Check that `.lando.yml` includes a `cache` service with `type: redis`. Run `lando info` to confirm the Redis service is listed and running.

### Problem: Serialization errors when caching objects
- **Cause:** The value being cached contains non-serializable data (closures, resource handles, `WP_Query` objects with database connections).
- **Fix:** Cache only scalar values, arrays, or objects that implement `Serializable` / `JsonSerializable`. Extract the needed data from complex objects into a plain array before caching. Use `Cache::remember()` with a closure that returns clean data.

## Escalation

- If the Redis service will not start at all (exits immediately or crashes), this is an infrastructure issue -- check `lando logs -s cache` for error output, verify Lando and Docker are running correctly, and try `lando rebuild`.
- If Redis is running but queue jobs are failing, consult the `sage:acorn-queues` skill for queue driver configuration and failed job troubleshooting.
