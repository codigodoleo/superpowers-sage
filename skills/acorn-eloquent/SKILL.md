---
name: superpowers-sage:acorn-eloquent
description: Eloquent ORM in WordPress via Acorn; models, migrations, relationships, factories, and query scopes for custom tables alongside WordPress's native tables
user-invocable: false
---

# Eloquent ORM in WordPress via Acorn

## When to Use Eloquent vs WordPress Functions

Acorn brings Laravel's Eloquent ORM into WordPress, but WordPress has its own database layer. Use the right tool for the job:

| Use case | Use Eloquent | Use WordPress functions |
|---|---|---|
| Custom tables (event logs, testimonials, form entries) | Yes | No |
| Complex joins across custom tables | Yes | No |
| Relationships between custom models | Yes | No |
| Post types, taxonomies, menus | No | Yes (`WP_Query`, `get_posts`) |
| User management, roles, capabilities | No | Yes (`wp_insert_user`, `get_userdata`) |
| Options, transients | No | Yes (`get_option`, `get_transient`) |
| Complex queries on `wp_posts` that `WP_Query` can't express | Read-only, carefully | Prefer `WP_Query` first |

**Rule of thumb:** WordPress-managed content goes through WordPress functions so hooks fire correctly. Custom application data that WordPress doesn't know about goes through Eloquent.

## Models

### Creating a Model

```bash
lando acorn make:model Testimonial
lando acorn make:model EventLog --migration
lando acorn make:model Submission --migration --factory --seed
```

### Model Location and Structure

Models live in `app/Models/`. Every model for a custom table should declare `$table` explicitly with the WordPress prefix accounted for.

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
        'rating' => 'integer',
        'is_featured' => 'boolean',
        'published_at' => 'datetime',
        'metadata' => 'array',
    ];
}
```

### Key Model Properties

| Property | Purpose | Example |
|---|---|---|
| `$table` | Explicit table name (include WP prefix) | `'wp_testimonials'` |
| `$fillable` | Mass-assignable attributes | `['name', 'email', 'body']` |
| `$guarded` | Non-mass-assignable (alternative to `$fillable`) | `['id']` |
| `$casts` | Attribute type casting | `['is_active' => 'boolean']` |
| `$connection` | Database connection name | `'mysql'` (rarely needed) |
| `$timestamps` | Whether `created_at`/`updated_at` exist | `true` (default) |
| `$primaryKey` | Custom primary key column | `'testimonial_id'` |

## Migrations

### Creating Migrations

```bash
lando acorn make:migration create_testimonials_table
lando acorn make:migration add_rating_to_testimonials_table
lando acorn make:migration create_event_logs_table
```

### Migration Structure

WordPress uses `$wpdb->prefix` (typically `wp_`). Account for this in your migrations:

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wp_testimonials', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('user_id')->nullable();
            $table->string('author_name');
            $table->string('company')->nullable();
            $table->text('body');
            $table->unsignedTinyInteger('rating')->default(5);
            $table->boolean('is_featured')->default(false);
            $table->timestamp('published_at')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamps();

            $table->index('user_id');
            $table->index('is_featured');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wp_testimonials');
    }
};
```

### Migration Commands

| Command | Purpose |
|---|---|
| `lando acorn migrate` | Run all pending migrations |
| `lando acorn migrate --seed` | Run migrations and seed |
| `lando acorn migrate:rollback` | Rollback last batch |
| `lando acorn migrate:rollback --step=2` | Rollback last 2 batches |
| `lando acorn migrate:reset` | Rollback all migrations |
| `lando acorn migrate:refresh` | Rollback all and re-run |
| `lando acorn migrate:status` | Show migration status |

**Important:** The migrations table itself (`wp_migrations`) lives alongside WordPress tables. Acorn handles this automatically.

## Relationships

### Defining Relationships

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class Testimonial extends Model
{
    protected $table = 'wp_testimonials';

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function tags(): BelongsToMany
    {
        return $this->belongsToMany(
            Tag::class,
            'wp_testimonial_tag',
            'testimonial_id',
            'tag_id',
        );
    }

    public function responses(): HasMany
    {
        return $this->hasMany(TestimonialResponse::class);
    }
}
```

### Wrapping WordPress Users

You can create an Eloquent model that reads from `wp_users` for use in relationships. Keep it read-oriented — user mutations should go through WordPress functions so hooks fire.

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class User extends Model
{
    protected $table = 'wp_users';
    protected $primaryKey = 'ID';
    public $timestamps = false;

    public function testimonials(): HasMany
    {
        return $this->hasMany(Testimonial::class, 'user_id', 'ID');
    }
}
```

### Relationship Types Quick Reference

| Type | Method | Use case |
|---|---|---|
| One-to-one | `hasOne()` / `belongsTo()` | Testimonial has one featured image record |
| One-to-many | `hasMany()` / `belongsTo()` | User has many testimonials |
| Many-to-many | `belongsToMany()` | Testimonials have many tags |
| Has-many-through | `hasManyThrough()` | User has many tag associations through testimonials |
| Polymorphic | `morphTo()` / `morphMany()` | Event log entries for multiple model types |

### Polymorphic Example — Event Logs

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class EventLog extends Model
{
    protected $table = 'wp_event_logs';

    protected $fillable = [
        'action',
        'description',
        'loggable_type',
        'loggable_id',
    ];

    public function loggable(): MorphTo
    {
        return $this->morphTo();
    }
}
```

Any model can then declare:

```php
public function eventLogs(): MorphMany
{
    return $this->morphMany(EventLog::class, 'loggable');
}
```

## Query Scopes

### Local Scopes

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

Usage:

```php
// Chain scopes fluently
$testimonials = Testimonial::published()
    ->featured()
    ->minRating(4)
    ->recent(60)
    ->with('author')
    ->latest('published_at')
    ->get();
```

### Global Scopes

Apply a constraint to every query on a model:

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

Register in the model:

```php
protected static function booted(): void
{
    static::addGlobalScope(new PublishedScope);
}
```

Remove when needed: `Testimonial::withoutGlobalScope(PublishedScope::class)->get();`

## Factories

### Creating a Factory

```bash
lando acorn make:factory TestimonialFactory
```

### Factory Definition

```php
<?php

namespace Database\Factories;

use App\Models\Testimonial;
use Illuminate\Database\Eloquent\Factories\Factory;

class TestimonialFactory extends Factory
{
    protected $model = Testimonial::class;

    public function definition(): array
    {
        return [
            'author_name' => fake()->name(),
            'company' => fake()->company(),
            'body' => fake()->paragraphs(2, asText: true),
            'rating' => fake()->numberBetween(1, 5),
            'is_featured' => fake()->boolean(20),
            'published_at' => fake()->optional(0.8)->dateTimeBetween('-1 year'),
            'metadata' => [
                'source' => fake()->randomElement(['website', 'email', 'social']),
            ],
        ];
    }

    public function featured(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_featured' => true,
            'rating' => fake()->numberBetween(4, 5),
        ]);
    }

    public function unpublished(): static
    {
        return $this->state(fn (array $attributes) => [
            'published_at' => null,
        ]);
    }
}
```

Usage:

```php
Testimonial::factory()->count(10)->create();
Testimonial::factory()->featured()->count(3)->create();
Testimonial::factory()->unpublished()->create();
```

## Seeders

### Creating a Seeder

```bash
lando acorn make:seeder TestimonialSeeder
```

### Seeder Definition

```php
<?php

namespace Database\Seeders;

use App\Models\Testimonial;
use Illuminate\Database\Seeder;

class TestimonialSeeder extends Seeder
{
    public function run(): void
    {
        Testimonial::factory()
            ->count(20)
            ->create();

        Testimonial::factory()
            ->featured()
            ->count(5)
            ->create();
    }
}
```

### Running Seeders

| Command | Purpose |
|---|---|
| `lando acorn db:seed` | Run `DatabaseSeeder` |
| `lando acorn db:seed --class=TestimonialSeeder` | Run a specific seeder |
| `lando acorn migrate --seed` | Migrate then seed |
| `lando acorn migrate:refresh --seed` | Reset, re-migrate, then seed |

## Accessors and Mutators

Use the `Attribute` class (Laravel 10+ syntax):

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Model;

class Testimonial extends Model
{
    protected $table = 'wp_testimonials';

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

    protected function starDisplay(): Attribute
    {
        return Attribute::make(
            get: fn (mixed $value, array $attributes) => str_repeat(
                '★',
                $attributes['rating'],
            ),
        );
    }
}
```

Append computed attributes to JSON/array output:

```php
protected $appends = ['excerpt', 'star_display'];
```

## Interacting with WordPress Tables

You can create Eloquent models for WordPress core tables (`wp_posts`, `wp_users`, `wp_postmeta`, etc.). This is useful for complex queries that `WP_Query` cannot express efficiently — joins across meta tables, aggregations, subqueries.

**Rules for WordPress table models:**

1. **Read-only by default.** Never insert, update, or delete WordPress-managed rows through Eloquent — this bypasses hooks (`save_post`, `wp_insert_user`, cache invalidation).
2. **Use for relationships only.** The primary use case is `belongsTo` / `hasMany` from custom models to WP tables.
3. **Disable timestamps.** WordPress tables do not have `created_at` / `updated_at` columns.
4. **Mind the primary key.** `wp_posts` uses `ID` (uppercase), `wp_users` uses `ID`, `wp_terms` uses `term_id`.

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class WpPost extends Model
{
    protected $table = 'wp_posts';
    protected $primaryKey = 'ID';
    public $timestamps = false;

    // Read-only guard
    public static function boot(): void
    {
        parent::boot();

        static::creating(fn () => throw new \RuntimeException(
            'Use wp_insert_post() instead of Eloquent for creating posts.',
        ));

        static::updating(fn () => throw new \RuntimeException(
            'Use wp_update_post() instead of Eloquent for updating posts.',
        ));
    }

    public function meta(): HasMany
    {
        return $this->hasMany(WpPostMeta::class, 'post_id', 'ID');
    }
}
```

## Best Practices

| Practice | Why |
|---|---|
| Keep models lean | Models define structure, relationships, scopes, and accessors — not business logic |
| Use scopes instead of raw `where` chains | Readable, reusable, testable query constraints |
| Eager load relationships | Prevent N+1 queries: `Testimonial::with('author')->get()` |
| Never bypass WordPress hooks for WP tables | Inserting into `wp_posts` via Eloquent skips `save_post`, cache, search indexing |
| Declare `$table` explicitly | Avoids surprises with table name guessing and WordPress prefixes |
| Use `$fillable` over `$guarded = []` | Explicit is safer — only allow known attributes for mass assignment |
| Run migrations in deployment order | `lando acorn migrate` before seeding or going live |
| Use factories for test data, not manual inserts | Consistent, repeatable, works with Pest/PHPUnit |
| Prefer `$casts` over manual type conversion | Ensures consistent types across reads and writes |
| Scope names should read naturally | `->published()->featured()` reads like English |

## Common Mistakes

| Mistake | Correct approach |
|---|---|
| Using Eloquent to create/update posts | Use `wp_insert_post()` / `wp_update_post()` so hooks fire |
| Forgetting the `wp_` prefix on custom tables | Always include the prefix in `$table` and migration table names |
| Not declaring `$timestamps = false` on WP tables | WordPress tables lack `created_at`/`updated_at` — Eloquent will error |
| Raw `DB::table()` queries scattered in controllers | Wrap queries in model scopes or repository methods |
| Lazy loading relationships in loops | Use `::with()` or `->load()` to eager load |
| Using old-style `getNameAttribute` accessors | Use `Attribute::make()` — the modern Laravel 10+ syntax |
| Forgetting to set `$primaryKey` on WP models | `wp_posts` and `wp_users` use `ID`, not `id` |
| Mass assignment without `$fillable` | Always define `$fillable` to prevent unintended attribute writes |

## Verification

- Run `lando acorn migrate:status` and confirm all migrations show as "Ran".
- Use `lando acorn tinker` to execute a test query (e.g., `App\Models\Testimonial::first()`) and verify the model returns data from the correct table.
- Verify relationships by eager loading: `App\Models\Testimonial::with('author')->first()` should return related data without errors.

## Failure modes

### Problem: Table not found (SQLSTATE[42S02])
- **Cause:** The migration for the table has not been run, or the table name in the model `$table` property does not match the migration.
- **Fix:** Run `lando acorn migrate` to execute pending migrations. Verify the `$table` property on the model includes the WordPress prefix (e.g., `'wp_testimonials'`) and matches the table name in the migration's `Schema::create()` call.

### Problem: Mass assignment exception (Add [field] to fillable property)
- **Cause:** The `$fillable` array on the model does not include the attribute being set via `Model::create()` or `$model->fill()`.
- **Fix:** Add the missing attribute to the `$fillable` array on the model class. Never use `$guarded = []` as a workaround -- explicitly list allowed attributes.

## Escalation

- If queries are slow due to N+1 problems (many individual queries instead of batch loading), consult the `sage:wp-performance` skill for eager loading strategies and query optimization.
- If you need to query WordPress core tables (`wp_posts`, `wp_users`), prefer WordPress functions (`WP_Query`, `get_posts`) over Eloquent to ensure hooks fire correctly.
