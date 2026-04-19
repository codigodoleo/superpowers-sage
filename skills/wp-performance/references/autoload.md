Deep reference for WordPress autoload optimization. Loaded on demand from `skills/wp-performance/SKILL.md`.

# Autoload Optimization

Autoloaded options are loaded on every WordPress request, so bloated autoload entries directly inflate TTFB and bootstrap time.

## What Autoloaded Options Are

WordPress stores plugin and theme configuration in `wp_options`. Each row has an `autoload` column. When `autoload='yes'`, WordPress fetches that row during bootstrap (before any page logic runs) via a single `SELECT` that pulls every autoloaded row at once. The result is cached in memory for the request.

The problem: there is no size limit. A single plugin can store megabytes of serialized data in an autoloaded option and inflate every page load — even pages that never use that plugin's output.

Target: total autoloaded size < 500KB.

## Auditing Autoloaded Options

Run the audit script to identify oversized options:

```bash
bash skills/wp-performance/scripts/autoload-audit.sh
```

The script returns the top autoloaded options larger than 1KB, sorted by size descending. Review the output and identify candidates for disabling autoload.

You can also query directly:

```sql
SELECT option_name, LENGTH(option_value) AS size_bytes
FROM wp_options
WHERE autoload = 'yes'
  AND LENGTH(option_value) > 1024
ORDER BY size_bytes DESC
LIMIT 20;
```

To see the total autoloaded footprint:

```sql
SELECT SUM(LENGTH(option_value)) AS total_bytes
FROM wp_options
WHERE autoload = 'yes';
```

## Common Culprits

| Option pattern | Typical source | Typical size |
|---|---|---|
| `_transient_*` | Plugins storing data as options instead of real transients | 10–500KB |
| `woocommerce_*` | WooCommerce product/category caches | 50–2000KB |
| `elementor_*` | Elementor CSS/template caches | 100–5000KB |
| `jetpack_*` | Jetpack sync/module data | 50–500KB |
| `yoast_*` | Yoast SEO indexing data | 20–200KB |
| Plugin `_settings` blobs | Plugins serializing entire config arrays | 10–500KB |

Transients stored in `wp_options` (not in object cache) are the most common cause of autoload bloat. They should expire, but if the object cache is not available WordPress falls back to the options table and transients accumulate.

## Disabling Autoload for Specific Options

Use WP-CLI to flip the autoload flag without deleting the data:

```bash
# Disable autoload for a specific option
lando wp option update <option_name> --autoload=no

# Example: disable a large transient-style option
lando wp option update woocommerce_product_data_store_cpt_cached_block_post_ids --autoload=no
```

After updating, verify the change:

```bash
lando wp option get <option_name> --format=table
```

## When to Set `autoload=no`

Set autoload to `no` when:

- The option is only read in specific admin contexts or on specific page types
- The option value is large (> 10KB) and not needed on most requests
- The option is a cache or computed value that can be regenerated on demand
- The option belongs to a plugin that is not active on every request (e.g. WooCommerce data on non-shop pages)

Do **not** disable autoload when:

- The option is a core WordPress setting required for every request
- The option controls site-wide behavior (e.g. `siteurl`, `active_plugins`)
- Disabling it would cause excessive individual DB queries on every page load (trading one large query for many small ones)

## Verification

After disabling autoload on heavy options, re-run the audit and confirm the total autoloaded size is below 500KB. Check QM's DB panel to ensure no new single-option queries are appearing on every page.
