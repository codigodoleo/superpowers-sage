Deep reference for debugging Acorn Redis failures. Loaded on demand from `skills/acorn-redis/SKILL.md`.

# Acorn Redis — Troubleshooting

Common errors when configuring and using Redis with Acorn in Lando.

## Connection Refused (Redis Not Running)

**Symptom:** `Illuminate\Redis\Connections\PhpRedisConnection` throws "Connection refused" or `ECONNREFUSED`.
**Cause:** The Redis service in Lando is not started, or `REDIS_HOST` in `.env` does not match the Lando service name.
**Fix:** Run `lando restart` to restart all services including Redis. Verify `.env` has `REDIS_HOST=cache` (matching the service name in `.lando.yml`). Check that `.lando.yml` includes a `cache` service with `type: redis`. Run `lando info` to confirm the Redis service is listed and running.

## Object Cache Drop-In Not Installed

**Symptom:** `lando wp cache type` returns "Default" instead of "Redis".
**Cause:** The `object-cache.php` drop-in is not present in `wp-content/`.
**Fix:** Install `wp-redis` or `redis-cache` plugin, then run `lando wp plugin install wp-redis --activate` and copy the drop-in: `lando wp plugin install wp-redis && lando wp redis enable`. Verify with `lando wp cache type`.

## Cache Not Persisting Between Requests

**Symptom:** `Cache::remember()` always executes the closure — no cache hits.
**Cause:** `CACHE_DRIVER` is not set to `redis`, or the `cache` Redis connection in `config/database.php` points to the wrong host/port.
**Fix:** Confirm `CACHE_DRIVER=redis` in `.env`. Test with `lando redis-cli -h cache PING` (expect `PONG`). Use `lando redis-cli -h cache MONITOR` while making a request to observe whether keys are being set.

## Session Not Working

**Symptom:** Sessions reset between requests; user is logged out unexpectedly.
**Cause:** `SESSION_DRIVER=redis` is set but the `default` Redis connection is misconfigured, or the session cookie name conflicts with another WordPress cookie.
**Fix:** Verify `REDIS_HOST=cache` and the `default` connection in `config/database.php` resolves correctly inside Lando. Check `SESSION_COOKIE` is unique to your app (use `APP_NAME`-based slug). Confirm `config/session.php` uses `env('SESSION_DRIVER', 'redis')`.
