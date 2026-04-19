# Factories and Seeders

Model factory definitions and seeding for Acorn Eloquent — generating test data with `fake()` and `lando acorn db:seed`.

## Creating a Factory

```bash
lando acorn make:factory TestimonialFactory
```

The factory must be linked to its model via `$model`:

```php
<?php

namespace Database\Factories;

use App\Models\Testimonial;
use Illuminate\Database\Eloquent\Factories\Factory;

class TestimonialFactory extends Factory
{
    protected $model = Testimonial::class;

    public function definition(): array
    {
        return [
            'author_name' => fake()->name(),
            'company'     => fake()->company(),
            'body'        => fake()->paragraphs(2, asText: true),
            'rating'      => fake()->numberBetween(1, 5),
            'is_featured' => fake()->boolean(20), // 20% chance true
            'published_at' => fake()->optional(0.8)->dateTimeBetween('-1 year'),
            'metadata'    => [
                'source' => fake()->randomElement(['website', 'email', 'social']),
            ],
        ];
    }

    public function featured(): static
    {
        return $this->state(fn (array $attributes) => [
            'is_featured' => true,
            'rating'      => fake()->numberBetween(4, 5),
        ]);
    }

    public function unpublished(): static
    {
        return $this->state(fn (array $attributes) => [
            'published_at' => null,
        ]);
    }
}
```

## Enabling HasFactory on the Model

```php
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Testimonial extends Model
{
    use HasFactory;
    // ...
}
```

## Using Factories

```php
// Create in database
Testimonial::factory()->count(10)->create();
Testimonial::factory()->featured()->count(3)->create();
Testimonial::factory()->unpublished()->create();

// Make (no database insert — for unit tests)
$testimonial = Testimonial::factory()->make();

// Create with specific attributes
Testimonial::factory()->create(['author_name' => 'John Doe', 'rating' => 5]);
```

## fake() Reference

Common `fake()` helpers:

| Call | Example output |
|---|---|
| `fake()->name()` | `"John Smith"` |
| `fake()->email()` | `"john@example.com"` |
| `fake()->company()` | `"Acme Corp"` |
| `fake()->paragraph()` | One paragraph of lorem ipsum |
| `fake()->paragraphs(2, asText: true)` | Two paragraphs as a string |
| `fake()->numberBetween(1, 5)` | Random int 1–5 |
| `fake()->boolean(25)` | `true` 25% of the time |
| `fake()->optional(0.8)->value` | Value 80% of the time, null 20% |
| `fake()->dateTimeBetween('-1 year')` | Random DateTime in the past year |
| `fake()->randomElement(['a', 'b'])` | One of the array values |
| `fake()->slug()` | `"lorem-ipsum-dolor"` |
| `fake()->url()` | `"https://www.example.com"` |
| `fake()->imageUrl(640, 480)` | URL string (no actual download) |

## Seeders

### Creating a Seeder

```bash
lando acorn make:seeder TestimonialSeeder
```

```php
<?php

namespace Database\Seeders;

use App\Models\Testimonial;
use Illuminate\Database\Seeder;

class TestimonialSeeder extends Seeder
{
    public function run(): void
    {
        Testimonial::factory()->count(20)->create();
        Testimonial::factory()->featured()->count(5)->create();
    }
}
```

Register in `DatabaseSeeder`:

```php
class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            TestimonialSeeder::class,
        ]);
    }
}
```

### Running Seeders

| Command | Purpose |
|---|---|
| `lando acorn db:seed` | Run `DatabaseSeeder` |
| `lando acorn db:seed --class=TestimonialSeeder` | Run a specific seeder |
| `lando acorn migrate --seed` | Migrate then seed |
| `lando acorn migrate:refresh --seed` | Reset, re-run migrations, then seed |

## WordPress Context in Factories / Seeds

If a seeder needs to create WordPress posts alongside custom Eloquent records, call WP functions directly (not via Eloquent):

```php
public function run(): void
{
    // Use WP function for WP content — not Eloquent
    $post_id = wp_insert_post([
        'post_title'  => fake()->sentence(),
        'post_status' => 'publish',
        'post_type'   => 'post',
    ]);

    // Then create the linked Eloquent record
    Testimonial::factory()->create(['wp_post_id' => $post_id]);
}
```

`wp_set_current_user` is not required in seeders unless you need capability checks (`current_user_can()`).

## Common Mistakes

| Mistake | Fix |
|---|---|
| Factory not found | Confirm `use HasFactory` is on the model and `$model` is set on the factory |
| Using `->create()` in unit tests | Use `->make()` for unit tests that don't need the database |
| Not wrapping factory calls in a transaction | For large seeds, use `DB::transaction()` for performance |
| Calling `wp_insert_post` in a factory | Factories run outside WP's request cycle — call WP functions in seeders, not in factory `definition()` |
