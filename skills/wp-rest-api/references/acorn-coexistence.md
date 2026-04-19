Deep reference for acorn-coexistence. Loaded on demand from `skills/wp-rest-api/SKILL.md`.

# REST API and Acorn Routes Coexistence

Decision matrix for when to use `register_rest_route()` versus Acorn Routes, and how both can coexist in the same Sage project.

## Decision Table

| Criterion | Native WP REST API | Acorn Routes |
|---|---|---|
| Gutenberg block data | Yes | No |
| Mobile app consumption | Yes | Possible but less standard |
| WP ecosystem plugin interop | Yes | No |
| WP admin-ajax replacement | Yes | Yes |
| Internal app logic | Possible but verbose | Yes |
| Livewire endpoints | No | Yes (automatic) |
| Laravel-style middleware | No (use WP hooks) | Yes |
| URL prefix | `/wp-json/namespace/v1/` | Defined in `routes/api.php` |

**Both can coexist in the same project.** They serve different URL prefixes and do not conflict.

## URL Namespace Separation

```
/wp-json/wp/v2/posts      ← WP core, Gutenberg uses this
/wp-json/myapp/v1/events  ← Custom REST endpoint for external consumers
/api/dashboard/stats      ← Acorn route for internal app logic
/api/livewire/...         ← Livewire automatically uses Acorn routes
```

## When to Choose Each

**Use native REST API when:**
- The consumer is the Gutenberg editor
- A mobile app or external service needs to integrate via a standard `wp-json` URL
- A WordPress plugin expects to interact with the endpoint
- You need WP's built-in schema discovery (`OPTIONS` requests)

**Use Acorn Routes when:**
- The endpoint is consumed only by your own front-end code
- You need Laravel middleware (rate limiting, JWT, auth guards)
- Livewire components are involved (Livewire uses Acorn's routing automatically)
- You prefer Laravel-style controllers and request objects

## Response Caching

For REST API endpoints that serve the same data repeatedly, cache with transients:

```php
public function get_items($request): \WP_REST_Response
{
    $cache_key = 'rest_events_' . md5(wp_json_encode($request->get_params()));
    $cached    = get_transient($cache_key);

    if ($cached !== false) {
        return rest_ensure_response($cached);
    }

    $data = $this->fetchEvents($request);
    set_transient($cache_key, $data, HOUR_IN_SECONDS);

    return rest_ensure_response($data);
}
```

Invalidate caches on data changes:

```php
add_action('save_post_event', function () {
    global $wpdb;
    $wpdb->query(
        "DELETE FROM {$wpdb->options} WHERE option_name LIKE '_transient_rest_events_%'"
    );
});
```

## Anti-Pattern: Duplicating Endpoints

Do not register the same resource in both systems:

```php
// ❌ Wrong — same data exposed twice
register_rest_route('myapp/v1', '/events', [...]);
Route::get('/api/events', [EventController::class, 'index']);

// ✅ Correct — one canonical endpoint per resource
register_rest_route('myapp/v1', '/events', [...]);
// OR
Route::get('/api/events', [EventController::class, 'index']);
```

Choose based on who consumes the endpoint.
