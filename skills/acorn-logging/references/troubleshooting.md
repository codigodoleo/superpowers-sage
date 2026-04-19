Deep reference for debugging Acorn logging failures. Loaded on demand from `skills/acorn-logging/SKILL.md`.

# Acorn Logging — Troubleshooting

Common errors when configuring and using Acorn's logging system in Lando/WordPress projects.

## Logs Not Appearing (WP_DEBUG_LOG Not Set)

**Symptom:** `Log::info()` / `Log::error()` calls produce no output in any log file.
**Cause:** `LOG_CHANNEL` is misconfigured or `config/logging.php` does not exist in the theme.
**Fix:** Confirm `config/logging.php` is present in your theme directory. Run `lando acorn vendor:publish --provider="Roots\Acorn\Providers\LoggingServiceProvider"` if the file is missing. Set `LOG_CHANNEL=single` in `.env` for immediate output to `storage/logs/acorn.log`. Check `storage/logs/` exists and is writable.

## Permission Errors on Log File

**Symptom:** `Permission denied` when writing to `storage/logs/acorn.log`.
**Cause:** The web server process does not have write permissions on the `storage/logs/` directory or the log file itself.
**Fix:** Fix permissions with `lando ssh -s appserver -c "chmod -R 775 /app/content/themes/{theme}/storage/logs"`. Ensure the `storage/` directory is writable by the web server user. In Lando, this is typically handled automatically but can break after manual file operations.

## Daily Channel Not Rotating

**Symptom:** Log file grows indefinitely; no dated log files appear alongside `acorn.log`.
**Cause:** The `daily` channel creates files named `acorn-YYYY-MM-DD.log`, but the `path` in `config/logging.php` points to a static filename.
**Fix:** This is expected behavior — the `daily` driver appends the date automatically. Verify files like `acorn-2024-01-15.log` exist in `storage/logs/`. Ensure the `days` key is set (e.g., `'days' => 14`) to enable automatic cleanup.

## Slack Not Notified

**Symptom:** Critical errors occur but no Slack notifications arrive.
**Cause:** The Slack channel is not added to the `stack` channels array, or the `LOG_SLACK_WEBHOOK_URL` env var is not set.
**Fix:** Add the Slack channel to `config/logging.php`:

```php
'slack' => [
    'driver' => 'slack',
    'url' => env('LOG_SLACK_WEBHOOK_URL'),
    'username' => 'Acorn Log',
    'emoji' => ':boom:',
    'level' => env('LOG_LEVEL', 'critical'),
],
```

Set `LOG_SLACK_WEBHOOK_URL` in `.env` and include `'slack'` in your `stack` channels: `'channels' => ['daily', 'slack']`. Verify the webhook URL is valid by testing with `curl`.
