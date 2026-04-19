# WordPress Core Tables

Deep reference for using Eloquent models with WordPress core database tables. Loaded on demand from `skills/acorn-eloquent/SKILL.md`.

## When to use

Use Eloquent for **read-only reporting queries** on WP core tables where the query is complex (aggregates, joins, custom grouping). For writing posts, use WP APIs (`wp_insert_post`, `wp_update_post`).

## Table mapping

| WP table | Primary key | Timestamps |
|---|---|---|
| `wp_posts` | `ID` | `post_date` / `post_modified` (not Eloquent timestamps) |
| `wp_postmeta` | `meta_id` | none |
| `wp_terms` | `term_id` | none |
| `wp_term_taxonomy` | `term_taxonomy_id` | none |
| `wp_users` | `ID` | `user_registered` |
| `wp_usermeta` | `umeta_id` | none |

## Canonical model pattern

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class WpPost extends Model
{
    protected $table = 'wp_posts';
    protected $primaryKey = 'ID';
    public $timestamps = false;
    protected $guarded = ['*']; // WP manages all writes

    protected $casts = [
        'post_date'     => 'datetime',
        'post_modified' => 'datetime',
    ];

    public function meta(): \Illuminate\Database\Eloquent\Relations\HasMany
    {
        return $this->hasMany(WpPostMeta::class, 'post_id', 'ID');
    }

    public function scopePublished($query): void
    {
        $query->where('post_status', 'publish')
              ->where('post_type', 'post');
    }
}
```

## WP prefix

If `$wpdb->prefix` is not `wp_`, use a dynamic table name:

```php
protected function getTable(): string
{
    return $GLOBALS['wpdb']->prefix . 'posts';
}
```

## Key pitfalls

- Never call `->save()`, `->create()`, or `->delete()` on WP core table models — use WP APIs instead.
- `post_date` is stored in local timezone; `post_date_gmt` is UTC. Decide which to use consistently.
- Acorn's `DB::table('wp_posts')` is also valid for simple queries without a Model class.
- Run `\DB::enableQueryLog()` and `\DB::getQueryLog()` to debug slow queries in development.
