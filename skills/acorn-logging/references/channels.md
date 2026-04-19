Deep reference for Acorn logging channel configuration. Loaded on demand from `skills/acorn-logging/SKILL.md`.

# Acorn Logging Channels

Custom Monolog channels, daily file rotation, Slack handler, and WordPress `debug.log` bridge configuration for Acorn logging.

## Configuration

Publish the logging config if it doesn't exist:

```
lando acorn vendor:publish --provider="Roots\Acorn\Providers\LoggingServiceProvider"
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

## Slack Channel

Send error-level logs to a Slack webhook:

```php
// config/logging.php
'slack' => [
    'driver'   => 'slack',
    'url'      => env('LOG_SLACK_WEBHOOK_URL'),
    'username' => 'Acorn Logger',
    'emoji'    => ':boom:',
    'level'    => env('LOG_LEVEL', 'error'),
],
```

In `.env`:
```
LOG_SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
```

Use in a stack channel to get both file and Slack:
```php
'stack' => [
    'driver'   => 'stack',
    'channels' => ['daily', 'slack'],
    'level'    => 'error',
],
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
