# Middleware Groups for Routes

How to assign, group, and parameterize middleware on Acorn routes. For creating custom middleware classes, see `superpowers-sage:acorn-middleware`.

## Applying Middleware to Individual Routes

```php
// Single named middleware
Route::get('/dashboard', [DashboardController::class, 'index'])
    ->middleware('auth')
    ->name('dashboard');

// Multiple middleware
Route::post('/reports/export', ExportReportController::class)
    ->middleware(['auth', 'throttle:10,1'])
    ->name('reports.export');
```

## Route Groups with Middleware

Group related routes under shared middleware and a prefix to avoid repetition:

```php
Route::prefix('admin')->middleware('auth')->group(function () {
    Route::get('/reports', [ReportController::class, 'index'])->name('admin.reports');
    Route::get('/reports/{report}', [ReportController::class, 'show'])->name('admin.reports.show');
    Route::post('/reports/export', [ReportController::class, 'export'])->name('admin.reports.export');
});
```

Combine prefix, name prefix, and middleware:

```php
Route::prefix('portal')
    ->name('portal.')
    ->middleware(['auth', 'verified'])
    ->group(function () {
        Route::get('/', [PortalController::class, 'index'])->name('index');
        Route::resource('tickets', TicketController::class);
        Route::post('/tickets/{ticket}/reply', [TicketReplyController::class, 'store'])
            ->name('tickets.reply');
    });
```

## Resource Routes with Middleware

Apply middleware to only some actions on a resource:

```php
// Protect all write actions; allow index and show publicly
Route::resource('projects', ProjectController::class)
    ->middleware('auth')
    ->except(['index', 'show']);
```

## Named Middleware Aliases

Register aliases in `app/Http/Kernel.php` to keep route files readable:

```php
// app/Http/Kernel.php
protected $middlewareAliases = [
    'auth'     => \Illuminate\Auth\Middleware\Authenticate::class,
    'throttle' => \Illuminate\Routing\Middleware\ThrottleRequests::class,
    'role'     => \App\Http\Middleware\CheckRole::class,
    'verified' => \Illuminate\Auth\Middleware\EnsureEmailIsVerified::class,
];
```

Then use aliases in routes:

```php
Route::post('/admin/users', [UserController::class, 'store'])
    ->middleware('role:admin');

Route::put('/articles/{article}', [ArticleController::class, 'update'])
    ->middleware('throttle:10,1');
```

## Middleware Groups (web / api)

The `web` and `api` groups are defined in `app/Http/Kernel.php`. Routes loaded via `RouteServiceProvider` automatically receive their respective group:

```php
// app/Http/Kernel.php
protected $middlewareGroups = [
    'web' => [
        \Illuminate\Cookie\Middleware\EncryptCookies::class,
        \Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse::class,
        \Illuminate\Session\Middleware\StartSession::class,
        \Illuminate\View\Middleware\ShareErrorsFromSession::class,
        \App\Http\Middleware\VerifyCsrfToken::class,
    ],

    'api' => [
        \Illuminate\Routing\Middleware\ThrottleRequests::class.':api',
        \Illuminate\Routing\Middleware\SubstituteBindings::class,
    ],
];
```

**`SubstituteBindings` must be in the middleware group or stack for route model binding to work.** It is included in both `web` and `api` groups by default.

## Controller Middleware

Apply middleware inside the controller constructor for action-level granularity:

```php
class ProjectController extends Controller
{
    public function __construct()
    {
        // Require auth for all actions except listing and viewing
        $this->middleware('auth')->except(['index', 'show']);

        // Rate-limit write actions
        $this->middleware('throttle:60,1')->only(['store', 'update']);
    }
}
```

## Middleware Parameters

Pass colon-separated parameters after the middleware name:

```php
// throttle:max_attempts,decay_minutes
Route::get('/feed', [FeedController::class, 'index'])->middleware('throttle:30,1');

// role:role_name[,role_name...]
Route::delete('/users/{user}', [UserController::class, 'destroy'])->middleware('role:admin');
```

In the middleware `handle()` method, parameters arrive after `$next`:

```php
public function handle(Request $request, Closure $next, string $role): Response
{
    // ...
}
```

## Ordering Matters

In a middleware stack, order determines execution sequence:

1. Auth middleware first (reject unauthenticated early)
2. Role/capability checks second (user must be known)
3. `EnsureJsonResponse` first in API groups (before auth, so errors are JSON too)
4. `SubstituteBindings` last in the group (so route model binding runs after auth)

## Common Mistakes

| Mistake | Fix |
|---|---|
| `middleware()` not taking effect | Confirm `app/Http/Kernel.php` exists and the alias is registered |
| `current_user_can()` returns false inside middleware | Call `wp_set_current_user($user->ID)` in auth middleware after resolving the user |
| Route model binding not resolving | Verify `SubstituteBindings` is in the middleware group |
| Using `add_action` for route auth | Use `Route::middleware('auth')` — WP hooks do not run on Acorn routes |
