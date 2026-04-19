Deep reference for Laravel Queue via Acorn in Sage/WordPress. Loaded on demand from `skills/acorn-queues/SKILL.md`.

# Laravel Queue via Acorn

## Queue Configuration

Create or edit `config/queue.php` in the theme directory:

```php
<?php

return [
    'default' => env('QUEUE_CONNECTION', 'database'),

    'connections' => [
        'sync' => [
            'driver' => 'sync',
        ],

        'database' => [
            'driver'      => 'database',
            'table'       => 'jobs',
            'queue'       => 'default',
            'retry_after' => 90,
            'after_commit' => false,
        ],

        'redis' => [
            'driver'      => 'redis',
            'connection'  => 'queue',
            'queue'       => env('REDIS_QUEUE', 'default'),
            'retry_after' => 90,
            'block_for'   => null,
            'after_commit' => false,
        ],
    ],

    'batching' => [
        'database' => env('DB_CONNECTION', 'mysql'),
        'table'    => 'job_batches',
    ],

    'failed' => [
        'driver'   => env('QUEUE_FAILED_DRIVER', 'database-uuids'),
        'database' => env('DB_CONNECTION', 'mysql'),
        'table'    => 'failed_jobs',
    ],
];
```

## Drivers

| Driver | When to use | Setup |
|---|---|---|
| `sync` | Development — jobs run inline, no background processing | Default, no extra setup |
| `database` | Production without Redis — reliable, no extra infrastructure | Needs migration (see below) |
| `redis` | Production with Redis — fastest, recommended for high-volume | See `redis-driver.md` reference |

Set the driver in `.env`:

```env
QUEUE_CONNECTION=database
```

## Database Driver Setup

Create migrations for jobs and failed jobs tables:

```bash
lando acorn queue:table
lando acorn queue:failed-table
lando acorn queue:batches-table   # only if using job batching
lando acorn migrate
```

This creates `jobs`, `failed_jobs`, and optionally `job_batches` tables in the WordPress database.

## Creating Jobs

```bash
# Via the helper script (validates PascalCase, checks lando availability)
bash skills/acorn-queues/scripts/create-job.sh ProcessImage

# Or directly via lando
lando acorn make:job ProcessImage
```

## Dispatching Jobs

```php
use App\Jobs\ProcessImage;
use App\Jobs\SyncExternalContent;

// Basic dispatch — runs on the default queue
ProcessImage::dispatch(attachmentId: $attachmentId);

// Delayed dispatch — wait 5 minutes before processing
SyncExternalContent::dispatch(sourceId: $sourceId)
    ->delay(now()->addMinutes(5));

// Dispatch to a specific queue
ProcessImage::dispatch(attachmentId: $attachmentId)
    ->onQueue('media');

// Conditional dispatch
ProcessImage::dispatchIf(
    condition: wp_attachment_is_image($attachmentId),
    attachmentId: $attachmentId,
);

// Dispatch from a WordPress hook
add_action('add_attachment', function (int $attachmentId): void {
    if (wp_attachment_is_image($attachmentId)) {
        ProcessImage::dispatch(attachmentId: $attachmentId);
    }
});
```

## Running the Queue Worker via Lando

```bash
# Use the helper script
bash skills/acorn-queues/scripts/run-worker.sh
bash skills/acorn-queues/scripts/run-worker.sh emails

# Or run directly
lando acorn queue:work

# With priority queues (high first, then default)
lando acorn queue:work --queue=high,default,emails

# Process a single job and stop (cron-based processing)
lando acorn queue:work --once

# Stop after current job finishes (graceful restart)
lando acorn queue:restart
```

**Production:** Run the queue worker as a persistent process using Supervisor or systemd. For simpler setups, use `--once` with a system cron job.

## Job Chaining — Sequential Execution

Jobs run one after another. If any job fails, the rest are skipped.

```php
use Illuminate\Support\Facades\Bus;

Bus::chain([
    new DownloadExternalImages(postId: $postId),
    new ProcessImage(attachmentId: $attachmentId),
    new UpdatePostMeta(postId: $postId, key: 'images_processed', value: true),
])->onQueue('media')->dispatch();
```

## Job Batching — Parallel Execution with Tracking

Jobs run concurrently. Requires the `job_batches` table migration.

```php
use Illuminate\Bus\Batch;
use Illuminate\Support\Facades\Bus;

$jobs = array_map(fn (int $id) => new ProcessImage(attachmentId: $id), $attachmentIds);

Bus::batch($jobs)
    ->then(fn (Batch $batch) => Log::info('All images processed', ['batch_id' => $batch->id]))
    ->catch(fn (Batch $batch, \Throwable $e) => Log::error('Batch failed', ['error' => $e->getMessage()]))
    ->finally(fn (Batch $batch) => Log::info('Batch finished', ['total' => $batch->totalJobs]))
    ->onQueue('media')
    ->dispatch();
```

## Testing Dispatches

```php
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Queue;

// Fake all dispatches
Bus::fake();
do_action('add_attachment', $attachmentId);
Bus::assertDispatched(ProcessImage::class);
Bus::assertDispatchedTimes(ProcessImage::class, times: 1);

// Assert batch
Bus::assertBatched(fn (PendingBatch $batch) =>
    $batch->name === 'weekly-newsletter' && $batch->jobs->count() > 0
);

// Queue facade approach
Queue::fake();
Queue::assertPushed(ProcessImage::class);
Queue::assertPushedOn('media', ProcessImage::class);
```
