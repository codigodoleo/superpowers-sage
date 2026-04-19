Deep reference for authentication. Loaded on demand from `skills/wp-rest-api/SKILL.md`.

# WordPress REST API Authentication

Application Passwords, cookie/nonce auth, and JWT for REST API consumers — when to use each and the Lando test workflow.

## Decision Matrix

| Consumer | Recommended auth | Notes |
|---|---|---|
| Same-origin JS (Gutenberg, admin) | Cookie + nonce | Automatic; requires `X-WP-Nonce` header |
| External app / mobile | Application Passwords | Built-in since WP 5.6; Basic Auth |
| Internal Acorn routes | JWT via middleware | Token-based; set `wp_set_current_user()` |
| CLI / testing | Application Passwords or cookie | Use `--user` flag in WP-CLI |

## Cookie Authentication (Same-Origin / Logged-In Users)

Automatic for same-origin requests. The REST API uses the logged-in cookie and verifies the `X-WP-Nonce` header:

```javascript
fetch('/wp-json/myapp/v1/posts', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'X-WP-Nonce': wpApiSettings.nonce,
    },
    body: JSON.stringify({ title: 'New Post' }),
});
```

Enqueue the nonce in your Service Provider:

```php
add_action('wp_enqueue_scripts', function () {
    wp_localize_script('sage/app', 'wpApiSettings', [
        'root'  => esc_url_raw(rest_url()),
        'nonce' => wp_create_nonce('wp_rest'),
    ]);
});
```

**Nonce expiration:** WP nonces expire after 24 hours by default. If you receive a 401 on a long-lived session, regenerate the nonce.

## Application Passwords (WordPress 5.6+)

Built-in for external clients. Users generate passwords in their profile under Users > Profile > Application Passwords. Clients send Basic Auth:

```
Authorization: Basic base64(username:application_password)
```

**Testing with Lando and curl:**

```bash
# Generate an application password first via WP admin
curl -X GET \
  -H "Authorization: Basic $(echo -n 'admin:xxxx xxxx xxxx xxxx xxxx xxxx' | base64)" \
  'https://mysite.lndo.site/wp-json/myapp/v1/posts'
```

Application Passwords require HTTPS. In Lando, use `https://` with the Lando-provided cert.

## JWT Authentication via Acorn Middleware

For token-based auth, implement a custom middleware that validates JWTs and sets the current user:

```php
namespace App\Http\Middleware;

class VerifyJwtToken
{
    public function handle($request, \Closure $next)
    {
        $token = $request->bearerToken();

        if (! $token || ! $user = $this->validateToken($token)) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        wp_set_current_user($user->ID);

        return $next($request);
    }
}
```

**Critical:** `wp_set_current_user()` must be called before any `current_user_can()` checks. If the user context is not set, all capability checks return false even with a valid token.

## Exposing Custom Fields on Existing Endpoints

```php
add_action('rest_api_init', function () {
    register_rest_field('post', 'reading_time', [
        'get_callback' => function ($post) {
            return (int) get_post_meta($post['id'], '_reading_time', true);
        },
        'update_callback' => function ($value, $post) {
            update_post_meta($post->ID, '_reading_time', absint($value));
        },
        'schema' => [
            'type'        => 'integer',
            'description' => 'Estimated reading time in minutes',
        ],
    ]);
});
```

## Exposing CPTs in the REST API

```php
register_post_type('event', [
    'show_in_rest'  => true,     // Required for REST + Gutenberg
    'rest_base'     => 'events', // Optional: customize URL segment
]);
```

For CPTs registered via Poet (`config/poet.php`), ensure `show_in_rest` is set in the configuration.
