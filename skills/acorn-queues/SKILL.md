---
name: superpowers-sage:acorn-queues
description: Background job processing in WordPress; Laravel queues via Acorn for robust tasks, Action Scheduler for simple recurring tasks, and Redis-backed queue drivers
user-invocable: false
---

# Queues, Jobs, and Background Tasks

## When to Use What

| Criteria | Action Scheduler | Laravel Queue + Job |
|---|---|---|
| **Best for** | Simple recurring tasks, WP-native workflows | Robust async processing, retry logic, heavy computation |
| **Infrastructure** | None — runs on WP cron | Needs queue driver (database or Redis) |
| **Retry/backoff** | Manual | Built-in (`$tries`, `$backoff`, exponential) |
| **Monitoring** | WP Admin > Tools > Scheduled Actions | `lando acorn queue:failed`, logs |
| **Examples** | Daily cleanups, content sync, email digests | Image processing, API syncs, bulk imports, PDF generation |
| **Already available** | Bundled with WooCommerce; standalone via `woocommerce/action-scheduler` | Requires Acorn queue config + worker process |

**Rule of thumb:** Start with Action Scheduler for simple, recurring WordPress tasks. Move to Laravel Queue + Job when you need retries, backoff, job chaining, batching, or processing that could take more than a few seconds.

## Action Scheduler

Action Scheduler is a scalable, traceable job queue for WordPress. It runs on WP cron but processes reliably even under load.

### Installing (if not using WooCommerce)

```bash
lando composer require woocommerce/action-scheduler
```

### Scheduling actions

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

### Handling actions

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

### Preventing duplicate schedules

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

### Monitoring

Navigate to **WP Admin > Tools > Scheduled Actions** to see pending, running, completed, and failed actions. Use groups to filter related actions.

## Laravel Queues in Acorn

### Queue configuration

Create or edit `config/queue.php` in your theme:

```php
<?php

return [
    'default' => env('QUEUE_CONNECTION', 'database'),

    'connections' => [
        'sync' => [
            'driver' => 'sync',
        ],

        'database' => [
            'driver' => 'database',
            'table' => 'jobs',
            'queue' => 'default',
            'retry_after' => 90,
            'after_commit' => false,
        ],

        'redis' => [
            'driver' => 'redis',
            'connection' => 'queue',
            'queue' => env('REDIS_QUEUE', 'default'),
            'retry_after' => 90,
            'block_for' => null,
            'after_commit' => false,
        ],
    ],

    'batching' => [
        'database' => env('DB_CONNECTION', 'mysql'),
        'table' => 'job_batches',
    ],

    'failed' => [
        'driver' => env('QUEUE_FAILED_DRIVER', 'database-uuids'),
        'database' => env('DB_CONNECTION', 'mysql'),
        'table' => 'failed_jobs',
    ],
];
```

### Drivers

| Driver | When to use | Setup |
|---|---|---|
| `sync` | Development — jobs run inline, no background processing | Default, no setup |
| `database` | Production without Redis — reliable, no extra infrastructure | Needs migration (see below) |
| `redis` | Production with Redis — fastest, recommended for high-volume | See `sage:acorn-redis` skill |

Set the driver in `.env`:

```env
QUEUE_CONNECTION=database
```

For Redis:

```env
QUEUE_CONNECTION=redis
REDIS_QUEUE=default
```

### Database driver setup

Create the migration for jobs and failed jobs tables:

```bash
lando acorn queue:table
lando acorn queue:failed-table
lando acorn queue:batches-table   # only if using job batching
lando acorn migrate
```

This creates the `jobs`, `failed_jobs`, and optionally `job_batches` tables in your WordPress database.

### Creating jobs

```bash
lando acorn make:job ProcessImage
lando acorn make:job SyncExternalContent
lando acorn make:job SendEmailCampaign
```

### Job class anatomy

```php
<?php

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class ProcessImage implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /**
     * Maximum number of attempts before marking as failed.
     */
    public int $tries = 3;

    /**
     * Seconds to wait before retrying after failure.
     * Array for exponential backoff: [10, 60, 300] = 10s, 1min, 5min.
     */
    public array $backoff = [10, 60, 300];

    /**
     * Maximum seconds the job can run before timing out.
     */
    public int $timeout = 120;

    /**
     * Number of seconds after which the job's unique lock is released.
     */
    public int $uniqueFor = 3600;

    public function __construct(
        protected readonly int $attachmentId,
        protected readonly string $size = 'large',
    ) {}

    /**
     * The unique ID for preventing duplicate jobs.
     */
    public function uniqueId(): string
    {
        return "process-image-{$this->attachmentId}-{$this->size}";
    }

    public function handle(): void
    {
        $filePath = get_attached_file($this->attachmentId);

        if (! $filePath || ! file_exists($filePath)) {
            Log::warning('ProcessImage: attachment file not found', [
                'attachment_id' => $this->attachmentId,
            ]);
            return;
        }

        Log::info('ProcessImage: starting', [
            'attachment_id' => $this->attachmentId,
            'size' => $this->size,
        ]);

        // Perform the heavy image processing
        $this->optimize($filePath);
        $this->generateWebP($filePath);

        Log::info('ProcessImage: completed', [
            'attachment_id' => $this->attachmentId,
        ]);
    }

    /**
     * Handle a job failure.
     */
    public function failed(?\Throwable $exception): void
    {
        Log::error('ProcessImage: failed permanently', [
            'attachment_id' => $this->attachmentId,
            'error' => $exception?->getMessage(),
        ]);
    }

    private function optimize(string $filePath): void
    {
        // Image optimization logic
    }

    private function generateWebP(string $filePath): void
    {
        // WebP conversion logic
    }
}
```

### Dispatching jobs

```php
use App\Jobs\ProcessImage;
use App\Jobs\SyncExternalContent;
use App\Jobs\SendEmailCampaign;

// Basic dispatch — runs on the default queue
ProcessImage::dispatch(attachmentId: $attachmentId);

// Delayed dispatch — wait 5 minutes before processing
SyncExternalContent::dispatch(sourceId: $sourceId)
    ->delay(now()->addMinutes(5));

// Dispatch to a specific queue
SendEmailCampaign::dispatch(campaignId: $campaignId)
    ->onQueue('emails');

// Dispatch with a condition
ProcessImage::dispatchIf(
    condition: wp_attachment_is_image($attachmentId),
    attachmentId: $attachmentId,
);

// Dispatch from a WordPress hook (in ThemeServiceProvider::boot())
add_action('add_attachment', function (int $attachmentId): void {
    if (wp_attachment_is_image($attachmentId)) {
        ProcessImage::dispatch(attachmentId: $attachmentId);
    }
});
```

### Running the queue worker

```bash
# Process jobs on the default queue
lando acorn queue:work

# Process specific queues with priority (high first, then default)
lando acorn queue:work --queue=high,default,emails

# Limit retries and memory
lando acorn queue:work --tries=3 --memory=256

# Process a single job and stop (useful for cron-based processing)
lando acorn queue:work --once

# Stop the worker gracefully after current job finishes
lando acorn queue:restart
```

**Production:** Run the queue worker as a persistent process using Supervisor, systemd, or a process manager. For simpler setups, use `--once` with WP-Cron or a system cron job.

### Cron-based worker (no persistent process)

If you cannot run a persistent worker, trigger the queue via WP-Cron:

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

## Failed Jobs

```bash
# List all failed jobs
lando acorn queue:failed

# Retry a specific failed job by ID
lando acorn queue:retry <job-id>

# Retry all failed jobs
lando acorn queue:retry all

# Delete a specific failed job
lando acorn queue:forget <job-id>

# Delete all failed jobs
lando acorn queue:flush

# Prune failed jobs older than 48 hours
lando acorn queue:prune-failed --hours=48
```

## Job Chaining and Batching

### Job chaining — sequential execution

Jobs run one after another. If any job fails, the rest are skipped.

```php
use Illuminate\Support\Facades\Bus;
use App\Jobs\DownloadExternalImages;
use App\Jobs\ProcessImage;
use App\Jobs\UpdatePostMeta;

Bus::chain([
    new DownloadExternalImages(postId: $postId),
    new ProcessImage(attachmentId: $attachmentId),
    new UpdatePostMeta(postId: $postId, key: 'images_processed', value: true),
])->onQueue('media')->dispatch();
```

### Job batching — parallel execution with tracking

Jobs run concurrently. You can track progress and react to completion or failure.

**Requires the `job_batches` table migration** (see database driver setup above).

```php
use Illuminate\Bus\Batch;
use Illuminate\Support\Facades\Bus;
use App\Jobs\ProcessImage;

$attachmentIds = get_posts([
    'post_type' => 'attachment',
    'post_mime_type' => 'image',
    'posts_per_page' => -1,
    'fields' => 'ids',
]);

$jobs = array_map(
    fn (int $id) => new ProcessImage(attachmentId: $id),
    $attachmentIds,
);

Bus::batch($jobs)
    ->then(function (Batch $batch): void {
        Log::info('All images processed', ['batch_id' => $batch->id]);
    })
    ->catch(function (Batch $batch, \Throwable $e): void {
        Log::error('Image batch had failures', [
            'batch_id' => $batch->id,
            'failed' => $batch->failedJobs,
        ]);
    })
    ->finally(function (Batch $batch): void {
        Log::info('Image batch finished', [
            'total' => $batch->totalJobs,
            'failed' => $batch->failedJobs,
        ]);
    })
    ->onQueue('media')
    ->dispatch();
```

## Practical WordPress Examples

### Content sync from external API

```php
<?php

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class SyncExternalContent implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable;

    public int $tries = 3;
    public array $backoff = [30, 120, 600];
    public int $timeout = 60;

    public function __construct(
        protected readonly string $endpoint,
        protected readonly string $postType = 'post',
    ) {}

    public function handle(): void
    {
        $response = Http::timeout(30)->get($this->endpoint);

        if ($response->failed()) {
            Log::warning('SyncExternalContent: API request failed', [
                'endpoint' => $this->endpoint,
                'status' => $response->status(),
            ]);
            $this->release(delay: 60);
            return;
        }

        foreach ($response->json('data', []) as $item) {
            $this->upsertPost($item);
        }

        Log::info('SyncExternalContent: completed', [
            'endpoint' => $this->endpoint,
            'count' => count($response->json('data', [])),
        ]);
    }

    private function upsertPost(array $item): void
    {
        $existing = get_posts([
            'post_type' => $this->postType,
            'meta_key' => '_external_id',
            'meta_value' => $item['id'],
            'posts_per_page' => 1,
        ]);

        $postData = [
            'post_type' => $this->postType,
            'post_title' => sanitize_text_field($item['title']),
            'post_content' => wp_kses_post($item['content']),
            'post_status' => 'publish',
        ];

        if (! empty($existing)) {
            $postData['ID'] = $existing[0]->ID;
            wp_update_post($postData);
        } else {
            $postId = wp_insert_post($postData);
            update_post_meta($postId, '_external_id', $item['id']);
        }
    }
}
```

### Email campaign dispatcher

```php
<?php

namespace App\Jobs;

use Illuminate\Bus\Batchable;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Support\Facades\Log;

class SendCampaignEmail implements ShouldQueue
{
    use Batchable, Dispatchable, InteractsWithQueue, Queueable;

    public int $tries = 2;
    public int $backoff = 60;

    public function __construct(
        protected readonly string $email,
        protected readonly string $subject,
        protected readonly string $templateSlug,
        protected readonly array $mergeData = [],
    ) {}

    public function handle(): void
    {
        if ($this->batch()?->cancelled()) {
            return;
        }

        $body = $this->renderTemplate();

        $sent = wp_mail($this->email, $this->subject, $body, [
            'Content-Type: text/html; charset=UTF-8',
        ]);

        if (! $sent) {
            Log::warning('SendCampaignEmail: wp_mail failed', [
                'email' => $this->email,
            ]);
            $this->fail(new \RuntimeException("wp_mail failed for {$this->email}"));
        }
    }

    private function renderTemplate(): string
    {
        return view("emails.{$this->templateSlug}", $this->mergeData)->render();
    }
}
```

Dispatching the campaign as a batch:

```php
use App\Jobs\SendCampaignEmail;
use Illuminate\Support\Facades\Bus;

$subscribers = get_users(['role' => 'subscriber', 'fields' => ['user_email']]);

$jobs = array_map(
    fn ($user) => new SendCampaignEmail(
        email: $user->user_email,
        subject: 'Weekly Newsletter',
        templateSlug: 'weekly-digest',
        mergeData: ['week' => now()->weekOfYear],
    ),
    $subscribers,
);

Bus::batch($jobs)
    ->name('weekly-newsletter')
    ->onQueue('emails')
    ->dispatch();
```

## Testing Jobs

### Faking dispatches

```php
use App\Jobs\ProcessImage;
use App\Jobs\SyncExternalContent;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Queue;

// Fake all job dispatches
Bus::fake();

// Trigger the code that dispatches jobs
do_action('add_attachment', $attachmentId);

// Assert the job was dispatched
Bus::assertDispatched(ProcessImage::class);

// Assert with specific arguments
Bus::assertDispatched(ProcessImage::class, function (ProcessImage $job) use ($attachmentId) {
    return $job->attachmentId === $attachmentId;
});

// Assert a job was NOT dispatched
Bus::assertNotDispatched(SyncExternalContent::class);

// Assert dispatch count
Bus::assertDispatchedTimes(ProcessImage::class, times: 1);
```

### Faking specific jobs

```php
// Only fake specific jobs — others dispatch normally
Bus::fake([ProcessImage::class]);

// Fake with Queue facade instead
Queue::fake();

do_action('add_attachment', $attachmentId);

Queue::assertPushed(ProcessImage::class);
Queue::assertPushedOn('media', ProcessImage::class);
```

### Testing job logic directly

```php
it('syncs external content into WordPress posts', function () {
    Http::fake([
        'https://api.example.com/posts' => Http::response([
            'data' => [
                ['id' => 'ext-1', 'title' => 'Test Post', 'content' => '<p>Hello</p>'],
            ],
        ]),
    ]);

    $job = new SyncExternalContent(
        endpoint: 'https://api.example.com/posts',
        postType: 'post',
    );

    $job->handle();

    $posts = get_posts([
        'meta_key' => '_external_id',
        'meta_value' => 'ext-1',
        'post_type' => 'post',
    ]);

    expect($posts)->toHaveCount(1);
    expect($posts[0]->post_title)->toBe('Test Post');
});
```

### Testing job batches

```php
use Illuminate\Bus\PendingBatch;
use Illuminate\Support\Facades\Bus;

Bus::fake();

// Trigger batch dispatch
$service->sendCampaign($campaignId);

Bus::assertBatched(function (PendingBatch $batch) {
    return $batch->name === 'weekly-newsletter'
        && $batch->jobs->count() > 0;
});
```

## Best Practices

| Practice | Why |
|---|---|
| **Make jobs idempotent** | Jobs may run more than once due to retries. The same input should produce the same result without side effects. |
| **Keep jobs small and focused** | One job = one task. Chain or batch for multi-step workflows. |
| **Use structured logging** | Log with context arrays (`Log::info('msg', ['key' => $val])`) inside `handle()` and `failed()`. |
| **Set `$tries` and `$backoff`** | Never let jobs retry infinitely. Use exponential backoff arrays for external APIs. |
| **Use dedicated queues** | Separate `high`, `default`, `emails`, `media` queues. Process critical queues first. |
| **Pass IDs, not objects** | Pass `$postId` instead of `$post`. Let the job fetch fresh data. Avoids serialization issues and stale data. |
| **Implement `failed()`** | Log or notify on permanent failure so issues are visible. |
| **Use `uniqueId()` for deduplication** | Prevent the same job from being queued multiple times. |
| **Test with `sync` driver in dev** | Set `QUEUE_CONNECTION=sync` locally so jobs run immediately for faster debugging. |
| **Action Scheduler for WP-native tasks** | Use it when you don't need retries/backoff and the task is simple. Avoid over-engineering. |

## Common Mistakes

| Mistake | Correct approach |
|---|---|
| Passing full Eloquent models or WP_Post objects to jobs | Pass the ID and re-fetch in `handle()` |
| Running `queue:work` without `--tries` | Always set `--tries` or define `$tries` on the job class |
| Using `sync` driver in production | Use `database` or `redis` — `sync` blocks the request |
| Forgetting to run migrations for database driver | Run `lando acorn queue:table && lando acorn migrate` |
| Scheduling duplicate recurring Action Scheduler tasks | Check with `as_has_scheduled_action()` before scheduling |
| Putting slow logic in Action Scheduler callbacks | If processing takes > 30s, use a Laravel Job instead |
| No logging inside jobs | Always log start, completion, and failure with context |
| Using `dispatch()` inside `register()` | Dispatch jobs from `boot()` hooks or service methods, never during registration |

## Verification

- Dispatch a test job and confirm it appears in the queue: check the `jobs` table (database driver) or use `lando redis-cli -h cache LLEN queues:default` (Redis driver).
- Run `lando acorn queue:work --once` and confirm the job processes successfully with expected log output.
- After processing, verify the job is removed from the queue and does not appear in `lando acorn queue:failed`.

## Failure modes

### Problem: Jobs dispatched but never processed (sit in queue indefinitely)
- **Cause:** The queue driver is misconfigured -- `QUEUE_CONNECTION` in `.env` does not match an entry in `config/queue.php`, or no worker process is running to consume jobs.
- **Fix:** Verify `QUEUE_CONNECTION` in `.env` matches a valid connection in `config/queue.php` (e.g., `database` or `redis`). Start a worker with `lando acorn queue:work`. For the database driver, ensure migrations have been run (`lando acorn queue:table && lando acorn migrate`).

### Problem: Jobs fail and the `failed_jobs` table does not exist
- **Cause:** The failed jobs migration was never created or run, so Laravel cannot record failures.
- **Fix:** Run `lando acorn queue:failed-table && lando acorn migrate` to create the `failed_jobs` table. Then retry failed jobs with `lando acorn queue:retry all`.

## Escalation

- If using the Redis queue driver and jobs fail with connection errors, consult the `sage:acorn-redis` skill for Redis service configuration and connectivity troubleshooting.
- If jobs need to run on a recurring schedule rather than being dispatched on-demand, consider using Action Scheduler or the Acorn command scheduler instead (see the scheduling section above).
