Deep reference for Acorn command scheduling and execution. Loaded on demand from `skills/acorn-commands/SKILL.md`.

# Command Scheduling and Execution

Acorn commands can be scheduled via the `Schedule` facade or triggered manually with `lando acorn`.

## Scheduling Commands

Define in `config/console.php`:

```php
return [
    'schedule' => function (Schedule $schedule) {
        $schedule->command('cleanup:tokens')->dailyAt('03:00');
        $schedule->command('import:products api --limit=500')->hourly();
        $schedule->command('generate:sitemap')->weekly()->mondays()->at('05:00')->onOneServer();
    },
];
```

Requires cron: `* * * * * cd /path && lando acorn schedule:run >> /dev/null 2>&1`. For heavy work, dispatch a queued job instead (see `sage:acorn-queues`).

## Running Commands Manually

```bash
lando acorn import:products csv --file=data/products.csv
lando acorn import:products api --dry-run --limit=10
lando acorn cleanup:tokens --days=7
lando acorn generate:sitemap
lando acorn list                    # List all commands
lando acorn help import:products    # Command help
```

## wp-cron vs Action Scheduler vs Real Cron

- Development: `lando acorn schedule:run --verbose`
- Staging/Production: disable wp-cron, use system cron to trigger `wp acorn schedule:run`
- Long-running tasks: delegate to Action Scheduler (see acorn-queues skill)
