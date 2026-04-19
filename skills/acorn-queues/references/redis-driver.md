Deep reference for Redis-backed queue driver in Acorn/Sage with Lando. Loaded on demand from `skills/acorn-queues/SKILL.md`.

# Redis Queue Driver

## When to Use Redis

Use the Redis driver when:
- Job volume is high (hundreds of jobs per minute)
- Job latency must be low (< 1 second from dispatch to processing)
- You need blocking pop (`block_for`) to avoid polling delays
- You are already running Redis for cache (`acorn-redis` skill)

For low-volume projects or environments without Redis infrastructure, the `database` driver is simpler and equally reliable.

## Lando Redis Service Configuration

In `.lando.yml`, ensure a Redis service is defined:

```yaml
services:
  cache:
    type: redis:7
    portforward: 6379
```

Then configure the connection in `config/database.php`:

```php
'redis' => [
    'client' => env('REDIS_CLIENT', 'phpredis'),

    'default' => [
        'host'     => env('REDIS_HOST', '127.0.0.1'),
        'password' => env('REDIS_PASSWORD', null),
        'port'     => env('REDIS_PORT', 6379),
        'database' => env('REDIS_DB', 0),
    ],

    'cache' => [
        'host'     => env('REDIS_HOST', '127.0.0.1'),
        'password' => env('REDIS_PASSWORD', null),
        'port'     => env('REDIS_PORT', 6379),
        'database' => env('REDIS_CACHE_DB', 1),
    ],

    'queue' => [
        'host'     => env('REDIS_HOST', '127.0.0.1'),
        'password' => env('REDIS_PASSWORD', null),
        'port'     => env('REDIS_PORT', 6379),
        'database' => env('REDIS_QUEUE_DB', 2),
    ],
],
```

Use separate databases (0, 1, 2) to isolate cache, sessions, and queue keys.

## Environment Variables

```env
QUEUE_CONNECTION=redis
REDIS_HOST=cache          # Lando service name
REDIS_PORT=6379
REDIS_QUEUE=default
REDIS_QUEUE_DB=2
```

In Lando, the Redis host is the **service name** (e.g. `cache`), not `127.0.0.1`.

## Queue Connection in config/queue.php

```php
'redis' => [
    'driver'      => 'redis',
    'connection'  => 'queue',    // matches the 'queue' key in config/database.php redis connections
    'queue'       => env('REDIS_QUEUE', 'default'),
    'retry_after' => 90,
    'block_for'   => null,       // set to seconds to use blocking pop (reduces polling overhead)
    'after_commit' => false,
],
```

## Verifying Redis Queue

```bash
# Check queue depth (Lando)
lando redis-cli -h cache LLEN queues:default

# Monitor live queue activity
lando redis-cli -h cache MONITOR

# Inspect a job (list all keys)
lando redis-cli -h cache KEYS "queues:*"
```

## Failover: Falling Back to Database Driver

If Redis becomes unavailable (e.g. during a Lando restart), switch the driver temporarily:

```env
QUEUE_CONNECTION=database
```

Ensure the `jobs` table exists (`lando acorn queue:table && lando acorn migrate`) before switching. Redis jobs that were not consumed will remain in Redis when the service comes back online.

## Supervisor Configuration (Production)

```ini
[program:queue-worker]
process_name=%(program_name)s_%(process_num)02d
command=php /path/to/web/app/themes/sage/artisan queue:work redis --queue=high,default --tries=3 --backoff=60 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
numprocs=2
redirect_stderr=true
stdout_logfile=/var/log/queue-worker.log
stopwaitsecs=3600
```

## Common Mistakes

| Mistake | Fix |
|---|---|
| Using `127.0.0.1` as `REDIS_HOST` inside Lando containers | Use the Lando service name (`cache`) |
| Queue and cache sharing the same Redis database | Use separate database numbers to avoid key collisions |
| No `block_for` set in high-throughput setups | Set `block_for: 5` to use blocking pop and reduce polling overhead |
