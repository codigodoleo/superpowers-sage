Deep reference for Laravel Auth custom guards in Acorn/WordPress. Loaded on demand from `skills/acorn-middleware/SKILL.md`.

# Custom Guards in Acorn

For deeper integration with Laravel's auth system, create a WordPress-aware guard. This lets you use Laravel's `Auth` facade and `auth()` helper with WordPress users — enabling `auth()->check()`, `auth()->user()`, `auth()->id()` throughout your controllers and middleware.

## The Laravel Guard Contract

A guard must implement `Illuminate\Contracts\Auth\Guard`:

- `check(): bool` — is a user authenticated?
- `guest(): bool` — opposite of `check()`
- `user(): mixed` — returns the authenticated user (or null)
- `id(): mixed` — returns the user's identifier
- `validate(array $credentials): bool` — validates credentials without persisting
- `hasUser(): bool` — whether a user has been set
- `setUser($user): static` — manually set the authenticated user

## WordPressGuard Implementation

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

## Register the Guard in a Provider

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

Register this provider in your `config/app.php` providers array (or Acorn's equivalent bootstrapping).

## Configure in config/auth.php

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

## How Acorn Resolves Guards

Acorn uses Laravel's `AuthManager` under the hood. When you call `auth('wordpress')` or `Auth::guard('wordpress')`, the manager looks up the driver registered via `Auth::extend()`. The guard factory closure receives the app container, guard name, and the config array from `config/auth.php`.

The guard is resolved fresh per-request because it holds a reference to the current `Request` instance.

## Using the Guard in Controllers and Middleware

```php
$user = auth()->user();       // Returns WP_User or null
$userId = auth()->id();       // Returns user ID or null
if (auth()->check()) { ... }  // Is the user authenticated?
if (auth()->guest()) { ... }  // Is the user a guest?

// Named guard — use if you have multiple guards
auth('wordpress')->check();
```

## Combining with Middleware

You can simplify `AuthenticateJwt` middleware when a custom guard is registered:

```php
public function handle(Request $request, Closure $next): Response
{
    if (auth('wordpress')->guest()) {
        return response()->json(['error' => 'Unauthorized.'], 401);
    }

    return $next($request);
}
```

This delegates token extraction and user resolution to the guard, keeping the middleware thin.

## Notes

- The guard caches `$this->user` after the first resolution — subsequent calls within the same request skip JWT decoding.
- `validate()` is for credential checking without persisting state (e.g., API key verification). It does not set `$this->user`.
- If WordPress cookie auth is sufficient for your use case, you can implement a `WordPressCookieGuard` that reads from `wp_get_current_user()` instead of parsing JWT.
