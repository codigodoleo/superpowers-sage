Deep reference for troubleshooting Acorn middleware issues. Loaded on demand from `skills/acorn-middleware/SKILL.md`.

# Middleware Troubleshooting

## Verification Checklist

Before escalating, confirm these basics:

- Send a request **without** valid credentials — middleware must return a 401 or 403 JSON response (not pass through).
- Send a request **with** valid credentials (e.g., a valid JWT Bearer token) — middleware must pass through to the controller and return the expected 200 response.
- Run `lando acorn route:list` and verify the middleware alias appears in the middleware column for protected routes.

## Common Failure Modes

### Problem: Middleware not executing (requests pass through unfiltered)

**Cause:** The middleware class is not registered in the HTTP Kernel (`app/Http/Kernel.php`), either as a global middleware, in a middleware group, or as a route middleware alias.

**Fix:** Add the middleware to `$middlewareAliases` in the Kernel for route-level usage, or to `$middlewareGroups` for group-level usage. Confirm the Kernel class exists at `app/Http/Kernel.php` and is being used by Acorn.

### Problem: JWT secret missing or invalid (all tokens rejected)

**Cause:** The `JWT_SECRET` environment variable is not set in `.env`, or the secret used to sign tokens differs from the one used to verify them.

**Fix:** Add `JWT_SECRET=<random-string-at-least-32-chars>` to your `.env` file. Ensure the same secret is used across all environments that need to verify the token. After changing the secret, all previously issued tokens become invalid — users must re-authenticate.

### Problem: `current_user_can()` returns false inside controllers after JWT auth

**Cause:** The JWT middleware authenticates via token but doesn't call `wp_set_current_user()`, so WordPress doesn't know who the current user is.

**Fix:** In `AuthenticateJwt::handle()`, call `wp_set_current_user($user->ID)` after resolving the user from the token payload.

### Problem: Using Laravel's built-in `auth` middleware throws "unauthenticated" even with a valid token

**Cause:** Laravel's default `Authenticate` middleware expects a configured guard that can resolve users from the session or token. Without a registered guard (e.g., `wordpress`), it falls through.

**Fix:** Create a custom guard (see `references/custom-guards.md`) and register it in `config/auth.php`, or use `auth.jwt` middleware alias instead of Laravel's built-in `auth`.

### Problem: Middleware group applied but only some routes are protected

**Cause:** Routes outside the `Route::middleware('group')->group(...)` closure are not protected.

**Fix:** Ensure all routes that should be protected are nested inside the middleware group closure. Run `lando acorn route:list` to inspect per-route middleware.

### Problem: `ThrottleRequests` throws a `RuntimeException` about cache store

**Cause:** Acorn's cache driver is not configured or the default driver is not supported.

**Fix:** Configure a supported cache driver in `.env` (`CACHE_DRIVER=file` is a safe default for most setups).

### Problem: CORS headers missing on API responses

**Cause:** `HandleCors::class` is not in global middleware, or `config/cors.php` paths don't match the route prefix.

**Fix:** Add `\Illuminate\Http\Middleware\HandleCors::class` to `$middleware` (global) in `Kernel.php`. Ensure `config/cors.php` paths include `api/*` or the correct prefix. Run `lando acorn config:cache` to refresh config.

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

## Escalation

- If you need to check WordPress roles or capabilities inside middleware, consult the `sage:wp-capabilities` skill for the correct `current_user_can()` patterns and role hierarchy.
- If middleware needs to integrate with WordPress's native cookie-based authentication (for admin or REST API requests), use `add_action`/`add_filter` hooks instead of Acorn middleware.
