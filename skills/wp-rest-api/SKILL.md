---
name: wp-rest-api
description: "WordPress REST API patterns — native REST endpoints, coexistence with Acorn Routes, authentication, schema validation"
user-invocable: false
---

# WordPress REST API Patterns

## When to use

Use this skill when the task involves creating, modifying, or debugging WordPress REST API endpoints, or when deciding between native REST and Acorn Routes for an API surface.

## Inputs required

- The API requirements: what data to expose, who consumes it, and authentication needs
- Whether the project already uses Acorn Routes (check `routes/web.php` or `routes/api.php`)
- The target consumers: Gutenberg editor, mobile apps, third-party integrations, or internal front-end

## Procedure

### Step 1 — Choose between Native REST and Acorn Routes

Use the decision table to pick the right approach:

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

**Both can coexist in the same project.** They serve different URL prefixes and do not conflict. Use native REST for WordPress-ecosystem integration and Acorn Routes for application logic.

### Step 2 — Register native REST endpoints

Always use `register_rest_route()` inside a `rest_api_init` action. Never omit `permission_callback`.

**Basic registration in a Service Provider:**

```php
namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class RestApiServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        add_action('rest_api_init', [$this, 'registerRoutes']);
    }

    public function registerRoutes(): void
    {
        register_rest_route('myapp/v1', '/posts', [
            'methods'             => 'GET',
            'callback'            => [$this, 'getPosts'],
            'permission_callback' => '__return_true', // Public endpoint
        ]);

        register_rest_route('myapp/v1', '/posts', [
            'methods'             => 'POST',
            'callback'            => [$this, 'createPost'],
            'permission_callback' => function () {
                return current_user_can('edit_posts');
            },
            'args'                => $this->getCreatePostArgs(),
        ]);
    }
}
```

### Step 3 — Use the WP_REST_Controller pattern for complex endpoints

For endpoints with CRUD operations, extend `WP_REST_Controller`:

```php
namespace App\Rest;

class EventController extends \WP_REST_Controller
{
    protected $namespace = 'myapp/v1';
    protected $rest_base = 'events';

    public function register_routes(): void
    {
        register_rest_route($this->namespace, '/' . $this->rest_base, [
            [
                'methods'             => \WP_REST_Server::READABLE,
                'callback'            => [$this, 'get_items'],
                'permission_callback' => [$this, 'get_items_permissions_check'],
                'args'                => $this->get_collection_params(),
            ],
            [
                'methods'             => \WP_REST_Server::CREATABLE,
                'callback'            => [$this, 'create_item'],
                'permission_callback' => [$this, 'create_item_permissions_check'],
                'args'                => $this->get_endpoint_args_for_item_schema(\WP_REST_Server::CREATABLE),
            ],
            'schema' => [$this, 'get_public_item_schema'],
        ]);

        register_rest_route($this->namespace, '/' . $this->rest_base . '/(?P<id>[\d]+)', [
            [
                'methods'             => \WP_REST_Server::READABLE,
                'callback'            => [$this, 'get_item'],
                'permission_callback' => [$this, 'get_item_permissions_check'],
                'args'                => [
                    'id' => [
                        'validate_callback' => fn($param) => is_numeric($param),
                    ],
                ],
            ],
            [
                'methods'             => \WP_REST_Server::EDITABLE,
                'callback'            => [$this, 'update_item'],
                'permission_callback' => [$this, 'update_item_permissions_check'],
            ],
            [
                'methods'             => \WP_REST_Server::DELETABLE,
                'callback'            => [$this, 'delete_item'],
                'permission_callback' => [$this, 'delete_item_permissions_check'],
            ],
        ]);
    }

    public function get_items_permissions_check($request): bool
    {
        return true; // Public
    }

    public function create_item_permissions_check($request): bool
    {
        return current_user_can('edit_posts');
    }

    public function get_item_schema(): array
    {
        return [
            '$schema'    => 'http://json-schema.org/draft-04/schema#',
            'title'      => 'event',
            'type'       => 'object',
            'properties' => [
                'id'         => ['type' => 'integer', 'readonly' => true],
                'title'      => ['type' => 'string', 'required' => true],
                'start_date' => ['type' => 'string', 'format' => 'date-time', 'required' => true],
                'end_date'   => ['type' => 'string', 'format' => 'date-time'],
                'status'     => ['type' => 'string', 'enum' => ['draft', 'published', 'cancelled']],
            ],
        ];
    }
}
```

Register the controller in a Service Provider:

```php
public function boot(): void
{
    add_action('rest_api_init', function () {
        (new \App\Rest\EventController())->register_routes();
    });
}
```

### Step 4 — Validate arguments with JSON Schema

Define argument schemas for automatic validation. Use `rest_validate_value_from_schema` for custom validation:

```php
private function getCreatePostArgs(): array
{
    return [
        'title' => [
            'type'              => 'string',
            'required'          => true,
            'sanitize_callback' => 'sanitize_text_field',
            'validate_callback' => function ($value) {
                return ! empty($value) && strlen($value) <= 200;
            },
        ],
        'status' => [
            'type'    => 'string',
            'default' => 'draft',
            'enum'    => ['draft', 'publish', 'pending'],
        ],
        'meta' => [
            'type'       => 'object',
            'properties' => [
                'color' => ['type' => 'string'],
                'priority' => ['type' => 'integer', 'minimum' => 1, 'maximum' => 5],
            ],
            'validate_callback' => function ($value, $request, $param) {
                return rest_validate_value_from_schema($value, [
                    'type'       => 'object',
                    'properties' => [
                        'color'    => ['type' => 'string'],
                        'priority' => ['type' => 'integer', 'minimum' => 1, 'maximum' => 5],
                    ],
                ], $param);
            },
        ],
    ];
}
```

### Step 5 — Expose custom fields and CPTs

**Register custom fields on existing endpoints:**

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

**Expose CPTs in the REST API:**

```php
register_post_type('event', [
    'label'         => 'Events',
    'public'        => true,
    'show_in_rest'  => true,              // Required for REST + Gutenberg
    'rest_base'     => 'events',          // Optional: customize URL segment
    'rest_namespace'=> 'wp/v2',           // Default namespace
    'supports'      => ['title', 'editor', 'custom-fields'],
]);
```

For CPTs registered via Acorn/Sage, ensure `show_in_rest` is set in the post type configuration.

### Step 6 — Authentication

**Cookie authentication (wp-admin / logged-in users):**
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

**Application Passwords (WordPress 5.6+):**
Built-in for external clients. Users generate passwords in their profile. Clients send Basic Auth:

```
Authorization: Basic base64(username:application_password)
```

**JWT via Acorn middleware:**
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

### Step 7 — Response caching and pagination

**Pagination with collection params:**

```php
public function get_items($request): \WP_REST_Response
{
    $per_page = $request->get_param('per_page') ?: 10;
    $page     = $request->get_param('page') ?: 1;

    $query = new \WP_Query([
        'post_type'      => 'event',
        'posts_per_page' => $per_page,
        'paged'          => $page,
    ]);

    $response = rest_ensure_response(
        array_map([$this, 'prepare_item_for_response'], $query->posts)
    );

    $response->header('X-WP-Total', $query->found_posts);
    $response->header('X-WP-TotalPages', $query->max_num_pages);

    return $response;
}
```

**Response caching via transients:**

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

Invalidate caches when data changes:

```php
add_action('save_post_event', function () {
    global $wpdb;
    $wpdb->query(
        "DELETE FROM {$wpdb->options} WHERE option_name LIKE '_transient_rest_events_%'"
    );
});
```

### Step 8 — Coexistence with Acorn Routes

Both systems run in the same project without conflict:

- **Native REST** serves from `/wp-json/namespace/v1/`
- **Acorn Routes** serve from whatever prefix is configured in `routes/api.php` (typically `/api/`)

Do not duplicate endpoints across both systems. Choose one per resource:

```
/wp-json/wp/v2/posts      ← WP core, Gutenberg uses this
/wp-json/myapp/v1/events  ← Custom REST endpoint for external consumers
/api/dashboard/stats      ← Acorn route for internal app logic
```

### Step 9 — Avoid anti-patterns

| Anti-pattern | Problem | Correct approach |
|---|---|---|
| Closure in route callback | Cannot be cached by object cache; breaks serialization | Use a class method reference `[$this, 'method']` |
| Missing `permission_callback` | WordPress emits `_doing_it_wrong` notice; endpoint is unprotected | Always include `permission_callback`, use `'__return_true'` for intentionally public endpoints |
| Database queries in callback | No separation of concerns; hard to test | Extract queries into a Service class or Repository |
| Returning raw arrays | Missing proper REST response headers | Use `rest_ensure_response()` or return `WP_REST_Response` |
| Hardcoded namespace version | Version changes require find-and-replace | Define namespace and version as class constants |
| No schema definition | Clients cannot discover endpoint shape | Define `get_item_schema()` on the controller |

## Verification

- [ ] Every `register_rest_route()` call includes a `permission_callback`
- [ ] Argument schemas define `type`, `required`, and `sanitize_callback` where applicable
- [ ] CPTs that need REST access have `show_in_rest => true`
- [ ] Authentication method matches the consumer (cookie for same-origin, application passwords or JWT for external)
- [ ] Pagination headers (`X-WP-Total`, `X-WP-TotalPages`) are set on collection endpoints
- [ ] No closures used as route callbacks
- [ ] No direct database queries in callbacks — logic is in Service classes
- [ ] Native REST and Acorn Routes do not duplicate the same resource
- [ ] Endpoint responds correctly to `OPTIONS` requests (CORS)

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| 404 on REST endpoint | Missing `rest_api_init` hook or permalink flush needed | Verify hook fires; flush permalinks via Settings > Permalinks |
| `rest_no_route` error | Typo in namespace or route path | Check `register_rest_route()` namespace and path match the request URL |
| `_doing_it_wrong` notice | Missing `permission_callback` | Add `permission_callback` to every route registration |
| 401 on authenticated endpoint | Nonce not sent or expired | Send `X-WP-Nonce` header; regenerate nonce if expired |
| CPT not appearing in `/wp/v2/` | `show_in_rest` not set | Add `'show_in_rest' => true` to CPT registration |
| Stale cached responses | Transient not invalidated on data change | Add cache invalidation on `save_post_{type}` hook |

## Escalation

- If the REST API is entirely disabled (by a security plugin or custom code), check for `rest_authentication_errors` filters or `rest_enabled` overrides.
- If performance is critical (hundreds of requests per second), recommend a dedicated caching layer (Varnish, Cloudflare) in front of the REST API rather than transient-based caching.
- If the API must serve a mobile app with offline support, recommend evaluating a dedicated API framework or GraphQL layer beyond the scope of this skill.
