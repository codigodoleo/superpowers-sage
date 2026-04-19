# Models

Eloquent model class configuration — table mapping, fillable fields, casts, and WP-aware defaults for custom and core tables.

## Creating a Model

```bash
lando acorn make:model Testimonial
lando acorn make:model EventLog --migration
lando acorn make:model Submission --migration --factory --seed
```

## Model Structure

Models live in `app/Models/`. Every model for a custom table should declare `$table` explicitly with the WordPress prefix.

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Testimonial extends Model
{
    use HasFactory;

    protected $table = 'wp_testimonials';

    protected $fillable = [
        'author_name',
        'company',
        'body',
        'rating',
        'is_featured',
        'published_at',
    ];

    protected $casts = [
        'rating'       => 'integer',
        'is_featured'  => 'boolean',
        'published_at' => 'datetime',
        'metadata'     => 'array',
    ];
}
```

## Key Model Properties

| Property | Purpose | Example |
|---|---|---|
| `$table` | Explicit table name (include WP prefix) | `'wp_testimonials'` |
| `$fillable` | Mass-assignable attributes | `['name', 'email', 'body']` |
| `$guarded` | Non-mass-assignable (alternative to `$fillable`) | `['id']` |
| `$casts` | Attribute type casting | `['is_active' => 'boolean']` |
| `$timestamps` | Whether `created_at`/`updated_at` exist | `true` (default) |
| `$primaryKey` | Custom primary key column | `'testimonial_id'` |
| `$keyType` | Type of the primary key | `'int'` (default) |
| `$incrementing` | Whether the key is auto-incrementing | `true` (default) |

## Custom Table — Full Example

For a completely custom table with no WP connection:

```php
class Project extends Model
{
    use HasFactory;

    protected $table      = 'wp_projects';
    protected $primaryKey = 'project_id';
    public $timestamps    = true; // has created_at / updated_at

    protected $fillable = [
        'title',
        'slug',
        'description',
        'status',
        'published_at',
    ];

    protected $casts = [
        'published_at' => 'datetime',
        'metadata'     => 'array',
        'is_featured'  => 'boolean',
    ];
}
```

## WP Core Table Mirror — Read-Only

For querying WP core tables in relationships, set `$timestamps = false` and the correct `$primaryKey`:

```php
class WpPost extends Model
{
    protected $table      = 'wp_posts';
    protected $primaryKey = 'ID';
    public $timestamps    = false;
    public $keyType       = 'int';
    public $incrementing  = true;

    // No $fillable — read-only; WP manages all writes
    public $guarded = ['*'];

    public static function boot(): void
    {
        parent::boot();

        static::creating(fn () => throw new \RuntimeException(
            'Use wp_insert_post() — Eloquent writing to wp_posts bypasses hooks.',
        ));

        static::updating(fn () => throw new \RuntimeException(
            'Use wp_update_post() — Eloquent writing to wp_posts bypasses hooks.',
        ));
    }

    public function meta(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(WpPostMeta::class, 'post_id', 'ID');
    }
}
```

**WP core table primary keys:**

| Table | Primary key |
|---|---|
| `wp_posts` | `ID` |
| `wp_users` | `ID` |
| `wp_terms` | `term_id` |
| `wp_comments` | `comment_ID` |
| `wp_postmeta` | `meta_id` |

## Accessors and Mutators

Use the `Attribute` class (Laravel 10+ syntax):

```php
use Illuminate\Database\Eloquent\Casts\Attribute;

protected function authorName(): Attribute
{
    return Attribute::make(
        get: fn (string $value) => ucwords($value),
        set: fn (string $value) => strtolower($value),
    );
}

protected function excerpt(): Attribute
{
    return Attribute::make(
        get: fn (mixed $value, array $attributes) => str(
            $attributes['body']
        )->limit(150)->toString(),
    );
}
```

Append computed attributes to JSON/array output:

```php
protected $appends = ['excerpt'];
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| Missing `$table` declaration | Always set `$table` explicitly — avoid Eloquent's table name guessing |
| Forgetting WP prefix on custom tables | Include `wp_` in `$table` and in migration `Schema::create()` |
| Not declaring `$timestamps = false` on WP core tables | WP tables have no `created_at`/`updated_at` — Eloquent will error |
| Wrong `$primaryKey` on WP tables | `wp_posts` and `wp_users` use `ID` (uppercase), not `id` |
| `$guarded = []` instead of `$fillable` | Explicitly declare `$fillable` — never open all attributes to mass assignment |
| Old `getNameAttribute()` accessor syntax | Use `Attribute::make()` — Laravel 10+ syntax only |
