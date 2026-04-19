Deep reference for N+1 query detection and remediation in Sage/Eloquent. Loaded on demand from `skills/wp-performance/SKILL.md`.

# N+1 Query Detection and Remediation

N+1 queries are the most common performance killer in Eloquent-backed Sage themes; detecting and eliminating them requires eager loading and Query Monitor.

## What Is N+1?

An N+1 pattern executes one query to retrieve a list of items (1 query),
then one additional query per item to retrieve related data (N queries).
The total query count grows linearly with the result set size.

## Detection with Query Monitor

In the QM Database Queries panel:
1. Sort by **Duplicates** — identical queries run multiple times are N+1 candidates
2. Switch to **Queries by Component** — the component with a high query count is the source
3. Enable `$wpdb->show_errors()` temporarily in development to surface query errors

In ACF block `with()` methods, N+1 is especially common when a block renders
per post in a loop and each iteration calls `get_field('relationship')`.

## Eloquent: preventLazyLoading

Enable lazy loading prevention in development to surface N+1 at runtime:

```php
// app/Providers/AppServiceProvider.php
use Illuminate\Database\Eloquent\Model;

public function boot(): void
{
    Model::preventLazyLoading(! app()->isProduction());
}
```

When an N+1 pattern is triggered, Laravel throws a `LazyLoadingViolationException`
instead of silently executing extra queries.

## Fixing with Eager Loading

```php
// Bad — 1 query for posts + N queries for authors (N+1)
$posts = Post::all();
foreach ($posts as $post) {
    echo $post->author->name;
}

// Good — 2 queries total (eager loading)
$posts = Post::with('author')->get();
```

For nested relationships:

```php
$posts = Post::with(['author', 'author.avatar', 'tags'])->get();
```

## N+1 in Native WP: get_posts() + meta

When querying by postmeta inside a loop:

```php
// Bad — 1 query for post IDs + N queries for meta
$postIds = get_posts(['fields' => 'ids', 'posts_per_page' => 20]);
foreach ($postIds as $id) {
    $price = get_post_meta($id, 'price', true);  // 1 query each
}

// Good — preload all meta in one query using update_post_meta_cache
update_post_meta_cache($postIds);  // fetches all meta for all IDs in one query
foreach ($postIds as $id) {
    $price = get_post_meta($id, 'price', true);  // served from cache
}
```

## Batching with IN Queries

For custom `$wpdb` queries that reference IDs from a prior query:

```php
// Bad — one query per ID
foreach ($postIds as $id) {
    $row = $wpdb->get_row($wpdb->prepare(
        "SELECT * FROM {$wpdb->postmeta} WHERE post_id = %d AND meta_key = 'price'",
        $id
    ));
}

// Good — single IN query
$placeholders = implode(',', array_fill(0, count($postIds), '%d'));
$rows = $wpdb->get_results(
    $wpdb->prepare(
        "SELECT post_id, meta_value FROM {$wpdb->postmeta}
         WHERE post_id IN ($placeholders) AND meta_key = 'price'",
        ...$postIds
    )
);
$metaByPost = array_column($rows, 'meta_value', 'post_id');
```

## ACF Block `with()` — Common N+1 Pattern

```php
// Bad — runs one get_field() per block per page
public function with(): array
{
    return [
        'related' => get_field('related_posts'),  // fetches relationship ACF field
    ];
}
```

For blocks that appear multiple times on a page, cache the related data in a
static variable or a Service class:

```php
public function with(): array
{
    static $cache = [];
    $blockId = $this->block->id ?? 'default';

    if (! isset($cache[$blockId])) {
        $cache[$blockId] = get_field('related_posts') ?: [];
    }

    return ['related' => $cache[$blockId]];
}
```

## Common N+1 Patterns in Sage

| Location | Pattern | Fix |
|---|---|---|
| View Composer | Loop over posts, access relationship inside loop | `->with('relation')` in query |
| ACF Block `with()` | `get_field('relationship')` per block render | Cache in static or Service |
| Blade `@foreach` | `get_post_meta()` inside loop | `update_post_meta_cache($ids)` before loop |
| Eloquent scope | Accessing `$model->relation` without `->with()` | Add eager load to query |
| REST API endpoint | Query per resource item in `get_items()` | Batch with `get_posts(['post__in' => $ids])` |

## Verification

After fixing an N+1, confirm with QM:
1. Reload the page with the fixed code
2. Check QM Queries panel — duplicate query count should drop to 0 or near 0
3. Verify the total query count has decreased proportionally
4. Run `Model::preventLazyLoading()` check — no `LazyLoadingViolationException` thrown
