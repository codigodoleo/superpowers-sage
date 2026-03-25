---
name: superpowers-sage:acorn-middleware
description: HTTP middleware, JWT authentication, custom guards, and request filtering using Acorn's Laravel middleware stack inside WordPress
user-invocable: false
---

# Middleware & Authentication

## What Middleware Does in Acorn

Middleware filters HTTP requests before they reach route controllers -- the same pipeline concept as Laravel. Each middleware inspects or transforms the request, then either passes it forward or returns a response early.

**Critical distinction:** Middleware only runs on Acorn-registered routes (defined in `routes/web.php` or `routes/api.php`). It does NOT intercept native WordPress requests (admin pages, REST API endpoints registered via `register_rest_route()`, or front-end page loads handled by the template hierarchy). If you need to filter WordPress-native requests, use `add_action`/`add_filter` hooks instead.

## Creating Middleware

```bash
lando acorn make:middleware EnsureJsonResponse
```

This generates `app/Http/Middleware/EnsureJsonResponse.php`:

```php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureJsonResponse
{
    public function handle(Request $request, Closure $next): Response
    {
        $request->headers->set('Accept', 'application/json');

        return $next($request);
    }
}
```

The `handle()` method receives the request and a `$next` closure. Call `$next($request)` to pass the request deeper into the application. Return a response directly to short-circuit the pipeline.

### Before vs After Middleware

```php
// Before middleware — runs BEFORE the controller
public function handle(Request $request, Closure $next): Response
{
    // Inspect/modify request here
    return $next($request);
}

// After middleware — runs AFTER the controller
public function handle(Request $request, Closure $next): Response
{
    $response = $next($request);
    // Inspect/modify response here
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
        'role' => \App\Http\Middleware\CheckRole::class,
        'throttle' => \Illuminate\Routing\Middleware\ThrottleRequests::class,
        'cors' => \Illuminate\Http\Middleware\HandleCors::class,
    ];
}
```

Register the Kernel in your service provider or `config/app.php` so Acorn uses it instead of the default.

## Registering Middleware

Middleware can be applied at three levels:

### 1. Global middleware (runs on every Acorn route)

Add to the `$middleware` array in the Kernel. Use sparingly -- only for truly universal concerns like CORS.

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

## Common Middleware Patterns

### EnsureJsonResponse

Forces JSON content negotiation on API routes. Apply to the `api` middleware group.

```php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

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

Role-based access using WordPress roles and capabilities. Accepts parameters for flexible authorization.

```php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

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

Usage in routes:

```php
// Single role
Route::get('/admin/settings', [SettingsController::class, 'index'])
    ->middleware('role:administrator');

// Multiple roles — user needs at least one
Route::get('/reports', [ReportController::class, 'index'])
    ->middleware('role:administrator,editor');
```

### ThrottleRequests

Rate limiting uses Laravel's built-in `ThrottleRequests` middleware. Register it as an alias and apply with parameters:

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

## JWT Authentication

JWT (JSON Web Tokens) is the preferred authentication approach for Acorn API routes. WordPress has its own cookie-based auth for the admin and REST API, but Acorn routes need a stateless auth mechanism.

### Install the JWT Package

```bash
lando theme-composer require firebase/php-jwt
```

### Create the JWT Service

```php
// app/Services/JwtService.php
namespace App\Services;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Firebase\JWT\ExpiredException;

class JwtService
{
    public function __construct(
        protected readonly string $secret,
        protected readonly string $algorithm = 'HS256',
        protected readonly int $ttl = 3600,
        protected readonly int $refreshTtl = 604800,
    ) {}

    public function issue(\WP_User $user): array
    {
        $now = time();

        $accessPayload = [
            'iss' => home_url(),
            'sub' => $user->ID,
            'iat' => $now,
            'exp' => $now + $this->ttl,
            'type' => 'access',
        ];

        $refreshPayload = [
            'iss' => home_url(),
            'sub' => $user->ID,
            'iat' => $now,
            'exp' => $now + $this->refreshTtl,
            'type' => 'refresh',
        ];

        return [
            'access_token' => JWT::encode($accessPayload, $this->secret, $this->algorithm),
            'refresh_token' => JWT::encode($refreshPayload, $this->secret, $this->algorithm),
            'token_type' => 'Bearer',
            'expires_in' => $this->ttl,
        ];
    }

    public function decode(string $token): object
    {
        return JWT::decode($token, new Key($this->secret, $this->algorithm));
    }

    public function refresh(string $refreshToken): array
    {
        $payload = $this->decode($refreshToken);

        if (($payload->type ?? null) !== 'refresh') {
            throw new \InvalidArgumentException('Invalid token type.');
        }

        $user = get_user_by('id', $payload->sub);

        if (! $user) {
            throw new \InvalidArgumentException('User not found.');
        }

        return $this->issue($user);
    }
}
```

### Register the Service

```php
// In ThemeServiceProvider::register() or a dedicated AuthServiceProvider
$this->app->singleton(JwtService::class, fn () => new JwtService(
    secret: config('app.key', env('JWT_SECRET', '')),
    ttl: (int) env('JWT_TTL', 3600),
    refreshTtl: (int) env('JWT_REFRESH_TTL', 604800),
));
```

Add `JWT_SECRET` to your `.env`:

```
JWT_SECRET=your-random-secret-key-at-least-32-chars
```

### Create the JWT Middleware

```bash
lando acorn make:middleware AuthenticateJwt
```

```php
// app/Http/Middleware/AuthenticateJwt.php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use App\Services\JwtService;
use Firebase\JWT\ExpiredException;

class AuthenticateJwt
{
    public function __construct(
        protected readonly JwtService $jwt,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->bearerToken();

        if (! $token) {
            return response()->json(['error' => 'Token required.'], 401);
        }

        try {
            $payload = $this->jwt->decode($token);
        } catch (ExpiredException) {
            return response()->json(['error' => 'Token expired.'], 401);
        } catch (\Throwable) {
            return response()->json(['error' => 'Invalid token.'], 401);
        }

        if (($payload->type ?? null) !== 'access') {
            return response()->json(['error' => 'Invalid token type.'], 401);
        }

        $user = get_user_by('id', $payload->sub);

        if (! $user) {
            return response()->json(['error' => 'User not found.'], 401);
        }

        // Set WordPress current user so WP functions work
        wp_set_current_user($user->ID);

        // Attach user to the request for controller access
        $request->merge(['auth_user' => $user]);
        $request->setUserResolver(fn () => $user);

        return $next($request);
    }
}
```

### Auth Controller with Login and Refresh Endpoints

```php
// app/Http/Controllers/AuthController.php
namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Services\JwtService;

class AuthController
{
    public function __construct(
        protected readonly JwtService $jwt,
    ) {}

    public function login(Request $request): JsonResponse
    {
        $request->validate([
            'username' => 'required|string',
            'password' => 'required|string',
        ]);

        $user = wp_authenticate(
            $request->input('username'),
            $request->input('password'),
        );

        if (is_wp_error($user)) {
            return response()->json([
                'error' => 'Invalid credentials.',
            ], 401);
        }

        return response()->json($this->jwt->issue($user));
    }

    public function refresh(Request $request): JsonResponse
    {
        $request->validate([
            'refresh_token' => 'required|string',
        ]);

        try {
            $tokens = $this->jwt->refresh($request->input('refresh_token'));
        } catch (\Throwable) {
            return response()->json(['error' => 'Invalid refresh token.'], 401);
        }

        return response()->json($tokens);
    }

    public function me(Request $request): JsonResponse
    {
        $user = wp_get_current_user();

        return response()->json([
            'id' => $user->ID,
            'username' => $user->user_login,
            'email' => $user->user_email,
            'display_name' => $user->display_name,
            'roles' => $user->roles,
        ]);
    }
}
```

### Route Registration

```php
// routes/api.php
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;

// Public auth routes
Route::post('/auth/login', [AuthController::class, 'login'])
    ->middleware('throttle:5,1');

Route::post('/auth/refresh', [AuthController::class, 'refresh'])
    ->middleware('throttle:10,1');

// Protected routes
Route::middleware('auth.jwt')->group(function () {
    Route::get('/auth/me', [AuthController::class, 'me']);

    // All protected API routes go here
    Route::get('/posts', [PostController::class, 'index']);
    Route::post('/posts', [PostController::class, 'store'])->middleware('role:editor,administrator');
});
```

### Using the Token from a Client

```js
// Login
const response = await fetch('/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'secret' }),
});
const { access_token, refresh_token } = await response.json();

// Authenticated request
const posts = await fetch('/api/posts', {
    headers: { 'Authorization': `Bearer ${access_token}` },
});

// Refresh when token expires
const refreshed = await fetch('/api/auth/refresh', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh_token }),
});
```

## Custom Guards

For deeper integration with Laravel's auth system, create a WordPress-aware guard. This lets you use Laravel's `Auth` facade and `auth()` helper with WordPress users.

```php
// app/Auth/WordPressGuard.php
namespace App\Auth;

use Illuminate\Contracts\Auth\Guard;
use Illuminate\Http\Request;
use App\Services\JwtService;

class WordPressGuard implements Guard
{
    protected ?\WP_User $user = null;

    public function __construct(
        protected readonly JwtService $jwt,
        protected readonly Request $request,
    ) {}

    public function check(): bool
    {
        return $this->user() !== null;
    }

    public function guest(): bool
    {
        return ! $this->check();
    }

    public function id(): ?int
    {
        return $this->user()?->ID;
    }

    public function user(): ?\WP_User
    {
        if ($this->user !== null) {
            return $this->user;
        }

        $token = $this->request->bearerToken();

        if (! $token) {
            return null;
        }

        try {
            $payload = $this->jwt->decode($token);
            $this->user = get_user_by('id', $payload->sub) ?: null;
        } catch (\Throwable) {
            return null;
        }

        return $this->user;
    }

    public function validate(array $credentials = []): bool
    {
        $user = wp_authenticate(
            $credentials['username'] ?? '',
            $credentials['password'] ?? '',
        );

        return ! is_wp_error($user);
    }

    public function hasUser(): bool
    {
        return $this->user !== null;
    }

    public function setUser($user): static
    {
        $this->user = $user;
        return $this;
    }
}
```

Register the guard in a provider:

```php
// app/Providers/AuthServiceProvider.php
namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Facades\Auth;
use App\Auth\WordPressGuard;
use App\Services\JwtService;

class AuthServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        Auth::extend('wordpress', function ($app, $name, array $config) {
            return new WordPressGuard(
                jwt: $app->make(JwtService::class),
                request: $app->make('request'),
            );
        });
    }
}
```

Configure it in `config/auth.php`:

```php
return [
    'defaults' => [
        'guard' => 'wordpress',
    ],

    'guards' => [
        'wordpress' => [
            'driver' => 'wordpress',
        ],
    ],
];
```

Now you can use Laravel's auth helpers:

```php
$user = auth()->user();       // Returns WP_User
$userId = auth()->id();       // Returns user ID
if (auth()->check()) { ... }  // Authenticated?
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

### Multiple Parameters

Variadic parameters use commas:

```php
// Middleware definition
public function handle(Request $request, Closure $next, string ...$roles): Response

// Route — passes ['administrator', 'editor'] as $roles
Route::get('/dashboard', ...)->middleware('role:administrator,editor');
```

## Best Practices

| Practice | Why |
|---|---|
| Keep middleware thin | Middleware should check a condition and pass/reject. Delegate heavy logic to services. |
| Single responsibility | One middleware = one concern. Don't combine auth + rate limiting + logging. |
| Use middleware for cross-cutting concerns | Auth, CORS, rate limiting, request logging, content negotiation. |
| Don't put business logic in middleware | Business rules belong in controllers and services. |
| Order matters | Middleware runs in the order listed. Put auth before role checks. |
| Return early on failure | Don't call `$next($request)` if the request should be rejected. |
| Set WP current user in auth middleware | Call `wp_set_current_user()` so WordPress functions like `current_user_can()` work correctly downstream. |
| Use `$request->bearerToken()` for JWT | Don't manually parse the `Authorization` header. Laravel provides this helper. |
| Protect refresh endpoints too | Apply throttling to token refresh to prevent abuse. |
| Store JWT_SECRET in `.env` | Never hardcode secrets. Use at least 32 random characters. |

## Common Mistakes

| Mistake | Correct approach |
|---|---|
| Applying middleware to WordPress admin routes | Middleware only works on Acorn routes. Use `add_action`/`add_filter` for WP-native requests. |
| Using Laravel's `auth` middleware without a guard | Laravel's built-in `Authenticate` middleware expects a configured guard. Create a custom guard or use `auth.jwt`. |
| Forgetting `wp_set_current_user()` in JWT middleware | Without this, WordPress functions like `current_user_can()` won't reflect the authenticated user. |
| Session-based auth for API routes | Use JWT for stateless API auth. Sessions require cookies and don't suit mobile/SPA clients. |
| Registering middleware but not creating the Kernel | Middleware aliases and groups require the HTTP Kernel. Create `app/Http/Kernel.php`. |
| Hardcoding JWT secrets | Use `env('JWT_SECRET')` and add the value to `.env`. |
| Not throttling auth endpoints | Login and refresh endpoints should always have strict rate limits to prevent brute-force attacks. |
| Returning HTML errors from API middleware | API middleware should return JSON responses with appropriate HTTP status codes. |

## Verification

- Send a request without valid credentials and confirm the middleware returns a 401 or 403 JSON response (blocking unauthorized access).
- Send a request with valid credentials (e.g., a valid JWT Bearer token) and confirm the middleware passes the request through to the controller, returning the expected 200 response.
- Check `lando acorn route:list` and verify the middleware alias appears in the middleware column for protected routes.

## Failure modes

### Problem: Middleware not executing (requests pass through unfiltered)
- **Cause:** The middleware class is not registered in the HTTP Kernel (`app/Http/Kernel.php`), either as a global middleware, in a middleware group, or as a route middleware alias.
- **Fix:** Add the middleware to `$middlewareAliases` in the Kernel for route-level usage, or to `$middlewareGroups` for group-level usage. Confirm the Kernel class exists at `app/Http/Kernel.php` and is being used by Acorn.

### Problem: JWT secret missing or invalid (all tokens rejected)
- **Cause:** The `JWT_SECRET` environment variable is not set in `.env`, or the secret used to sign tokens differs from the one used to verify them.
- **Fix:** Add `JWT_SECRET=<random-string-at-least-32-chars>` to your `.env` file. Ensure the same secret is used across all environments that need to verify the token. After changing the secret, all previously issued tokens become invalid -- users must re-authenticate.

## Escalation

- If you need to check WordPress roles or capabilities inside middleware, consult the `sage:wp-capabilities` skill for the correct `current_user_can()` patterns and role hierarchy.
- If middleware needs to integrate with WordPress's native cookie-based authentication (for admin or REST API requests), use `add_action`/`add_filter` hooks instead of Acorn middleware.
