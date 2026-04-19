Deep reference for request filtering, middleware groups, and middleware parameters in Acorn. Loaded on demand from `skills/acorn-middleware/SKILL.md`.

# Request Filtering in Acorn

## Before vs After Middleware

Middleware runs either before or after the controller depending on where you call `$next($request)`:

```php
// Before middleware — inspects/modifies REQUEST before the controller runs
public function handle(Request $request, Closure $next): Response
{
    // Inspect or modify $request here
    return $next($request);
}

// After middleware — inspects/modifies RESPONSE after the controller runs
public function handle(Request $request, Closure $next): Response
{
    $response = $next($request);
    // Inspect or modify $response here
    return $response;
}
```

## HTTP Kernel Setup

Acorn themes need an HTTP Kernel to register middleware. Create it if it doesn't exist:

```php
// app/Http/Kernel.php
namespace App\Http;

use Illuminate\Foundation\Http\Kernel as HttpKernel;

class Kernel extends HttpKernel
{
    /**
     * Global middleware — runs on every request.
     */
    protected $middleware = [
        \Illuminate\Http\Middleware\HandleCors::class,
    ];

    /**
     * Middleware groups.
     */
    protected $middlewareGroups = [
        'web' => [
            \Illuminate\Cookie\Middleware\EncryptCookies::class,
            \Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse::class,
            \Illuminate\Session\Middleware\StartSession::class,
            \Illuminate\View\Middleware\ShareErrorsFromSession::class,
        ],

        'api' => [
            \App\Http\Middleware\EnsureJsonResponse::class,
            'throttle:60,1',
        ],
    ];

    /**
     * Route middleware aliases — used in route definitions.
     */
    protected $middlewareAliases = [
        'auth.jwt' => \App\Http\Middleware\AuthenticateJwt::class,
        'role'     => \App\Http\Middleware\CheckRole::class,
        'throttle' => \Illuminate\Routing\Middleware\ThrottleRequests::class,
        'cors'     => \Illuminate\Http\Middleware\HandleCors::class,
    ];
}
```

Register the Kernel in your service provider or `config/app.php` so Acorn uses it instead of the default.

## Registering Middleware

Middleware can be applied at three levels:

### 1. Global middleware (runs on every Acorn route)

Add to the `$middleware` array in the Kernel. Use sparingly — only for truly universal concerns like CORS.

### 2. Middleware groups (applied to route groups)

```php
// routes/api.php
use Illuminate\Support\Facades\Route;

Route::middleware('api')->group(function () {
    Route::get('/posts', [PostController::class, 'index']);
});
```

### 3. Route middleware aliases (applied per-route)

```php
Route::get('/admin/dashboard', [DashboardController::class, 'index'])
    ->middleware('role:administrator');

Route::post('/webhooks/stripe', [WebhookController::class, 'handle'])
    ->middleware(['auth.jwt', 'throttle:30,1']);
```

## Middleware Groups

Group middleware logically for different route types:

```php
// In Kernel
protected $middlewareGroups = [
    // Web routes — session-based, rendered views
    'web' => [
        \Illuminate\Cookie\Middleware\EncryptCookies::class,
        \Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse::class,
        \Illuminate\Session\Middleware\StartSession::class,
        \Illuminate\View\Middleware\ShareErrorsFromSession::class,
    ],

    // API routes — stateless, JSON responses
    'api' => [
        \App\Http\Middleware\EnsureJsonResponse::class,
        'throttle:60,1',
    ],

    // Authenticated API routes — JWT + API defaults
    'api.auth' => [
        \App\Http\Middleware\EnsureJsonResponse::class,
        'auth.jwt',
        'throttle:60,1',
    ],
];
```

Usage in routes:

```php
Route::middleware('api.auth')->prefix('api/v1')->group(function () {
    Route::apiResource('posts', PostController::class);
    Route::apiResource('users', UserController::class)->middleware('role:administrator');
});
```

## Middleware Parameters

Middleware can accept parameters after the `$next` closure. Pass them in route definitions using `:` syntax.

```php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class CheckCapability
{
    public function handle(Request $request, Closure $next, string $capability): Response
    {
        if (! current_user_can($capability)) {
            return response()->json(['error' => 'Insufficient permissions.'], 403);
        }

        return $next($request);
    }
}
```

Register the alias:

```php
'capability' => \App\Http\Middleware\CheckCapability::class,
```

Usage:

```php
Route::delete('/posts/{id}', [PostController::class, 'destroy'])
    ->middleware('capability:delete_others_posts');
```

### Multiple Parameters (Variadic)

Use variadic parameters and comma-separated values in route definitions:

```php
// Middleware definition
public function handle(Request $request, Closure $next, string ...$roles): Response

// Route — passes ['administrator', 'editor'] as $roles
Route::get('/dashboard', ...)->middleware('role:administrator,editor');
```

## Common Filtering Patterns

### EnsureJsonResponse

Forces JSON content negotiation on API routes. Apply to the `api` middleware group.

```php
class EnsureJsonResponse
{
    public function handle(Request $request, Closure $next): Response
    {
        $request->headers->set('Accept', 'application/json');

        $response = $next($request);

        if ($response instanceof \Illuminate\Http\JsonResponse) {
            return $response;
        }

        return response()->json(
            data: $response->getContent() ? json_decode($response->getContent(), true) : null,
            status: $response->getStatusCode(),
        );
    }
}
```

### CheckRole

Role-based access using WordPress roles. Accepts parameters for flexible authorization.

```php
class CheckRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = wp_get_current_user();

        if (! $user->exists()) {
            return response()->json(['error' => 'Unauthenticated.'], 401);
        }

        foreach ($roles as $role) {
            if (in_array($role, $user->roles, strict: true)) {
                return $next($request);
            }
        }

        return response()->json(['error' => 'Forbidden.'], 403);
    }
}
```

### ThrottleRequests

Rate limiting uses Laravel's built-in `ThrottleRequests` middleware:

```php
// In Kernel $middlewareAliases
'throttle' => \Illuminate\Routing\Middleware\ThrottleRequests::class,

// In routes — 60 requests per minute
Route::middleware('throttle:60,1')->group(function () {
    Route::get('/api/search', [SearchController::class, 'index']);
});

// Strict limit for auth endpoints — 5 attempts per minute
Route::post('/api/login', [AuthController::class, 'login'])
    ->middleware('throttle:5,1');
```

### CORS

Use Laravel's built-in CORS middleware with a config file:

```php
// config/cors.php
return [
    'paths' => ['api/*'],
    'allowed_methods' => ['*'],
    'allowed_origins' => [
        env('WP_HOME', 'https://example.com'),
    ],
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['*'],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => false,
];
```

Add `\Illuminate\Http\Middleware\HandleCors::class` to global middleware in the Kernel.

## Middleware Ordering

Middleware runs in the order listed. Always place auth middleware before role/capability checks. Example correct order for an `api.auth` group:

1. `EnsureJsonResponse` — content negotiation (before request reaches controller)
2. `auth.jwt` — authenticate the user
3. `throttle:60,1` — rate limiting (can use authenticated user identity)
4. Per-route: `role:administrator` — authorization after authentication
