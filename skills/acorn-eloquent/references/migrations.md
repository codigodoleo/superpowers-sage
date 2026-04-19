# Migrations

## Creating Migrations

```bash
lando acorn make:migration create_testimonials_table
lando acorn make:migration add_rating_to_testimonials_table
lando acorn make:migration create_event_logs_table
```

Acorn resolves the theme's `database/migrations/` directory automatically.

## Migration Structure

Always include the WordPress prefix in table names. Use `up()` to create and `down()` to reverse:

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wp_testimonials', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('user_id')->nullable();
            $table->string('author_name');
            $table->string('company')->nullable();
            $table->text('body');
            $table->unsignedTinyInteger('rating')->default(5);
            $table->boolean('is_featured')->default(false);
            $table->timestamp('published_at')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamps(); // created_at, updated_at

            $table->index('user_id');
            $table->index('is_featured');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wp_testimonials');
    }
};
```

## Column Types Reference

| Method | SQL type | Notes |
|---|---|---|
| `$table->id()` | BIGINT UNSIGNED AUTO_INCREMENT | Primary key shorthand |
| `$table->string('col', 255)` | VARCHAR | Default length 255 |
| `$table->text('col')` | TEXT | |
| `$table->longText('col')` | LONGTEXT | For large content |
| `$table->integer('col')` | INT | |
| `$table->unsignedBigInteger('col')` | BIGINT UNSIGNED | For foreign keys to `id()` columns |
| `$table->boolean('col')` | TINYINT(1) | |
| `$table->timestamp('col')` | TIMESTAMP | Nullable by default for WP compat |
| `$table->timestamps()` | created_at + updated_at | Omit for WP core table mirrors |
| `$table->json('col')` | JSON | MySQL 5.7.8+ / MariaDB 10.2+ |
| `$table->decimal('col', 8, 2)` | DECIMAL | For currency |
| `$table->enum('col', ['a', 'b'])` | ENUM | |

## Adding Columns to Existing Tables

```php
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('wp_testimonials', function (Blueprint $table) {
            $table->unsignedSmallInteger('view_count')->default(0)->after('rating');
            $table->string('video_url')->nullable()->after('body');
        });
    }

    public function down(): void
    {
        Schema::table('wp_testimonials', function (Blueprint $table) {
            $table->dropColumn(['view_count', 'video_url']);
        });
    }
};
```

## Running Migrations

All migration commands must run via Lando:

| Command | Purpose |
|---|---|
| `lando acorn migrate` | Run all pending migrations |
| `lando acorn migrate --seed` | Run migrations then seed |
| `lando acorn migrate:rollback` | Rollback last batch |
| `lando acorn migrate:rollback --step=2` | Rollback last 2 batches |
| `lando acorn migrate:reset` | Rollback all migrations |
| `lando acorn migrate:refresh` | Rollback all and re-run |
| `lando acorn migrate:refresh --seed` | Rollback, re-run, and seed |
| `lando acorn migrate:status` | Show migration status (ran / pending) |

**Never run `migrate:reset` or `migrate:refresh` on production data.** Use `migrate:rollback` with a specific `--step`.

## Migration Naming Convention

Acorn uses timestamps in migration filenames for ordering:

```
database/migrations/
  2024_01_15_120000_create_testimonials_table.php
  2024_01_15_120001_create_event_logs_table.php
  2024_02_10_093000_add_rating_to_testimonials_table.php
```

The `make:migration` command generates the timestamp prefix automatically.

## Migrations Table

Acorn stores the migrations log in `wp_migrations` (uses the WP prefix). This table is created automatically on first `lando acorn migrate`.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Table name missing WP prefix | Use `wp_` prefix in both the migration and the model's `$table` |
| Running `migrate` directly on the host | Always use `lando acorn migrate` |
| Forgetting `down()` | Always implement `down()` to enable rollbacks in development |
| Adding `timestamps()` to a WP core table migration | WP core tables have no `created_at`/`updated_at` |
| Using `$table->string()` for large content | Use `$table->text()` or `$table->longText()` |
