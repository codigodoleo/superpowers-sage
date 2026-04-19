Deep reference for job design patterns in Acorn/Sage Laravel queues. Loaded on demand from `skills/acorn-queues/SKILL.md`.

# Job Patterns — Idempotency, Chunking, Retries, Unique Jobs

## Idempotency

Jobs may run more than once due to retries, worker restarts, or duplicate dispatches. Design every job so the same input always produces the same result without harmful side effects.

**Pattern: check-then-act**

```php
public function handle(): void
{
    // Guard: skip if already processed
    if (get_post_meta($this->postId, '_sync_completed', true)) {
        return;
    }

    // Perform the work
    $this->syncPost();

    // Mark as done (idempotency flag)
    update_post_meta($this->postId, '_sync_completed', '1');
}
```

**Pattern: upsert instead of insert**

```php
private function upsertPost(array $item): void
{
    $existing = get_posts([
        'post_type'      => $this->postType,
        'meta_key'       => '_external_id',
        'meta_value'     => $item['id'],
        'posts_per_page' => 1,
    ]);

    $postData = [
        'post_type'    => $this->postType,
        'post_title'   => sanitize_text_field($item['title']),
        'post_content' => wp_kses_post($item['content']),
        'post_status'  => 'publish',
    ];

    if (! empty($existing)) {
        $postData['ID'] = $existing[0]->ID;
        wp_update_post($postData);
    } else {
        $postId = wp_insert_post($postData);
        update_post_meta($postId, '_external_id', $item['id']);
    }
}
```

## Chunking Large Datasets

Never load thousands of records into a single job — it bloats memory and blocks the worker.

**Pattern: fan-out dispatcher job**

```php
class DispatchImageJobs implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public function handle(): void
    {
        $ids = get_posts([
            'post_type'      => 'attachment',
            'post_mime_type' => 'image',
            'posts_per_page' => -1,
            'fields'         => 'ids',
        ]);

        // Dispatch one small job per item (or chunk)
        foreach (array_chunk($ids, 50) as $chunk) {
            ProcessImageChunk::dispatch($chunk)->onQueue('media');
        }
    }
}
```

**Pattern: chunked batch**

```php
$ids = get_posts(['post_type' => 'attachment', 'fields' => 'ids', 'posts_per_page' => -1]);

$jobs = array_map(fn (int $id) => new ProcessImage(attachmentId: $id), $ids);

Bus::batch($jobs)
    ->name('bulk-image-process')
    ->onQueue('media')
    ->dispatch();
```

## Retries and Backoff

```php
class SyncExternalContent implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /** Maximum attempts before marking as permanently failed. */
    public int $tries = 3;

    /**
     * Seconds to wait before retrying.
     * Array = exponential backoff: 30s, 2min, 10min.
     */
    public array $backoff = [30, 120, 600];

    /** Maximum seconds before timeout. */
    public int $timeout = 60;

    public function handle(): void
    {
        $response = Http::timeout(30)->get($this->endpoint);

        if ($response->failed()) {
            // Manual retry with custom delay
            $this->release(delay: 60);
            return;
        }

        // ... process response
    }

    public function failed(?\Throwable $exception): void
    {
        Log::error('SyncExternalContent permanently failed', [
            'endpoint' => $this->endpoint,
            'error'    => $exception?->getMessage(),
        ]);
    }
}
```

**Backoff options:**
- `public int $backoff = 30;` — fixed 30s between all retries
- `public array $backoff = [10, 60, 300];` — 10s → 1min → 5min (exponential)

## Unique Jobs (ShouldBeUnique)

Prevents the same job being queued more than once (e.g., avoid processing the same image twice).

```php
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;

class ProcessImage implements ShouldQueue, ShouldBeUnique
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $uniqueFor = 3600; // lock held for 1 hour

    public function __construct(
        protected readonly int $attachmentId,
        protected readonly string $size = 'large',
    ) {}

    /**
     * Unique key — same attachment + size = same job identity.
     */
    public function uniqueId(): string
    {
        return "process-image-{$this->attachmentId}-{$this->size}";
    }

    public function handle(): void
    {
        // ...
    }
}
```

Requires the `cache` driver to support atomic locks (`redis` or `database`). Use `$uniqueFor` to limit how long the lock is held in case the job crashes before completing.

## WordPress Context in Jobs

When a job needs to call `current_user_can()` or other WP user functions, WordPress may not have set the current user because jobs run outside of an HTTP request context.

```php
public function handle(): void
{
    // Set WordPress current user so current_user_can() works correctly.
    wp_set_current_user($this->userId);

    if (! current_user_can('edit_posts')) {
        Log::warning('Job skipped — insufficient capability', ['user_id' => $this->userId]);
        return;
    }

    // ... rest of handle
}
```

**Rule:** Any job that calls `current_user_can()`, `get_current_user_id()`, or WP functions that rely on the current user **must** call `wp_set_current_user()` at the top of `handle()`.

## Pass IDs, Not Objects

```php
// Bad — serializes the entire WP_Post, stale on retry
public function __construct(protected readonly \WP_Post $post) {}

// Good — fetch fresh data inside handle()
public function __construct(protected readonly int $postId) {}

public function handle(): void
{
    $post = get_post($this->postId);
    if (! $post) {
        return; // post was deleted since dispatch — idempotent exit
    }
    // ...
}
```
