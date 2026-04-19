Deep reference for Acorn Redis cache configuration and usage. Loaded on demand from `skills/acorn-redis/SKILL.md`.

# Redis Cache Configuration and Usage

Full Lando service config, Laravel cache store setup, and `Cache::remember()` / `Cache::tags()` usage patterns for Redis in Acorn.

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

For tag-based group invalidation (e.g., invalidate all post caches on `save_post`), see [`cache-tags.md`](cache-tags.md).

## Best Practices

1. **Use `Cache::remember()` by default** — avoids manual get/set boilerplate and handles race conditions.
2. **Set explicit TTLs** — never rely on implicit expiration. Use `now()->addMinutes(30)` or `now()->addHour()`.
3. **Prefix keys with context** — `homepage:featured`, `user:{id}:preferences` — avoids collisions across features.
4. **Never cache user-specific data in global keys** — tag or key by user ID if caching per-user data.
5. **Separate Redis databases** — `0` sessions, `1` cache, `2` WP object cache. Prevents one `FLUSHDB` from nuking everything.
6. **Invalidate on write, not on read** — hook into `save_post`, model events, or deploy scripts to flush stale caches.
7. **Use cache tags for related groups** — easier to invalidate "all post caches" than tracking individual keys.
8. **Monitor in development** — `lando redis-cli -h cache MONITOR` shows exactly what hits Redis and when.
