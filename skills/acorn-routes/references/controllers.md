# Controllers

Controller class structure, constructor injection, and resource/API/invokable controller full examples for Acorn routes.

## Base Controller

Create a base controller before generating resource controllers:

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

## Standard Controller with Constructor Injection

The container auto-resolves type-hinted constructor parameters. Inject services here — not in `handle()` methods.

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
        return view('projects.show', ['project' => $project]);
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'title'       => ['required', 'string', 'max:255'],
            'description' => ['required', 'string'],
            'status'      => ['required', 'in:draft,published'],
        ]);

        $project = $this->projects->create($validated);

        return redirect()
            ->route('projects.show', $project)
            ->with('success', 'Project created.');
    }
}
```

**Note on WordPress user context in constructors:** The container resolves the constructor before the request is dispatched, so `wp_set_current_user()` is not meaningful there. If a controller method needs WP user context (e.g., `current_user_can()`), call `wp_set_current_user(get_current_user_id())` at the top of that method, not in the constructor.

## Resource Controllers

Resource controllers map seven REST-style actions to a single route declaration.

| Method | URI | Action | Route name |
|---|---|---|---|
| GET | `/projects` | `index` | `projects.index` |
| GET | `/projects/create` | `create` | `projects.create` |
| POST | `/projects` | `store` | `projects.store` |
| GET | `/projects/{project}` | `show` | `projects.show` |
| GET | `/projects/{project}/edit` | `edit` | `projects.edit` |
| PUT/PATCH | `/projects/{project}` | `update` | `projects.update` |
| DELETE | `/projects/{project}` | `destroy` | `projects.destroy` |

```php
// routes/web.php
Route::resource('projects', ProjectController::class);

// Partial — only some actions
Route::resource('events', EventController::class)->only(['index', 'show']);
Route::resource('comments', CommentController::class)->except(['destroy']);
```

Generate with the script:

```bash
bash skills/acorn-routes/scripts/create-controller.sh ProjectController --resource
```

## API Resource Controllers

API resources omit the `create` and `edit` HTML form endpoints (they serve JSON only).

```bash
bash skills/acorn-routes/scripts/create-controller.sh ProjectController --api
```

In routes:

```php
Route::apiResource('projects', \App\Http\Controllers\Api\ProjectController::class);
```

## Single-Action (Invokable) Controllers

Use `__invoke` for routes that do exactly one thing. The class itself is the action.

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
            dateTo:   $request->date('to'),
            format:   $format,
        );
    }
}
```

```php
// routes/web.php — no method name needed
Route::post('/reports/export', ExportReportController::class)->name('reports.export');
```

Generate with:

```bash
bash skills/acorn-routes/scripts/create-controller.sh ExportReportController --invokable
```

## Controller Middleware

Apply middleware inside the controller constructor for fine-grained, per-action control:

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

## Dependency Injection in Action Methods

The container resolves type-hinted parameters in both the constructor and individual action methods:

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
            'plan'  => ['required', 'string'],
        ]);

        $this->subscriptions->create($validated);
        $this->newsletter->addSubscriber($validated['email']);

        return redirect()->route('subscribe.thanks');
    }
}
```

## Named Routes in Controllers

Always redirect to named routes — never hardcode paths:

```php
// Good
return redirect()->route('projects.show', ['project' => $project->id]);

// Bad
return redirect('/projects/' . $project->id);
```
