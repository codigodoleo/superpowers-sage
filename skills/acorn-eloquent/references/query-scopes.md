# Query Scopes

Local and global query scopes, raw queries, and advanced filtering patterns for Eloquent models in Acorn.

## Local Scopes

Local scopes are reusable, chainable query constraints defined on the model. Prefix the method name with `scope`:

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class Testimonial extends Model
{
    protected $table = 'wp_testimonials';

    public function scopePublished(Builder $query): void
    {
        $query->whereNotNull('published_at')
              ->where('published_at', '<=', now());
    }

    public function scopeFeatured(Builder $query): void
    {
        $query->where('is_featured', true);
    }

    public function scopeMinRating(Builder $query, int $rating): void
    {
        $query->where('rating', '>=', $rating);
    }

    public function scopeByCompany(Builder $query, string $company): void
    {
        $query->where('company', $company);
    }

    public function scopeRecent(Builder $query, int $days = 30): void
    {
        $query->where('created_at', '>=', now()->subDays($days));
    }
}
```

Chain scopes fluently — the `scope` prefix is omitted in calls:

```php
$testimonials = Testimonial::published()
    ->featured()
    ->minRating(4)
    ->recent(60)
    ->with('author')
    ->latest('published_at')
    ->get();
```

## Global Scopes

Global scopes apply a constraint to every query on the model automatically.

### Defining a Global Scope

```php
<?php

namespace App\Models\Scopes;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Scope;

class PublishedScope implements Scope
{
    public function apply(Builder $builder, Model $model): void
    {
        $builder->whereNotNull('published_at')
                ->where('published_at', '<=', now());
    }
}
```

### Registering a Global Scope

```php
class Testimonial extends Model
{
    protected static function booted(): void
    {
        static::addGlobalScope(new PublishedScope());
    }
}
```

### Bypassing Global Scopes

```php
// Remove one global scope for this query
Testimonial::withoutGlobalScope(PublishedScope::class)->get();

// Remove all global scopes
Testimonial::withoutGlobalScopes()->get();

// Remove multiple specific scopes
Testimonial::withoutGlobalScopes([PublishedScope::class, ActiveScope::class])->get();
```

## Raw Queries

Avoid raw queries when Eloquent scopes can express the constraint. Use them for aggregations or complex expressions that the query builder cannot represent:

```php
// Raw WHERE clause (use binding to prevent SQL injection)
Testimonial::whereRaw('YEAR(published_at) = ?', [2024])->get();

// Raw SELECT for aggregation
Testimonial::selectRaw('company, COUNT(*) as count, AVG(rating) as avg_rating')
    ->groupBy('company')
    ->orderByDesc('avg_rating')
    ->get();

// DB::select for complex multi-table queries
$results = \Illuminate\Support\Facades\DB::select(
    'SELECT t.*, COUNT(r.id) as response_count
     FROM wp_testimonials t
     LEFT JOIN wp_testimonial_responses r ON r.testimonial_id = t.id
     WHERE t.is_featured = 1
     GROUP BY t.id',
);
```

Always use `?` placeholders or named bindings — never interpolate user input into raw queries.

## Dynamic Scope (Conditional)

Apply scopes conditionally based on request input:

```php
$testimonials = Testimonial::query()
    ->when($request->filled('company'), fn ($q) => $q->byCompany($request->input('company')))
    ->when($request->filled('min_rating'), fn ($q) => $q->minRating((int) $request->input('min_rating')))
    ->when($request->boolean('featured'), fn ($q) => $q->featured())
    ->latest()
    ->paginate(15);
```

## Scope Naming Conventions

Scope names should read like natural English when chained:

```php
Testimonial::published()->featured()->minRating(4)->get();
// Reads: "Published, featured testimonials with at least rating 4"
```

Prefix with the entity name for clarity in large models:

```php
scopePublished()   // not scopeIsPublished or scopeWherePublished
scopeMinRating()   // not scopeRatingAtLeast
scopeByCompany()   // consistent with scopeByAuthor, scopeByTag
```

## Performance Notes

- **Indexes matter more than scopes.** Add database indexes on columns used in frequent scope conditions: `is_featured`, `published_at`, `company`.
- **Avoid global scopes on high-traffic tables.** Every query adds the constraint — ensure the column is indexed.
- **Use `->count()` not `->get()->count()`** — `->count()` runs a `SELECT COUNT(*)`, `->get()->count()` loads all rows.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Forgetting the `scope` prefix | `scopePublished` not `published` — prefix is required |
| Scope without index on the filtered column | Add a DB index on `is_featured`, `published_at`, etc. |
| `->get()` then filter in PHP | Filter in the query with scopes — let the DB do the work |
| Raw query with string interpolation | Always use `?` or named bindings: `whereRaw('col = ?', [$val])` |
| Not escaping `withoutGlobalScope()` in admin context | Be explicit about when you bypass global scopes |
