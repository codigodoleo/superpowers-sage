---
name: superpowers-sage:acorn-logging
description: Error handling, logging channels, exception reporting, and structured debugging using Acorn's Laravel logging inside WordPress
user-invocable: false
---

# Error Handling & Logging with Acorn

Acorn uses Laravel's logging system inside WordPress. Logs are configured per-theme in `config/logging.php` and coexist with WordPress's native `debug.log`.

## Configuration

Publish the logging config if it doesn't exist:

```
lando acorn vendor:publish --tag=acorn-logging
```

The config lives at `config/logging.php` in your theme directory:

```php
// config/logging.php
return [
    'default' => env('LOG_CHANNEL', 'stack'),

    'channels' => [
        'stack' => [
            'driver' => 'stack',
            'channels' => ['single'],
            'ignore_exceptions' => false,
        ],

        'single' => [
            'driver' => 'single',
            'path' => storage_path('logs/acorn.log'),
            'level' => env('LOG_LEVEL', 'debug'),
        ],

        'daily' => [
            'driver' => 'daily',
            'path' => storage_path('logs/acorn.log'),
            'level' => env('LOG_LEVEL', 'debug'),
            'days' => 14,
        ],

        'errorlog' => [
            'driver' => 'errorlog',
            'level' => env('LOG_LEVEL', 'debug'),
        ],

        'syslog' => [
            'driver' => 'syslog',
            'level' => env('LOG_LEVEL', 'debug'),
        ],
    ],
];
```

Use `daily` as the default channel in production to prevent unbounded log growth:

```env
LOG_CHANNEL=daily
```

## Using the Logger

```php
use Illuminate\Support\Facades\Log;

// Basic usage
Log::info('Order placed successfully');
Log::warning('API rate limit approaching');
Log::error('Payment gateway timeout');

// Always pass context as an array — never interpolate strings
Log::error('Payment failed', [
    'order_id' => $orderId,
    'gateway' => $gateway,
    'amount' => $amount,
]);

// Write to a specific channel
Log::channel('errorlog')->critical('Database connection lost');

// Write to multiple channels simultaneously
Log::stack(['daily', 'errorlog'])->error('Critical failure', ['trace' => $e->getMessage()]);
```

## Log Levels

From most to least severe — use the appropriate level:

| Level | Use for |
|---|---|
| `emergency` | System is unusable |
| `alert` | Immediate action required |
| `critical` | Critical conditions (component failure) |
| `error` | Runtime errors that need attention |
| `warning` | Unusual conditions, not errors |
| `notice` | Normal but significant events |
| `info` | General operational messages |
| `debug` | Detailed debug info (dev only) |

## Custom Channels

Create channels for specific concerns to keep logs organized:

```php
// config/logging.php — add to 'channels' array
'api' => [
    'driver' => 'daily',
    'path' => storage_path('logs/api.log'),
    'level' => 'debug',
    'days' => 7,
],

'payments' => [
    'driver' => 'daily',
    'path' => storage_path('logs/payments.log'),
    'level' => 'info',
    'days' => 30,
],
```

```php
Log::channel('api')->info('External API called', [
    'endpoint' => $url,
    'status' => $response->status(),
    'duration_ms' => $duration,
]);

Log::channel('payments')->error('Charge failed', [
    'order_id' => $order->id,
    'error' => $e->getMessage(),
]);
```

## Exception Handling

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

### Custom Exception Classes

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

## Integration with WordPress Debug

Acorn's logging is independent from WordPress's `WP_DEBUG_LOG`. Both can run simultaneously:

| System | Log file | Controlled by |
|---|---|---|
| WordPress | `wp-content/debug.log` | `WP_DEBUG` + `WP_DEBUG_LOG` |
| Acorn | `storage/logs/acorn.log` | `config/logging.php` |

To route Acorn logs into PHP's error log (which WordPress may also use):

```php
// config/logging.php
'default' => 'errorlog',
```

For development, keep both enabled. For production, disable `WP_DEBUG` and rely on Acorn's structured logging with the `daily` driver.

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

## Verification

- Write a test log entry (`Log::info('test', ['key' => 'value'])`) and confirm it appears in the expected log file (e.g., `storage/logs/acorn.log` or the daily rotated variant).
- Verify the correct channel is being used by writing to a named channel (`Log::channel('payments')->info('test')`) and checking the channel-specific log file.

## Failure modes

### Problem: Permission denied when writing to log file
- **Cause:** The web server process does not have write permissions on the `storage/logs/` directory or the log file itself.
- **Fix:** Fix permissions with `lando ssh -s appserver -c "chmod -R 775 /app/content/themes/{theme}/storage/logs"`. Ensure the `storage/` directory is writable by the web server user. In Lando, this is typically handled automatically but can break after manual file operations.

### Problem: Log channel not configured (driver not found)
- **Cause:** The channel name used in `Log::channel('name')` does not exist in the `channels` array in `config/logging.php`.
- **Fix:** Add the missing channel definition to `config/logging.php` with the appropriate driver (`single`, `daily`, `errorlog`, etc.) and path. Verify `config/logging.php` exists in your theme directory.

## Escalation

- If the log disk is full or storage permissions cannot be resolved at the application level, this is an infrastructure issue -- check disk usage with `df -h` and coordinate with the server administrator.
- If you need to route logs to an external service (Sentry, Datadog, Slack), add a custom channel driver in `config/logging.php` or use the exception handler's `reportable()` method.
