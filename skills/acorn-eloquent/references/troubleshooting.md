# Eloquent Troubleshooting

Common errors and fixes for Eloquent in Acorn/WordPress. Loaded on demand from `skills/acorn-eloquent/SKILL.md`.

## Common errors

| Error | Cause | Fix |
|---|---|---|
| `SQLSTATE[42S02]: Table doesn't exist` | Migration not run, or wrong `$table` name | Run `lando acorn migrate:status`; verify `$table` property |
| Mass assignment exception | `$fillable` not set | Add properties to `$fillable`, or use `$guarded = []` for dev |
| `Call to undefined method App\Models\X::save()` on WP model | Tried to write via Eloquent to a WP-managed table | Use `wp_insert_post()`, `update_post_meta()`, etc. instead |
| Timestamps column not found | WP table has no `created_at`/`updated_at` | Set `public $timestamps = false` |
| Wrong results on WP table queries | Auto-prefixing issue | Check `$table` uses `$wpdb->prefix` if prefix != `wp_` |
| Factory generates invalid data | `fake()` not seeded consistently | Call `Faker::seed(1234)` in `setUp()` for deterministic tests |

## Debugging

```bash
# Check pending migrations
lando acorn migrate:status

# Roll back last batch
lando acorn migrate:rollback

# Fresh migrate + seed
lando acorn migrate:fresh --seed
```

## Escalation

For persistent query issues, enable query logging:
```php
\DB::enableQueryLog();
// ... your query ...
dd(\DB::getQueryLog());
```
