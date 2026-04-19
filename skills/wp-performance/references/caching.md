Deep reference for WordPress caching strategies in Sage/Bedrock. Loaded on demand from `skills/wp-performance/SKILL.md`.

# Caching in WordPress / Sage

Caching in a Sage/Bedrock stack spans four layers — object cache, transients, full-page, and static assets — each with distinct scope and invalidation strategies.

## Strategy Selection

| Strategy | Use when | TTL | Persistence |
|---|---|---|---|
| **Object cache (Redis)** | Frequently accessed data, low-latency reads | Request or explicit | Redis server |
| **Transients** | Data shared across requests, no Redis; external API responses | Explicit | DB (or object cache if available) |
| **Cache::remember()** | Expensive Eloquent computations in Acorn Services | Explicit | Configured cache driver |
| **Full-page cache** | Static or near-static pages, high traffic | Explicit | Nginx / CDN |

Cross-reference the **acorn-redis** skill for Redis setup in Lando.

## wp_cache_get / wp_cache_set

WordPress object cache API — backed by Redis when the drop-in is installed:

```php
$cacheKey   = "my-plugin/posts/{$categoryId}";
$cacheGroup = 'my-plugin';

$posts = wp_cache_get($cacheKey, $cacheGroup);

if (false === $posts) {
    $posts = get_posts(['category' => $categoryId, 'posts_per_page' => 10]);
    wp_cache_set($cacheKey, $posts, $cacheGroup, HOUR_IN_SECONDS);
}
```

`wp_cache_get` returns `false` on a cache miss (distinguish from a cached `null`
by using the `$found` reference parameter):

```php
$data = wp_cache_get($key, $group, false, $found);
if (! $found) {
    // genuine cache miss
}
```

### Cache Invalidation

Always pair `wp_cache_set` with a cache-bust on write:

```php
// On post save/update
add_action('save_post', function (int $postId): void {
    wp_cache_delete("my-plugin/posts/{$postId}", 'my-plugin');
    // Also bust listing caches that may include this post
    wp_cache_delete('my-plugin/posts/latest', 'my-plugin');
});
```

For group-level invalidation: `wp_cache_flush_group('my-plugin')` (requires Redis
with group invalidation support — Memcached does not support it).

## Transients

Transients are stored in the `wp_options` table unless an object cache drop-in
is present (then they use the object cache transparently):

```php
$cacheKey = 'my_plugin_api_response_' . md5($query);

$data = get_transient($cacheKey);
if (false === $data) {
    $response = wp_remote_get('https://api.example.com/search?q=' . urlencode($query));
    if (! is_wp_error($response)) {
        $data = json_decode(wp_remote_retrieve_body($response), true);
        set_transient($cacheKey, $data, 12 * HOUR_IN_SECONDS);
    }
}
```

**Delete on update:**

```php
delete_transient($cacheKey);
```

**Avoid autoloaded transients** — use `set_transient()` (which sets `autoload=no`)
rather than `add_option()` with `autoload=yes`.

## Cache::remember() (Acorn/Laravel)

For Acorn-based Sage themes, use the Laravel Cache facade for expressive caching:

```php
use Illuminate\Support\Facades\Cache;

$posts = Cache::remember("category-posts-{$id}", now()->addHour(), function () use ($id) {
    return Post::whereHas('categories', fn ($q) => $q->where('id', $id))
               ->with('author')
               ->latest()
               ->take(10)
               ->get();
});
```

Configure the cache driver in `.env`:

```env
CACHE_DRIVER=redis    # preferred; falls back to file if Redis is unavailable
```

## Object Cache vs Transients — Decision Guide

Use **object cache (`wp_cache_*`)** when:
- Data is request-scoped or session-scoped
- High read frequency (menus, nav, option-based config)
- Redis is available (object cache backed by Redis is persistent across requests)
- You want group-level invalidation

Use **transients** when:
- Data must survive cache flushes (transients survive Redis restarts if stored in DB)
- External API responses that need a natural expiration
- Simpler code path is preferable over group invalidation

## Redis Setup Verification

```bash
lando redis-cli ping      # → PONG
lando redis-cli info | grep used_memory_human
```

Monitor hit rates in QM's Object Cache panel. Target >90% hit rate.
Separate Redis databases: cache (db 0), sessions (db 1), object cache (db 2).

See the **acorn-redis** skill for full Redis configuration.

## Page Cache

Full-page caching (Nginx fastcgi_cache or WP Super Cache) is appropriate for:
- High-traffic pages with mostly static content
- Pages where TTFB is the primary bottleneck and query optimization is insufficient

**Exclude from page cache:**
- Logged-in user sessions
- Cart/checkout pages (WooCommerce)
- Pages with Livewire components
- REST API endpoints

## Cache Invalidation Strategy — Required for Every Cache

Every `wp_cache_set`, `set_transient`, or `Cache::remember()` must have a
documented invalidation trigger. Common triggers:

| Trigger | Hook | Action |
|---|---|---|
| Post saved | `save_post` | Delete post-specific and listing caches |
| Term updated | `edited_term` | Delete taxonomy-based caches |
| Option updated | `update_option_{name}` | Delete option-dependent caches |
| Plugin activated | `activated_plugin` | Full cache flush if needed |
