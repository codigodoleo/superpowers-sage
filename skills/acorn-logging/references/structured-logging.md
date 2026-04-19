Deep reference for Acorn structured logging conventions. Loaded on demand from `skills/acorn-logging/SKILL.md`.

# Structured Logging in Acorn

Context arrays, log correlation IDs, and the structured logging conventions that make logs machine-parseable in Acorn/Sage projects.

## Structured Logging Rules

Always pass context arrays. Never build log messages with concatenation or interpolation.

```php
// Correct
Log::error('User login failed', ['email' => $email, 'ip' => $request->ip()]);

// Wrong — no structured data, harder to search/filter
Log::error("User login failed for {$email} from {$request->ip()}");
```

## Best Practices

1. **Use `daily` in production** — set `LOG_CHANNEL=daily` and configure `days` to auto-rotate
2. **Log actionable information** — include IDs, status codes, durations, not vague descriptions
3. **Use correct levels** — `info` for success paths, `error` for failures, `debug` for dev-only detail
4. **Never log sensitive data** — no passwords, tokens, credit card numbers, or full request bodies with auth headers
5. **Use custom channels** — separate `payments`, `api`, `auth` logs so they are easy to review independently
6. **Pass context arrays** — structured data is searchable and parseable; string interpolation is not
7. **Custom exceptions with properties** — embed context (IDs, codes) as readonly properties on the exception class
8. **Check logs with Lando** — read Acorn logs directly:

```
lando ssh -s appserver -c "tail -f /app/content/themes/{theme}/storage/logs/acorn.log"
```

## Log Correlation IDs

Attach a per-request trace ID so all log entries from a single request are correlated:

```php
// app/Providers/AppServiceProvider.php
public function boot(): void
{
    $traceId = substr(md5(uniqid('', true)), 0, 8);
    Log::withContext(['trace_id' => $traceId]);
}
```

Every subsequent `Log::info()` / `Log::error()` in the same request will include `trace_id` in the context array, making it easy to filter log files by request.

## Exception Handling with Structured Context

Create or edit `app/Exceptions/Handler.php` in your theme:

```php
<?php

namespace App\Exceptions;

use Illuminate\Foundation\Exceptions\Handler as ExceptionHandler;
use Throwable;

class Handler extends ExceptionHandler
{
    protected $dontReport = [
        \Illuminate\Validation\ValidationException::class,
    ];

    public function register(): void
    {
        $this->reportable(function (Throwable $e) {
            // Send to external service, Slack, etc.
        });

        $this->reportable(function (\App\Exceptions\PaymentException $e) {
            Log::channel('payments')->critical($e->getMessage(), [
                'order_id' => $e->orderId,
                'trace' => $e->getTraceAsString(),
            ]);

            return false; // prevent double-reporting
        });
    }
}
```

## Custom Exception Classes

```php
<?php

namespace App\Exceptions;

use RuntimeException;

class PaymentException extends RuntimeException
{
    public function __construct(
        string $message,
        public readonly int $orderId,
        public readonly string $gateway,
        int $code = 0,
        ?\Throwable $previous = null,
    ) {
        parent::__construct($message, $code, $previous);
    }
}
```

Throw it with context:

```php
throw new PaymentException(
    message: 'Gateway returned 502',
    orderId: $order->id,
    gateway: 'stripe',
);
```
