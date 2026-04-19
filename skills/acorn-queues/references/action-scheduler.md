Deep reference for Action Scheduler in WordPress/Sage/Acorn. Loaded on demand from `skills/acorn-queues/SKILL.md`.

# Action Scheduler — Setup & Recipes

Action Scheduler is a scalable, traceable job queue for WordPress. It runs on WP cron but processes reliably even under load. Bundled with WooCommerce; available standalone via `woocommerce/action-scheduler`.

## Installing (standalone)

```bash
lando composer require woocommerce/action-scheduler
```

## Scheduling Actions

```php
// Single action — runs once at a specific time
as_schedule_single_action(
    timestamp: strtotime('+10 minutes'),
    hook: 'app/sync_external_content',
    args: ['post_id' => 42],
    group: 'content-sync',
);

// Recurring action — runs every interval
as_schedule_recurring_action(
    timestamp: time(),
    interval_in_seconds: HOUR_IN_SECONDS,
    hook: 'app/cleanup_expired_tokens',
    args: [],
    group: 'maintenance',
);

// Async action — runs as soon as possible (next available cron tick)
as_enqueue_async_action(
    hook: 'app/process_form_submission',
    args: ['submission_id' => 15],
    group: 'forms',
);
```

## Handling Actions

Register callbacks in your `ThemeServiceProvider::boot()` or `actions.php`:

```php
// In ThemeServiceProvider::boot()
add_action('app/sync_external_content', function (int $postId): void {
    $this->app->make(\App\Services\ContentSyncService::class)
        ->syncPost($postId);
});

add_action('app/cleanup_expired_tokens', function (): void {
    $this->app->make(\App\Services\TokenService::class)
        ->pruneExpired();
});
```

## Preventing Duplicate Schedules

Check before scheduling recurring actions (typically in a service provider or activation hook):

```php
if (! as_has_scheduled_action('app/cleanup_expired_tokens', [], 'maintenance')) {
    as_schedule_recurring_action(
        timestamp: time(),
        interval_in_seconds: DAY_IN_SECONDS,
        hook: 'app/cleanup_expired_tokens',
        args: [],
        group: 'maintenance',
    );
}
```

Always call `as_has_scheduled_action()` before scheduling a recurring action — duplicate recurring schedules stack up silently and fire multiple times.

## Cron-Based Queue Worker (no persistent process)

If you cannot run a persistent worker, trigger the Laravel queue via Action Scheduler and WP-Cron:

```php
// In ThemeServiceProvider::boot()
add_action('app/process_queue', function (): void {
    \Illuminate\Support\Facades\Artisan::call('queue:work', [
        '--once' => true,
        '--tries' => 3,
    ]);
});

if (! as_has_scheduled_action('app/process_queue')) {
    as_schedule_recurring_action(
        timestamp: time(),
        interval_in_seconds: MINUTE_IN_SECONDS,
        hook: 'app/process_queue',
        group: 'queue',
    );
}
```

## Monitoring

Navigate to **WP Admin > Tools > Scheduled Actions** to see pending, running, completed, and failed actions. Use groups to filter related actions.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Scheduling without `as_has_scheduled_action()` check | Always guard recurring schedules; duplicate actions stack up |
| Putting slow logic (> 30s) in AS callbacks | Dispatch a Laravel Job from the callback instead |
| Using AS for jobs that need retries / backoff | Switch to Laravel Queue Jobs with `$tries` / `$backoff` |
