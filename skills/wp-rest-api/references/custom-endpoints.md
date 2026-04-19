Deep reference for custom-endpoints. Loaded on demand from `skills/wp-rest-api/SKILL.md`.

# WordPress REST API Custom Endpoints

Full `register_rest_route()` examples with schema validation, permission callbacks, and both object-style and controller-style registration.

## Basic Registration in a Service Provider

Always use `register_rest_route()` inside a `rest_api_init` action. Never omit `permission_callback`.

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

## JSON Schema Argument Validation

Define argument schemas for automatic validation:

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
                'color'    => ['type' => 'string'],
                'priority' => ['type' => 'integer', 'minimum' => 1, 'maximum' => 5],
            ],
        ],
    ];
}
```

## WP_REST_Controller Pattern for CRUD Endpoints

For endpoints with full CRUD operations, extend `WP_REST_Controller`:

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

## Pagination

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

## Anti-Patterns

| Anti-pattern | Problem | Correct approach |
|---|---|---|
| Closure in route callback | Cannot be cached; breaks serialization | Use class method reference `[$this, 'method']` |
| Missing `permission_callback` | WordPress emits `_doing_it_wrong`; endpoint unprotected | Always include `permission_callback` |
| Returning raw arrays | Missing proper REST response headers | Use `rest_ensure_response()` or return `WP_REST_Response` |
| Hardcoded namespace version | Version changes require find-and-replace | Define namespace and version as class constants |
| No schema definition | Clients cannot discover endpoint shape | Define `get_item_schema()` on the controller |
