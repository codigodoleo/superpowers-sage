Deep reference for Acorn command practical examples. Loaded on demand from `skills/acorn-commands/SKILL.md`.

# Acorn Commands — Practical Examples

Worked examples for the three most common Acorn command use cases: bulk data import, cache warm-up, and site maintenance.

## Import Products (WordPress + Laravel)

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

## Maintenance: Cleanup Expired Tokens

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

## Generate Sitemap (WordPress data)

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
