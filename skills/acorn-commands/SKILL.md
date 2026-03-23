---
name: superpowers-sage:acorn-commands
description: Custom Acorn CLI commands for WordPress automation; artisan-style commands for theme tasks, data imports, maintenance, and scheduled operations
user-invocable: false
---

# Custom Acorn CLI Commands

Acorn commands are artisan-style CLI commands running inside WordPress context with full access to the Laravel container (services, Eloquent, config) **and** all WordPress functions (`get_posts()`, `wp_insert_post()`, etc.).

## Creating a Command

```bash
lando acorn make:command ImportProducts
# Generates app/Console/Commands/ImportProducts.php
```

## Command Anatomy

```php
<?php
namespace App\Console\Commands;
use Illuminate\Console\Command;

class ImportProducts extends Command
{
    protected $signature = 'import:products
        {source : The data source (csv or api)}
        {--dry-run : Preview changes without writing}
        {--limit=100 : Max records to process}
        {--tag=* : Tags to assign (repeatable)}';
    protected $description = 'Import products from CSV or external API';

    public function handle(): int
    {
        $source = $this->argument('source');
        $this->info("Importing from {$source}");
        if ($this->option('dry-run')) { $this->warn('Dry-run mode — no writes.'); }
        return self::SUCCESS; // 0 = success, 1 = failure
    }
}
```

## Arguments and Options

```
{format}         Required       {--with-meta}     Boolean flag
{format=csv}     Default value  {--chunk=500}     Option with default
{format?}        Nullable       {--F|format=csv}  Shortcut
{ids*}           Array
```

## Output and Interaction

```php
$this->info('Done.');  $this->warn('Caution.');  $this->error('Failed!');
$this->table(['ID', 'Title'], $rows);
$this->withProgressBar($items, fn ($item) => process($item));
if (! $this->confirm('Continue?')) { return self::FAILURE; }
```

## Dependency Injection

Inject services into `handle()` — the container resolves them automatically:

```php
public function handle(ProductImporter $importer): int
{
    $results = $importer->run(source: $this->argument('source'), limit: (int) $this->option('limit'));
    $this->info("Imported {$results->created} / skipped {$results->skipped}");
    return self::SUCCESS;
}
```

## Calling Other Commands

```php
$this->call('cache:clear');                                               // With output
$this->callSilent('view:clear');                                          // Silent
$this->call('import:products', ['source' => 'csv', '--dry-run' => true]); // With args
```

## Registration

Commands in `app/Console/Commands/` are auto-discovered. For commands elsewhere, register in a ServiceProvider's `boot()`: `$this->commands([ImportProducts::class])`.

## Scheduling

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

## Practical Examples

### Import Products (WordPress + Laravel)

```php
class ImportProducts extends Command
{
    protected $signature = 'import:products {source} {--file=} {--dry-run}';
    protected $description = 'Import products as WordPress posts';
    public function handle(ProductImporter $importer): int
    {
        $items = match ($this->argument('source')) {
            'csv' => $importer->fromCsv($this->option('file')),
            'api' => $importer->fromApi(),
            default => $this->fail('Invalid source.'),
        };
        $created = $skipped = 0;
        $this->withProgressBar($items, function (array $item) use (&$created, &$skipped) {
            if (get_page_by_title($item['name'], OBJECT, 'product')) { $skipped++; return; }
            if (! $this->option('dry-run')) {
                wp_insert_post(['post_type' => 'product', 'post_title' => $item['name'],
                    'post_status' => 'publish', 'meta_input' => ['_price' => $item['price']]]);
            }
            $created++;
        });
        $this->newLine();
        $this->info("{$created} created, {$skipped} skipped.");
        return self::SUCCESS;
    }
}
```

### Maintenance: Cleanup Expired Tokens

```php
class CleanupExpiredTokens extends Command
{
    protected $signature = 'cleanup:tokens {--days=30}';
    protected $description = 'Delete expired authentication tokens';
    public function handle(): int
    {
        $deleted = \App\Models\PersonalAccessToken::where('expires_at', '<', now()->subDays((int) $this->option('days')))->delete();
        $this->info("Deleted {$deleted} expired tokens.");
        return self::SUCCESS;
    }
}
```

### Generate Sitemap (WordPress data)

```php
class GenerateSitemap extends Command
{
    protected $signature = 'generate:sitemap {--output=public/sitemap.xml}';
    protected $description = 'Generate XML sitemap from published content';
    public function handle(): int
    {
        $posts = get_posts(['post_type' => ['post', 'page'], 'numberposts' => -1]);
        $xml = new \SimpleXMLElement('<?xml version="1.0"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"/>');
        foreach ($posts as $post) {
            $xml->addChild('url')->addChild('loc', get_permalink($post));
        }
        file_put_contents($this->option('output'), $xml->asXML());
        $this->info('Sitemap: ' . count($posts) . ' URLs.');
        return self::SUCCESS;
    }
}
```

## Running Commands

```bash
lando acorn import:products csv --file=data/products.csv
lando acorn import:products api --dry-run --limit=10
lando acorn cleanup:tokens --days=7
lando acorn generate:sitemap
lando acorn list                    # List all commands
lando acorn help import:products    # Command help
```

## Verification

- Run `lando acorn list` and confirm your custom command appears with the correct signature and description.
- Execute the command with `lando acorn <command-name>` and verify it completes without errors, returning exit code 0 (`self::SUCCESS`).
- Test arguments and options by running with `--help` to confirm the signature matches expectations, then run with sample inputs.

## Failure modes

### Problem: Command not discovered (not in `lando acorn list`)
- **Cause:** The command class is not in the `app/Console/Commands/` directory (the auto-discovery path), or the namespace does not match the file location.
- **Fix:** Ensure the command file is at `app/Console/Commands/YourCommand.php` with namespace `App\Console\Commands`. If the command lives elsewhere, register it explicitly in a service provider's `boot()` method: `$this->commands([YourCommand::class])`.

### Problem: Dependency injection resolution fails (target is not instantiable)
- **Cause:** The `handle()` method type-hints a service that is not bound in the container, or the service's own dependencies cannot be resolved.
- **Fix:** Verify the service is registered in a service provider's `register()` method. Check that all constructor parameters of the injected service are also resolvable. Use `lando acorn tinker` and `app()->make(YourService::class)` to test resolution in isolation.

## Escalation

- If DI resolution fails for a complex service tree, consult the service-providers reference in `sage:roots-sage-lando` for correct binding patterns and singleton registration.
- If the command needs to dispatch long-running work, dispatch a queued job instead of running the logic inline -- see `sage:acorn-queues` for job dispatching patterns.
