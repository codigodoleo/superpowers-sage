Deep reference for queue troubleshooting in Acorn/Sage/WordPress. Loaded on demand from `skills/acorn-queues/SKILL.md`.

# Queue Troubleshooting

## Failed Jobs Table

```bash
# List all failed jobs
lando acorn queue:failed

# Retry a specific failed job by UUID
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

If the `failed_jobs` table does not exist, create it first:

```bash
lando acorn queue:failed-table && lando acorn migrate
```

## queue:work Debug Mode

```bash
# Verbose output — shows each job being processed
lando acorn queue:work --verbose

# Process one job and stop (safe for debugging)
lando acorn queue:work --once

# Stop worker gracefully (finish current job, then exit)
lando acorn queue:restart
```

## Common Errors and Fixes

### Jobs dispatched but never processed (sit in queue indefinitely)

**Cause:** No worker is running, or `QUEUE_CONNECTION` in `.env` does not match a connection in `config/queue.php`.

**Fix:**
1. Verify `QUEUE_CONNECTION` in `.env` matches a valid connection key (`database` or `redis`).
2. Start a worker: `lando acorn queue:work`.
3. For the database driver, confirm migrations were run: `lando acorn queue:table && lando acorn migrate`.

### `failed_jobs` table does not exist

**Cause:** The failed jobs migration was never created or run.

**Fix:** `lando acorn queue:failed-table && lando acorn migrate`

### Jobs retry immediately without respecting backoff

**Cause:** `$backoff` not set on the job class, or worker started without `--backoff` flag.

**Fix:** Add `public array $backoff = [30, 120, 600];` to the job class. The `run-worker.sh` script passes `--backoff=60` by default.

### `Class not found` error in failed jobs log

**Cause:** The job class was renamed or deleted after it was queued. The serialized payload references the old class name.

**Fix:** Flush the failing jobs (`lando acorn queue:flush`) and redispatch. If the class was renamed, add a temporary class alias until the queue drains.

### Redis connection refused inside Lando

**Cause:** `REDIS_HOST=127.0.0.1` does not work inside Lando containers. The Redis service is accessible by its service name.

**Fix:** Set `REDIS_HOST=cache` (or whatever the Lando service name is). See `redis-driver.md` for full Lando Redis setup.

### `sync` driver accidentally used in production

**Cause:** `QUEUE_CONNECTION=sync` in production `.env` causes jobs to run synchronously, blocking the HTTP request.

**Fix:** Set `QUEUE_CONNECTION=database` (or `redis`) in production. Use `sync` only in local development for instant feedback.

### `current_user_can()` always returns false inside jobs

**Cause:** Jobs run outside the HTTP request lifecycle. WordPress does not set a current user automatically.

**Fix:** Call `wp_set_current_user($userId)` at the top of `handle()` if the job needs to check capabilities. See `job-patterns.md` for the pattern.

### Memory exhaustion — worker runs out of memory

**Cause:** Job loads large datasets into memory (e.g. `get_posts` with `posts_per_page: -1`).

**Fix:** Chunk the dataset using the fan-out pattern in `job-patterns.md`. Set a memory limit on the worker: `lando acorn queue:work --memory=256`.

## Best Practices Summary

| Practice | Why |
|---|---|
| Always set `$tries` and `$backoff` | Prevents infinite retries; exponential backoff protects external APIs |
| Pass IDs, not objects | Avoids serialization issues and stale data on retry |
| Log in `handle()` and `failed()` | Makes issues visible without digging into DB records |
| Use dedicated queues (`high`, `emails`, `media`) | Prioritize critical work; prevent one slow queue from blocking others |
| Use `sync` driver in development only | Ensures job logic works before running a worker |
| Check `as_has_scheduled_action()` before recurring AS schedules | Prevents duplicate stacked recurring tasks |

## Escalation Paths

- **Redis connectivity issues** → see `redis-driver.md` for Lando Redis setup and failover guidance.
- **Jobs need recurring schedule** → use Action Scheduler or the Acorn command scheduler. See `action-scheduler.md`.
- **Job design concerns (idempotency, chunking)** → see `job-patterns.md`.
