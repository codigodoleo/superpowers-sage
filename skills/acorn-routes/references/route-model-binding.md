# Route Model Binding

Laravel resolves Eloquent models from route parameters automatically. This requires Acorn's Eloquent integration — see `superpowers-sage:acorn-eloquent` for model setup.

## Implicit Binding

When the route parameter name matches the type-hinted variable name in the controller, Laravel fetches the model by primary key and injects it. Returns 404 automatically if not found.

```php
// Route
Route::get('/projects/{project}', [ProjectController::class, 'show']);

// Controller — $project resolved from {project} segment by ID
public function show(Project $project): View
{
    return view('projects.show', ['project' => $project]);
}
```

## Custom Route Key (slug or other column)

### Per-route override

```php
// Resolve by slug for this route only
Route::get('/projects/{project:slug}', [ProjectController::class, 'show']);
```

### Model-level default

```php
class Project extends Model
{
    public function getRouteKeyName(): string
    {
        return 'slug';
    }
}
```

## Scoped Bindings (Nested Resources)

Scope the child to the parent — Laravel returns 404 if the task doesn't belong to the project:

```php
Route::get('/projects/{project}/tasks/{task:slug}', function (Project $project, Task $task) {
    return view('tasks.show', compact('project', 'task'));
})->scopeBindings();
```

## Missing Model Handling

Customize the 404 response when a model is not found:

```php
Route::get('/projects/{project}', [ProjectController::class, 'show'])
    ->missing(fn () => redirect()->route('projects.index')->with('error', 'Project not found.'));
```

## WordPress Post ID Binding

You can bind WP post IDs by creating an Eloquent model for `wp_posts`:

```php
// app/Models/WpPost.php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class WpPost extends Model
{
    protected $table   = 'wp_posts';
    protected $primaryKey = 'ID';
    public $timestamps = false;
}
```

```php
// Route
Route::get('/portfolio/{wpPost}', [PortfolioController::class, 'show']);

// Controller
public function show(WpPost $wpPost): View
{
    // $wpPost resolved from {wpPost} by primary key (ID)
    return view('portfolio.show', ['post' => $wpPost]);
}
```

**Read-only rule:** Never use Eloquent to mutate WP core table rows — use `wp_update_post()` / `wp_delete_post()` so WordPress hooks fire.

## Explicit Binding (Custom Resolution Logic)

Register explicit bindings in a service provider's `boot()` method:

```php
// app/Providers/RouteServiceProvider.php
public function boot(): void
{
    Route::bind('project', function (string $value) {
        return Project::where('slug', $value)
            ->where('status', 'published')
            ->firstOrFail();
    });

    $this->routes(function () {
        // ...
    });
}
```

## `resolveRouteBinding()` on the Model

Override resolution at the model level for full control:

```php
class Project extends Model
{
    public function resolveRouteBinding(mixed $value, ?string $field = null): ?self
    {
        return $this->where($field ?? 'slug', $value)
                    ->where('status', 'published')
                    ->first();
    }

    public function resolveChildRouteBinding(
        string $childType,
        mixed  $value,
        ?string $field,
    ): ?Model {
        return parent::resolveChildRouteBinding($childType, $value, $field);
    }
}
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| Parameter name doesn't match variable name | `{project}` → `Project $project` (names must match) |
| Using `$id` instead of type-hint | Type-hint the model — implicit binding won't fire without it |
| WP core table `ID` vs `id` | Set `$primaryKey = 'ID'` on models for `wp_posts`, `wp_users` |
| Forgetting `scopeBindings()` | Without it, nested `{task}` is resolved globally, not scoped to `{project}` |
