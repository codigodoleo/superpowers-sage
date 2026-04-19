# Troubleshooting — Acorn Routes

## Problem: 404 Not Found on a defined route

**Cause:** Route not registered. The `RouteServiceProvider` is not loading the route file, or the provider is not listed in `config/app.php`.

**Fix:**
1. Confirm `RouteServiceProvider::class` is in the `providers` array in `config/app.php`.
2. Run `lando acorn route:list` — if the route does not appear, the file is not being loaded.
3. Clear any stale route cache: `lando acorn route:clear`.
4. Check the route file path passed to `$this->app->basePath('routes/web.php')` is correct.

## Problem: Route conflicts with WordPress rewrite rules

**Cause:** The Acorn route path collides with a WordPress page slug or permalink. For example, if a WordPress page exists at `/about` and you define `Route::get('/about', ...)`, Acorn takes precedence — the WP page becomes unreachable.

**Fix:**
- Prefix all Acorn routes with a dedicated namespace: `/app/`, `/portal/`, `/api/`.
- Run `lando acorn route:list` and compare paths against your WordPress permalink structure.
- Never define Acorn routes at paths occupied by WordPress pages or posts.

**Check for conflicts:**

```bash
lando acorn route:list
# Cross-reference output with WordPress content at Settings > Permalinks
```

## Problem: Middleware not firing on a route

**Cause:** Either the middleware is not registered (no alias in `app/Http/Kernel.php`), or `app/Http/Kernel.php` does not exist.

**Fix:**
1. Verify `app/Http/Kernel.php` exists with `protected $middlewareAliases = [...]`.
2. Confirm the alias matches what you're using in the route: `'auth.jwt'` must be declared as `'auth.jwt' => AuthenticateJwt::class`.
3. Run `lando acorn route:list` and inspect the `Middleware` column for the route.

## Problem: Route model binding returns null / no 404

**Cause:** `SubstituteBindings` middleware is missing from the middleware group, so binding is never attempted.

**Fix:** Ensure `SubstituteBindings::class` is in the `web` or `api` group in `app/Http/Kernel.php`.

## Problem: Route caching breaks routes

**Cause:** Route cache is stale, or routes include closures which cannot be cached.

**Fix:**
- During development: `lando acorn route:clear`
- Production: `lando acorn route:cache` after deploying; ensure all routes use controller classes (no closures)

## Problem: Named route helper `route('name')` throws exception

**Cause:** The route name is not registered, or the route cache is stale.

**Fix:**
1. Run `lando acorn route:list --name=route.name` to confirm the name exists.
2. If using route caching, run `lando acorn route:clear && lando acorn route:cache`.

## Problem: `current_user_can()` returns false inside a controller

**Cause:** WordPress has not been told which user is making the request. Acorn routes are outside WP's request cycle — `wp_set_current_user()` is not called automatically.

**Fix:** Call `wp_set_current_user(get_current_user_id())` in auth middleware after resolving the authenticated user. Do not put it in controller constructors — the container resolves constructors before the auth middleware runs.

## Problem: CSRF token mismatch on POST/PUT/DELETE routes

**Cause:** The route is in `routes/web.php` (using the `web` middleware group which includes CSRF verification) but no token is included in the request.

**Fix:**
- For HTML forms: include `@csrf` in the Blade template.
- For API/AJAX calls: send `X-CSRF-TOKEN` header or use the `api` middleware group (stateless, no CSRF).
- For webhooks: exclude the webhook route from CSRF in `app/Http/Middleware/VerifyCsrfToken.php`.

## Problem: 405 Method Not Allowed

**Cause:** Sending a GET to a POST-only route or vice versa.

**Fix:** Run `lando acorn route:list --path=your-path` to check the allowed HTTP methods.

## Best Practices Checklist

- [ ] All routes defined in `routes/web.php` or `routes/api.php`, not `functions.php`
- [ ] `RouteServiceProvider` registered in `config/app.php`
- [ ] All routes have a `->name()`
- [ ] No closures in route files (prevents route caching)
- [ ] Acorn routes use a dedicated prefix that won't collide with WP content URLs
- [ ] `app/Http/Kernel.php` exists with middleware aliases
- [ ] Route model binding uses `SubstituteBindings` in the middleware group
- [ ] `wp_set_current_user()` called in auth middleware, not controller constructors

## Escalation

- If a route needs to integrate with the WordPress REST API (`/wp-json/`), use `register_rest_route()` — see `superpowers-sage:wp-rest-api`.
- If middleware auth is not working, see `superpowers-sage:acorn-middleware` for Kernel setup, JWT, and custom guards.
- If Eloquent models are not resolving in route model binding, see `superpowers-sage:acorn-eloquent` for model configuration.
