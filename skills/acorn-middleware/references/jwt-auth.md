Deep reference for JWT authentication middleware. Loaded on demand from `skills/acorn-middleware/SKILL.md`.

# JWT Authentication in Acorn

JWT (JSON Web Tokens) is the preferred authentication approach for Acorn API routes. WordPress has its own cookie-based auth for the admin and REST API, but Acorn routes need a stateless auth mechanism.

## Install the JWT Package

```bash
lando theme-composer require firebase/php-jwt
```

## Environment Variables

Add to your `.env`:

```
JWT_SECRET=your-random-secret-key-at-least-32-chars
JWT_TTL=3600
JWT_REFRESH_TTL=604800
```

- `JWT_SECRET`: Must be at least 32 random characters. Never hardcode. All tokens become invalid if changed.
- `JWT_TTL`: Access token lifetime in seconds (default 3600 = 1 hour).
- `JWT_REFRESH_TTL`: Refresh token lifetime in seconds (default 604800 = 7 days).

## Create the JWT Service

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

## Register the Service

```php
// In ThemeServiceProvider::register() or a dedicated AuthServiceProvider
$this->app->singleton(JwtService::class, fn () => new JwtService(
    secret: config('app.key', env('JWT_SECRET', '')),
    ttl: (int) env('JWT_TTL', 3600),
    refreshTtl: (int) env('JWT_REFRESH_TTL', 604800),
));
```

## Create the JWT Middleware

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

## Auth Controller with Login and Refresh Endpoints

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

## Route Registration

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

## Token Flow (Client-side)

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

## Key Rules

- Always call `wp_set_current_user()` in auth middleware so `current_user_can()` works downstream.
- Use `$request->bearerToken()` — never manually parse the `Authorization` header.
- Apply `throttle:5,1` to login and `throttle:10,1` to refresh to prevent brute-force abuse.
- Changing `JWT_SECRET` invalidates all issued tokens — users must re-authenticate.
- Distinguish `access` vs `refresh` token types via the `type` claim to prevent token substitution.
