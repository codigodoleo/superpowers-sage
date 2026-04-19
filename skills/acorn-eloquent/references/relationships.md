# Relationships

Eloquent relationship patterns for Acorn, including WP-specific Post→Meta and Term→Taxonomy associations.

## Quick Reference

| Type | Methods | Use case |
|---|---|---|
| One-to-one | `hasOne()` / `belongsTo()` | Testimonial → featured image record |
| One-to-many | `hasMany()` / `belongsTo()` | User → many testimonials |
| Many-to-many | `belongsToMany()` | Testimonials → many tags |
| Has-many-through | `hasManyThrough()` | User → tag associations through testimonials |
| Polymorphic | `morphTo()` / `morphMany()` | Event log entries for multiple model types |

## Standard Relationships

```php
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

    public function responses(): HasMany
    {
        return $this->hasMany(TestimonialResponse::class);
    }

    public function tags(): BelongsToMany
    {
        return $this->belongsToMany(
            Tag::class,
            'wp_testimonial_tag', // pivot table
            'testimonial_id',     // FK on pivot referencing this model
            'tag_id',             // FK on pivot referencing Tag
        );
    }
}
```

## WordPress-Specific: Post → PostMeta (hasMany)

Mirror `wp_posts` → `wp_postmeta` relationship:

```php
class WpPost extends Model
{
    protected $table      = 'wp_posts';
    protected $primaryKey = 'ID';
    public $timestamps    = false;

    public function meta(): HasMany
    {
        // FK on wp_postmeta is 'post_id'; local key is 'ID'
        return $this->hasMany(WpPostMeta::class, 'post_id', 'ID');
    }
}

class WpPostMeta extends Model
{
    protected $table      = 'wp_postmeta';
    protected $primaryKey = 'meta_id';
    public $timestamps    = false;

    public function post(): BelongsTo
    {
        return $this->belongsTo(WpPost::class, 'post_id', 'ID');
    }
}
```

**Read-only rule:** Never use Eloquent to write to `wp_posts` or `wp_postmeta` — use `wp_insert_post()` / `update_post_meta()` so WordPress hooks fire.

## WordPress-Specific: Term → TermMeta (hasMany)

```php
class WpTerm extends Model
{
    protected $table      = 'wp_terms';
    protected $primaryKey = 'term_id';
    public $timestamps    = false;

    public function meta(): HasMany
    {
        return $this->hasMany(WpTermMeta::class, 'term_id', 'term_id');
    }
}
```

## Wrapping wp_users for Relationships

Use `wp_users` as a read-oriented model to support custom model relationships:

```php
class User extends Model
{
    protected $table      = 'wp_users';
    protected $primaryKey = 'ID';
    public $timestamps    = false;

    public function testimonials(): HasMany
    {
        return $this->hasMany(Testimonial::class, 'user_id', 'ID');
    }
}
```

## Polymorphic Relationships

For event logs that can belong to multiple model types:

```php
// app/Models/EventLog.php
class EventLog extends Model
{
    protected $table = 'wp_event_logs';

    protected $fillable = ['action', 'description', 'loggable_type', 'loggable_id'];

    public function loggable(): \Illuminate\Database\Eloquent\Relations\MorphTo
    {
        return $this->morphTo();
    }
}

// Any model can attach event logs
class Testimonial extends Model
{
    public function eventLogs(): \Illuminate\Database\Eloquent\Relations\MorphMany
    {
        return $this->morphMany(EventLog::class, 'loggable');
    }
}
```

Migration for polymorphic table:

```php
$table->string('loggable_type');
$table->unsignedBigInteger('loggable_id');
$table->index(['loggable_type', 'loggable_id']);
```

## Eager Loading

Always eager load when iterating to avoid N+1 queries:

```php
// N+1 (bad) — runs 1 + N queries
$testimonials = Testimonial::all();
foreach ($testimonials as $t) {
    echo $t->author->name; // new query each iteration
}

// Eager load (good) — runs 2 queries total
$testimonials = Testimonial::with('author')->get();

// Multiple relationships
$testimonials = Testimonial::with(['author', 'tags', 'responses'])->get();

// Nested eager loading
$testimonials = Testimonial::with('author.profile')->get();
```

Load after retrieval:

```php
$testimonial->load('tags', 'responses');
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| Using Eloquent to write to WP core tables | Use WP functions so hooks fire: `wp_insert_post()`, `update_post_meta()` |
| Wrong FK column order in `hasMany` / `belongsTo` | `hasMany(Related::class, 'fk_on_related', 'local_key')` |
| Wrong primary key on WP models | `wp_posts` → `ID`, `wp_terms` → `term_id`, `wp_comments` → `comment_ID` |
| Lazy loading in loops | Use `Testimonial::with('author')->get()` or `->load()` |
| Polymorphic index missing | Always add `index(['loggable_type', 'loggable_id'])` on morph tables |
