Deep reference for debugging Acorn command failures. Loaded on demand from `skills/acorn-commands/SKILL.md`.

# Acorn Commands — Troubleshooting

Common errors when creating and running Acorn CLI commands in Lando.

## Command Not Found

**Symptom:** `lando acorn my:command` returns "Command not found."
**Fix:** Register in `AppServiceProvider::boot()`:
```php
$this->commands([\App\Console\Commands\MyCommand::class]);
```

## Dependency Injection Fails

**Symptom:** Constructor argument is null or throws "Target [Interface] is not instantiable."
**Fix:** Bind the interface in `AppServiceProvider::register()` before `boot()` runs.

## Schedule Not Running

**Symptom:** `lando acorn schedule:run` exits silently, nothing executes.
**Fix:** Verify `ScheduleServiceProvider` is registered in `config/app.php` providers and the command's `schedule()` frequency is defined.

## Command Output Not Visible

**Symptom:** `lando acorn my:command` exits 0 but shows no output.
**Fix:** Use `$this->info()` / `$this->line()` — do not use `echo` directly in Acorn commands.
