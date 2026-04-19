<?php

namespace App\Jobs;

use Illuminate\Bus\Batchable;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class {{CLASS_NAME}} implements ShouldQueue
{
    use Batchable, Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /** Maximum attempts before marking as permanently failed. */
    public int $tries = 3;

    /** Exponential backoff in seconds: 30s, 2min, 10min. */
    public array $backoff = [30, 120, 600];

    /** Maximum seconds the job can run before timing out. */
    public int $timeout = 60;

    public function __construct(
        // Pass IDs, not objects — re-fetch fresh data in handle()
        protected readonly int $id,
    ) {}

    public function handle(): void
    {
        // Exit early if the batch has been cancelled
        if ($this->batch()?->cancelled()) {
            return;
        }

        // If this job needs WordPress user context, set it first:
        // wp_set_current_user($this->userId); // add: protected readonly int $userId to constructor

        Log::info('{{CLASS_NAME}}: starting', ['id' => $this->id]);

        // TODO: implement job logic here

        Log::info('{{CLASS_NAME}}: completed', ['id' => $this->id]);
    }

    /**
     * Handle permanent failure (all retries exhausted).
     */
    public function failed(?\Throwable $exception): void
    {
        Log::error('{{CLASS_NAME}}: permanently failed', [
            'id'    => $this->id,
            'error' => $exception?->getMessage(),
        ]);
    }
}
