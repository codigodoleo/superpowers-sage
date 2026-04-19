Deep reference for Acorn Redis cache tags and group invalidation. Loaded on demand from `skills/acorn-redis/SKILL.md`.

# Redis Cache Tags

Cache tags group related entries for atomic invalidation — the recommended pattern for post-type and taxonomy caches in Sage.

## Using Cache Tags

Tags group related entries for bulk invalidation. Requires a tag-aware driver (Redis supports this).

```php
// Store with tags
Cache::tags(['posts', 'homepage'])->remember('homepage:grid', now()->addHour(), fn () =>
    get_posts(['posts_per_page' => 12])
);

Cache::tags(['posts', 'archive'])->put('archive:page:1', $archiveData, now()->addMinutes(30));

// Flush everything tagged "posts" — clears both homepage and archive caches
Cache::tags(['posts'])->flush();

// Flush only homepage-related caches
Cache::tags(['homepage'])->flush();
```

## Tag-Based Invalidation on WordPress Hooks

Invalidate tags in a service provider or `save_post` / `edited_term` hook:

```php
add_action('save_post', function (int $postId): void {
    Cache::tags(['posts'])->flush();
});

add_action('edited_term', function (int $termId, int $ttId, string $taxonomy): void {
    Cache::tags([$taxonomy])->flush();
}, 10, 3);
```

## Taxonomy Cache Pattern

Tag cache entries by post type and taxonomy for fine-grained invalidation:

```php
// Cache by post type tag
Cache::tags(['product', 'catalog'])->remember('catalog:page:1', now()->addMinutes(30), fn () =>
    get_posts(['post_type' => 'product', 'numberposts' => 24])
);

// Invalidate only product caches when a product is saved
add_action('save_post_product', function (): void {
    Cache::tags(['product'])->flush();
});
```

## Important Notes

- Cache tags require a tag-aware store. Redis supports tags; the `file` and `database` drivers do not.
- Flushing a tag does not delete individual keys — it invalidates the tag index, causing tagged entries to miss on next read.
- Use narrow tags (e.g., `product` not `posts`) to avoid over-invalidating unrelated caches.
