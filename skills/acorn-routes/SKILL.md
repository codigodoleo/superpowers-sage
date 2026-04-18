---
name: superpowers-sage:acorn-routes
description: Routes, controllers, route model binding, middleware groups, and API endpoints using Acorn's Laravel routing inside WordPress
user-invocable: false
---

# Acorn Routes

## When to use

- Application endpoints not mapped to WordPress content (forms, APIs, dashboards, webhooks)
- REST-style JSON endpoints where you want Laravel middleware, DI, and controller organization
- Frontend routes that render Blade views with Laravel Livewire
- Endpoints that need middleware chains (auth, rate-limit, CSRF)
- Route model binding with Eloquent models

## When NOT to use

- Permalink-based content routing (posts, pages, archives) — WordPress handles this natively via template hierarchy
- Gutenberg-internal REST endpoints — those MUST stay on `register_rest_route()` for block editor compatibility
- Admin-area menus and settings pages — use `add_menu_page()` / `add_submenu_page()`
- URLs expected to participate in canonical redirects and SEO plugin hooks — WP rewrite rules are better wired

## Prerequisites

- Acorn installed in the theme
- `RouteServiceProvider` registered in `config/app.php`
- `routes/web.php` and/or `routes/api.php` present in the theme

## How Routing Works in Acorn

Acorn brings Laravel's full routing system into WordPress. Routes are defined in `routes/web.php` and `routes/api.php` inside your Sage theme, loaded by a `RouteServiceProvider`, and dispatched through Laravel's router.

Acorn routes coexist with WordPress's own routing and rewrite system. WordPress still handles permalink-based routing for posts, pages, archives, and taxonomies. Acorn routes handle custom application endpoints -- forms, API calls, dashboard pages, webhooks, and anything that doesn't map to WordPress content types.

**Prefer Acorn routes over `register_rest_route()`.** The Laravel router gives you middleware, route model binding, dependency injection, and controller organization. The WordPress REST API is still available for Gutenberg internals, but application-level endpoints belong in Acorn routes.

## RouteServiceProvider Setup

Create a `RouteServiceProvider` in your theme to load route files:

```php
// app/Providers/RouteServiceProvider.php
namespace App\Providers;

use Illuminate\Foundation\Support\Providers\RouteServiceProvider as ServiceProvider;
use Illuminate\Support\Facades\Route;

class RouteServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        $this->routes(function () {
            Route::middleware('web')
                ->group($this->app->basePath('routes/web.php'));

            Route::middleware('api')
                ->prefix('api')
                ->group($this->app->basePath('routes/api.php'));
        });
    }
}
```

Register the provider in `config/app.php`:

```php
'providers' => [
    // ...
    App\Providers\RouteServiceProvider::class,
],
```

Create the route files:

```
routes/
  web.php
  api.php
```

Both files should return route definitions. Start with an empty scaffold:

```php
// routes/web.php
<?php

use Illuminate\Support\Facades\Route;

// Web routes here
```

```php
// routes/api.php
<?php

use Illuminate\Support\Facades\Route;

// API routes here
```

## Route Definitions

### Basic Routes

```php
// routes/web.php
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ContactController;
use App\Http\Controllers\DashboardController;

// Simple controller actions
Route::get('/dashboard', [DashboardController::class, 'index'])->name('dashboard');
Route::get('/dashboard/settings', [DashboardController::class, 'settings'])->name('dashboard.settings');
Route::post('/dashboard/settings', [DashboardController::class, 'updateSettings'])->name('dashboard.settings.update');

// All HTTP verbs
Route::get('/contact', [ContactController::class, 'show'])->name('contact.show');
Route::post('/contact', [ContactController::class, 'submit'])->name('contact.submit');
Route::put('/profile/{user}', [ProfileController::class, 'update'])->name('profile.update');
Route::delete('/account/{user}', [AccountController::class, 'destroy'])->name('account.destroy');
```

### Resource Routes

```php
use App\Http\Controllers\ProjectController;
use App\Http\Controllers\EventController;

// Full resource (index, create, store, show, edit, update, destroy)
Route::resource('projects', ProjectController::class);

// Partial resource -- only the routes you need
Route::resource('events', EventController::class)->only(['index', 'show']);
Route::resource('comments', CommentController::class)->except(['destroy']);
```

### Route Groups

```php
// Prefix + middleware group
Route::prefix('admin')->middleware('auth')->group(function () {
    Route::get('/reports', [ReportController::class, 'index'])->name('admin.reports');
    Route::get('/reports/{report}', [ReportController::class, 'show'])->name('admin.reports.show');
    Route::post('/reports/export', [ReportController::class, 'export'])->name('admin.reports.export');
});

// Named route group with shared prefix
Route::name('client.')->prefix('client')->group(function () {
    Route::get('/invoices', [InvoiceController::class, 'index'])->name('invoices.index');       // client.invoices.index
    Route::get('/invoices/{invoice}', [InvoiceController::class, 'show'])->name('invoices.show'); // client.invoices.show
});
```

### Named Routes

Always name your routes. Use them in Blade templates and redirects instead of hardcoding URLs:

```php
// In routes
Route::get('/projects/{project}', [ProjectController::class, 'show'])->name('projects.show');

// In controllers
return redirect()->route('projects.show', ['project' => $project->id]);

// In Blade templates
<a href="{{ route('projects.show', ['project' => $project->id]) }}">View Project</a>
```

## Controllers

Controllers live in `app/Http/Controllers/`. Create a base controller first:

```php
// app/Http/Controllers/Controller.php
namespace App\Http\Controllers;

use Illuminate\Routing\Controller as BaseController;
use Illuminate\Foundation\Validation\ValidatesRequests;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;

abstract class Controller extends BaseController
{
    use AuthorizesRequests, ValidatesRequests;
}
```

### Standard Controller

```php
// app/Http/Controllers/ProjectController.php
namespace App\Http\Controllers;

use App\Models\Project;
use App\Services\ProjectService;
use Illuminate\Http\Request;
use Illuminate\Contracts\View\View;
use Illuminate\Http\RedirectResponse;

class ProjectController extends Controller
{
    public function __construct(
        protected ProjectService $projects,
    ) {}

    public function index(): View
    {
        return view('projects.index', [
            'projects' => $this->projects->getPublished(),
        ]);
    }

    public function show(Project $project): View
    {
        return view('projects.show', [
            'project' => $project,
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'description' => ['required', 'string'],
            'status' => ['required', 'in:draft,published'],
        ]);

        $project = $this->projects->create($validated);

        return redirect()
            ->route('projects.show', $project)
            ->with('success', 'Project created.');
    }
}
```

### Single-Action Controllers

For routes that do one thing, use an `__invoke` controller:

```php
// app/Http/Controllers/ExportReportController.php
namespace App\Http\Controllers;

use App\Services\ReportService;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ExportReportController extends Controller
{
    public function __invoke(
        Request $request,
        ReportService $reports,
    ): StreamedResponse {
        $format = $request->enum('format', \App\Enums\ExportFormat::class);

        return $reports->export(
            dateFrom: $request->date('from'),
            dateTo: $request->date('to'),
            format: $format,
        );
    }
}
```

```php
// In routes
Route::post('/reports/export', ExportReportController::class)->name('reports.export');
```

### Dependency Injection

The container auto-resolves type-hinted constructor parameters and method parameters. Inject services, the `Request`, or any registered binding:

```php
class SubscriptionController extends Controller
{
    public function __construct(
        protected SubscriptionService $subscriptions,
        protected NewsletterService $newsletter,
    ) {}

    public function subscribe(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'plan' => ['required', 'string'],
        ]);

        $this->subscriptions->create($validated);
        $this->newsletter->addSubscriber($validated['email']);

        return redirect()->route('subscribe.thanks');
    }
}
```

## Route Model Binding

Route model binding automatically resolves Eloquent models from route parameters. This works with Acorn's Eloquent integration (see `sage:acorn-eloquent` for model setup).

### Implicit Binding

When the route parameter name matches the controller's type-hinted variable name, Laravel resolves the model automatically:

```php
// Route
Route::get('/projects/{project}', [ProjectController::class, 'show']);

// Controller -- $project is resolved by ID automatically
public function show(Project $project): View
{
    return view('projects.show', ['project' => $project]);
}
```

### Custom Keys

Resolve by slug or another column instead of the primary key:

```php
// Option 1: In the route definition
Route::get('/projects/{project:slug}', [ProjectController::class, 'show']);

// Option 2: In the model (applies globally)
class Project extends Model
{
    public function getRouteKeyName(): string
    {
        return 'slug';
    }
}
```

### Scoped Bindings

For nested resources, scope the child model to the parent:

```php
Route::get('/projects/{project}/tasks/{task:slug}', function (Project $project, Task $task) {
    // $task is scoped to $project -- returns 404 if the task doesn't belong to the project
    return view('tasks.show', compact('project', 'task'));
})->scopeBindings();
```

### Missing Model Handling

Customize the 404 behavior when a model isn't found:

```php
Route::get('/projects/{project}', [ProjectController::class, 'show'])
    ->missing(fn () => redirect()->route('projects.index')->with('error', 'Project not found.'));
```

## Middleware

Apply middleware to individual routes or groups. For creating custom middleware classes, see `sage:acorn-middleware`.

### Applying Middleware

```php
// Single route
Route::get('/dashboard', [DashboardController::class, 'index'])
    ->middleware('auth')
    ->name('dashboard');

// Route group
Route::middleware(['auth', 'verified'])->group(function () {
    Route::get('/billing', [BillingController::class, 'index'])->name('billing');
    Route::post('/billing/update', [BillingController::class, 'update'])->name('billing.update');
});

// Resource with middleware
Route::resource('projects', ProjectController::class)
    ->middleware('auth')
    ->except(['index', 'show']);
```

### Controller Middleware

Apply middleware inside the controller constructor for fine-grained control:

```php
class ProjectController extends Controller
{
    public function __construct()
    {
        $this->middleware('auth')->except(['index', 'show']);
        $this->middleware('throttle:60,1')->only(['store', 'update']);
    }
}
```

### Middleware Parameters

```php
Route::post('/admin/users', [UserController::class, 'store'])
    ->middleware('role:admin');

Route::put('/articles/{article}', [ArticleController::class, 'update'])
    ->middleware('throttle:10,1'); // 10 requests per minute
```

## API Routes

API routes are defined in `routes/api.php`, automatically prefixed with `/api`, and use the `api` middleware group (stateless, no session).

### Basic API Endpoints

```php
// routes/api.php
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\ProjectController;
use App\Http\Controllers\Api\EventController;

Route::apiResource('projects', ProjectController::class);

Route::get('/events/upcoming', [EventController::class, 'upcoming'])->name('api.events.upcoming');
Route::get('/events/{event}', [EventController::class, 'show'])->name('api.events.show');
```

### Versioned API

```php
// app/Providers/RouteServiceProvider.php
public function boot(): void
{
    $this->routes(function () {
        Route::middleware('web')
            ->group($this->app->basePath('routes/web.php'));

        Route::middleware('api')
            ->prefix('api/v1')
            ->group($this->app->basePath('routes/api.php'));
    });
}
```

Or handle multiple versions:

```php
public function boot(): void
{
    $this->routes(function () {
        Route::middleware('web')
            ->group($this->app->basePath('routes/web.php'));

        Route::middleware('api')
            ->prefix('api/v1')
            ->name('api.v1.')
            ->group($this->app->basePath('routes/api_v1.php'));

        Route::middleware('api')
            ->prefix('api/v2')
            ->name('api.v2.')
            ->group($this->app->basePath('routes/api_v2.php'));
    });
}
```

### API Controller

```php
// app/Http/Controllers/Api/ProjectController.php
namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Project;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ProjectController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $projects = Project::query()
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->input('status')))
            ->when($request->filled('search'), fn ($q) => $q->where('title', 'like', "%{$request->input('search')}%"))
            ->orderByDesc('created_at')
            ->paginate(perPage: $request->integer('per_page', 15));

        return ProjectResource::collection($projects);
    }

    public function show(Project $project): ProjectResource
    {
        return new ProjectResource($project->load('tasks', 'team'));
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'status' => ['required', 'in:active,archived'],
        ]);

        $project = Project::create($validated);

        return response()->json(
            new ProjectResource($project),
            status: 201,
        );
    }

    public function update(Request $request, Project $project): ProjectResource
    {
        $validated = $request->validate([
            'title' => ['sometimes', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'status' => ['sometimes', 'in:active,archived'],
        ]);

        $project->update($validated);

        return new ProjectResource($project);
    }

    public function destroy(Project $project): JsonResponse
    {
        $project->delete();

        return response()->json(status: 204);
    }
}
```

### API Resources

Use API Resources to control JSON output shape:

```php
// app/Http/Resources/ProjectResource.php
namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProjectResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'slug' => $this->slug,
            'description' => $this->description,
            'status' => $this->status,
            'tasks' => TaskResource::collection($this->whenLoaded('tasks')),
            'team' => TeamResource::make($this->whenLoaded('team')),
            'created_at' => $this->created_at->toIso8601String(),
            'updated_at' => $this->updated_at->toIso8601String(),
        ];
    }
}
```

### Webhook Endpoints

For incoming webhooks from external services:

```php
// routes/api.php
Route::post('/webhooks/stripe', [StripeWebhookController::class, 'handle'])
    ->middleware('verify.stripe.signature')
    ->name('api.webhooks.stripe');

Route::post('/webhooks/github', [GithubWebhookController::class, 'handle'])
    ->name('api.webhooks.github');
```

## WordPress Coexistence

Acorn routes and WordPress routes operate on different layers. Keep these rules in mind:

- **Acorn routes take precedence** when they match a URL. If you define `Route::get('/about', ...)`, it will override any WordPress page at `/about/`. Be intentional about URL paths.
- **Avoid collisions** with WordPress slugs. Prefix your Acorn routes (e.g., `/app/dashboard` or `/portal/settings`) to stay clear of WordPress content URLs.
- **WordPress admin** (`/wp-admin/`) and **REST API** (`/wp-json/`) are unaffected by Acorn routes.
- **Permalink flush** is not needed for Acorn routes. They bypass WordPress rewrite rules entirely.

## Best Practices

**Routes are declarations, not implementations.** A route file should read like a table of contents -- endpoint, HTTP verb, controller, name. All logic belongs in controllers and services.

**Keep route files clean:**

```php
// Good -- route file is a clean manifest
Route::get('/projects', [ProjectController::class, 'index'])->name('projects.index');
Route::get('/projects/{project:slug}', [ProjectController::class, 'show'])->name('projects.show');
Route::post('/projects', [ProjectController::class, 'store'])->name('projects.store')->middleware('auth');
```

**Use controllers for everything.** Even simple endpoints benefit from a controller class -- they're testable, injectable, and discoverable.

**Group related routes** to reduce middleware and prefix repetition:

```php
Route::prefix('portal')->name('portal.')->middleware('auth')->group(function () {
    Route::get('/', [PortalController::class, 'index'])->name('index');
    Route::resource('tickets', TicketController::class);
    Route::post('/tickets/{ticket}/reply', [TicketReplyController::class, 'store'])->name('tickets.reply');
});
```

## Anti-patterns

**Business logic in route closures.** Closures cannot be serialized for route caching and encourage spaghetti code:

```php
// Bad -- logic in closure, uncacheable
Route::post('/subscribe', function (Request $request) {
    $email = $request->validate(['email' => 'required|email']);
    $subscriber = Subscriber::create($email);
    Mail::to($subscriber)->send(new WelcomeMail());
    return redirect('/thanks');
});

// Good -- delegate to a controller
Route::post('/subscribe', [SubscriptionController::class, 'store'])->name('subscribe');
```

**Database queries in routes.** Never query the database directly in route definitions.

**Validation in routes.** Validation belongs in controllers (via `$request->validate()`) or in dedicated Form Request classes -- not in route files.

**Unnamed routes.** Always name routes so you can reference them with `route()` instead of hardcoding paths. Unnamed routes break when URLs change.

**Overlapping with WordPress URLs.** Do not define Acorn routes at paths that WordPress content already occupies (e.g., `/blog`, `/about`). Use a dedicated prefix like `/app`, `/portal`, or `/api`.

## Lando Commands

```bash
# List all registered routes with methods, URIs, names, and middleware
lando acorn route:list

# Show routes matching a specific path
lando acorn route:list --path=api

# Show routes for a specific method
lando acorn route:list --method=POST

# Cache routes for production (faster boot, no closure routes allowed)
lando acorn route:cache

# Clear the route cache
lando acorn route:clear
```

**Route caching** (`lando acorn route:cache`) compiles all routes into a single file for faster registration. Use it in production. It requires that all routes use controller classes -- closures cannot be cached. Always run `lando acorn route:clear` during development to avoid stale caches.

## Verification

- Visit the route URL in a browser or with `curl` and confirm the expected response (HTML or JSON) is returned with the correct status code.
- Run `lando acorn route:list` and verify the route appears with the correct HTTP method, URI, controller, name, and middleware.
- Test named routes by calling `route('route.name')` in Tinker or a Blade template and confirming the generated URL is correct.

## Failure modes

### Problem: 404 Not Found on a defined route
- **Cause:** Route not registered -- the `RouteServiceProvider` is not loading the route file, or the provider is not listed in `config/app.php`.
- **Fix:** Confirm `RouteServiceProvider` is registered in `config/app.php` providers array. Run `lando acorn route:list` to verify the route exists. Clear any stale route cache with `lando acorn route:clear`.

### Problem: Route conflicts with WordPress rewrites
- **Cause:** The Acorn route path collides with a WordPress page slug or permalink (e.g., `/about` exists as both an Acorn route and a WP page).
- **Fix:** Prefix Acorn routes with a dedicated namespace like `/app/`, `/portal/`, or `/api/` to avoid overlapping with WordPress content URLs. Never define Acorn routes at paths occupied by WordPress pages or posts.

## Escalation

- If the route needs to integrate with the WordPress REST API (`/wp-json/`), consult the `sage:wp-rest-api` skill for `register_rest_route()` patterns.
- If route middleware is not behaving as expected, consult the `sage:acorn-middleware` skill for Kernel setup and middleware registration.
