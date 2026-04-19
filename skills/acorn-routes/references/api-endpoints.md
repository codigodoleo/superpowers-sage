# API Endpoints

Building JSON API endpoints with Acorn routes, including rate limiting, token auth, and proper response handling.

## Basic Setup

API routes live in `routes/api.php` and are automatically:
- Prefixed with `/api` (configurable)
- Assigned the `api` middleware group (stateless — no session)
- Rate-limited via the `throttle` middleware

```php
// routes/api.php
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\ProjectController;

Route::apiResource('projects', ProjectController::class);

Route::get('/events/upcoming', [\App\Http\Controllers\Api\EventController::class, 'upcoming'])
    ->name('api.events.upcoming');
```

## API Controller Structure

API controllers return JSON. Omit `create` and `edit` HTML methods:

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
            ->paginate(perPage: $request->integer('per_page', 15));

        return ProjectResource::collection($projects);
    }

    public function show(Project $project): ProjectResource
    {
        return new ProjectResource($project->load('tasks'));
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title'  => ['required', 'string', 'max:255'],
            'status' => ['required', 'in:active,archived'],
        ]);

        $project = Project::create($validated);

        return response()->json(new ProjectResource($project), 201);
    }

    public function destroy(Project $project): JsonResponse
    {
        $project->delete();

        return response()->json(status: 204);
    }
}
```

## API Resources (JSON Shape)

Use `JsonResource` to control what the API exposes — never return raw Eloquent models:

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
            'id'          => $this->id,
            'title'       => $this->title,
            'slug'        => $this->slug,
            'status'      => $this->status,
            'tasks'       => TaskResource::collection($this->whenLoaded('tasks')),
            'created_at'  => $this->created_at->toIso8601String(),
        ];
    }
}
```

## Accept: application/json Detection

Some middleware and exceptions only format as JSON when the request has the correct `Accept` header. Force JSON in API groups:

```php
// app/Http/Middleware/EnsureJsonResponse.php
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

Register in `app/Http/Kernel.php` under the `api` group:

```php
'api' => [
    \App\Http\Middleware\EnsureJsonResponse::class,
    \Illuminate\Routing\Middleware\ThrottleRequests::class.':api',
    \Illuminate\Routing\Middleware\SubstituteBindings::class,
],
```

## Rate Limiting

Limit requests per time window with `throttle:attempts,minutes`:

```php
// 60 requests per minute per IP
Route::middleware('throttle:60,1')->group(function () {
    Route::apiResource('projects', ProjectController::class);
});

// Strict limit for auth endpoints
Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:5,1');
```

Custom rate limiters (registered in a service provider):

```php
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Support\Facades\RateLimiter;

RateLimiter::for('api', function (Request $request) {
    return Limit::perMinute(60)->by($request->user()?->id ?: $request->ip());
});
```

## Token Authentication for API Routes

For simple API token auth without a full OAuth server:

```php
// app/Http/Middleware/AuthenticateApiToken.php
namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AuthenticateApiToken
{
    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->bearerToken();

        if (! $token || $token !== config('app.api_token')) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        return $next($request);
    }
}
```

Register and apply:

```php
// routes/api.php
Route::middleware(['auth.token', 'throttle:60,1'])->group(function () {
    Route::apiResource('projects', ProjectController::class);
});
```

## Versioned API

Configure versioning in `RouteServiceProvider`:

```php
public function boot(): void
{
    $this->routes(function () {
        Route::middleware('web')
            ->group($this->app->basePath('routes/web.php'));

        Route::middleware('api')
            ->prefix('api/v1')
            ->name('api.v1.')
            ->group($this->app->basePath('routes/api.php'));
    });
}
```

## Webhook Endpoints

Webhooks are incoming POST requests from external services. They typically bypass CSRF and verify via a signature:

```php
// routes/api.php
Route::post('/webhooks/stripe', [\App\Http\Controllers\Api\StripeWebhookController::class, 'handle'])
    ->middleware('verify.stripe.signature')
    ->name('api.webhooks.stripe');
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| HTML error page returned for API 404/500 | Add `EnsureJsonResponse` middleware to the `api` group |
| No `Accept: application/json` from client | Clients must send this header, or use `EnsureJsonResponse` middleware to force it |
| Returning raw model `->toJson()` | Always use API Resources to control output shape |
| CSRF token mismatch on API routes | API routes use `api` middleware group (stateless) — no CSRF; `web` routes require CSRF |
| Route not found at `/api/projects` | Confirm `RouteServiceProvider` sets prefix `api` and the `api.php` route file is loaded |
