Deep reference for Acorn Redis session and queue configuration. Loaded on demand from `skills/acorn-redis/SKILL.md`.

# Redis Session and Queue Configuration

Configuring Redis as the session driver and queue connection in Acorn, with Lando service wiring.

## Session Configuration

`config/session.php`:

```php
return [
    'driver' => env('SESSION_DRIVER', 'redis'),
    'lifetime' => env('SESSION_LIFETIME', 120),
    'connection' => env('SESSION_CONNECTION', 'default'),
    'cookie' => env('SESSION_COOKIE', Str::slug(env('APP_NAME', 'sage'), '_') . '_session'),
];
```

Sessions use the `default` Redis connection (database `0`), separate from cache (database `1`).

Add to `.env`:

```env
SESSION_DRIVER=redis
SESSION_CONNECTION=default
```

## Queue Driver

Set `QUEUE_CONNECTION=redis` in `.env`. Queue configuration lives in `config/queue.php`. See `sage:acorn-queues` for job dispatching, workers, and retry strategies.

```env
QUEUE_CONNECTION=redis
```

## Lando Service Wiring

All three uses (cache, session, queue) share the same Redis service in `.lando.yml`:

```yaml
services:
  cache:
    type: redis:6
```

Isolate them using separate Redis databases:

| Use | Database | `.env` key |
|---|---|---|
| Sessions | `0` | `REDIS_DB=0` |
| Cache | `1` | `REDIS_CACHE_DB=1` |
| WP Object Cache | `2` | `WP_REDIS_DATABASE=2` |
| Queue | `0` (default) | `QUEUE_CONNECTION=redis` |

Keeping separate databases ensures that flushing cache (`FLUSHDB` on db 1) does not invalidate sessions or queue jobs.
