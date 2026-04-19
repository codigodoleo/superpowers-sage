Deep reference for ACF Composer block class structure in Sage themes. Loaded on demand from `skills/block-scaffolding/SKILL.md`.

# ACF Composer Block Registration

Full block class shape, `$fields` definition, and required overrides for registering ACF Composer blocks in a Sage theme.

## Full Block Class Shape

```php
<?php

namespace App\Blocks;

use Log1x\AcfComposer\Block;
use StoutLogic\AcfBuilder\FieldsBuilder;

class HeroBlock extends Block
{
    public $name = 'Hero Block';
    public $description = 'Full-width hero with headline and CTA.';
    public $category = 'theme-blocks';      // custom category slug
    public $icon = 'align-wide';            // dashicons slug (no "dashicons-" prefix)
    public $keywords = ['hero', 'banner'];

    /** Spacing control: null = enabled, [] = disabled */
    public $spacing = [
        'padding' => null,
        'margin'  => null,
    ];

    /** Block supports (editor controls) */
    public $supports = [
        'align'      => ['wide', 'full'],
        'color'      => ['background' => true, 'text' => true],
        'typography' => ['fontSize' => false],
    ];

    /**
     * $styles drives the Gutenberg style picker.
     * WP 6.x requires `name`, not `value`.
     * Omit entirely for blocks with a single fixed appearance.
     */
    public $styles = [
        ['label' => 'Light',   'name' => 'light',   'isDefault' => true],
        ['label' => 'Neutral', 'name' => 'neutral'],
        ['label' => 'Dark',    'name' => 'dark'],
    ];

    /**
     * Optional: restrict allowed parent blocks.
     * e.g. ['acf/section-wrapper']
     */
    // public $parent = [];

    /**
     * Optional: set block visibility in the inserter.
     * true = visible; false = hidden (useful for inner-only blocks).
     */
    // public $public = true;

    /** Pass computed data to the Blade view */
    public function with(): array
    {
        return [
            // 'posts' => get_posts(['posts_per_page' => 3]),
        ];
    }

    /** Declare ACF fields via AcfBuilder (never via the GUI) */
    public function fields(): array
    {
        $fields = new FieldsBuilder('hero-block');

        $fields
            ->addText('titulo', ['label' => 'Título'])
            ->addTextarea('descricao', ['label' => 'Descrição', 'rows' => 3])
            ->addLink('cta', ['label' => 'CTA']);

        return $fields->build();
    }

    /**
     * Keep empty — CSS/JS are enqueued by ThemeServiceProvider::boot()
     * via has_block() on wp_enqueue_scripts priority 20.
     * assets() fires inside render() → after wp_head() → assets never reach <head>.
     */
    public function assets(array $block): void
    {
        //
    }
}
```

## Key Properties

| Property | Required | Notes |
|---|---|---|
| `$name` | Yes | Human-readable label shown in the block inserter |
| `$description` | Yes | Shown in the block inserter tooltip |
| `$category` | Yes | Block category slug — use a project-specific custom category |
| `$icon` | Yes | Dashicons slug without the `dashicons-` prefix, or inline SVG |
| `$keywords` | No | Improves block search in the inserter |
| `$spacing` | Recommended | `null` = enabled; `[]` = disabled |
| `$supports` | Recommended | Editor feature controls (align, color, typography) |
| `$styles` | Full mode only | Gutenberg style picker entries; omit for Minimal blocks |
| `$parent` | No | Restrict to specific parent blocks |
| `$public` | No | Set `false` to hide from the inserter (inner-only blocks) |

## register() and view()

ACF Composer handles `register()` and `view()` internally via the `Block` base class.
- `register()` maps the class properties to `register_block_type()` arguments.
- `view()` resolves the Blade template at `resources/views/blocks/{slug}.blade.php`.

You do not override these methods unless implementing advanced custom rendering.

## Block Category Registration

Register a custom category in a Service Provider:

```php
add_filter('block_categories_all', function (array $categories): array {
    array_unshift($categories, [
        'slug'  => 'theme-blocks',
        'title' => __('Theme Blocks', 'sage'),
    ]);
    return $categories;
});
```

## $styles Format (WP 6.x)

Always use `name`, not `value` — WordPress 6.x deprecated `value`:

```php
// Correct (WP 6.x)
['label' => 'Dark', 'name' => 'dark']

// Wrong (deprecated)
['label' => 'Dark', 'value' => 'dark']
```

## assets() — Why It Must Stay Empty

ACF Composer's `assets()` is called from within `render()`, which fires during
`the_content` filter — after `wp_head()` has already executed. Any style or
script enqueued here is output too late and never reaches `<head>` on the
frontend. Always handle enqueue in `ThemeServiceProvider::boot()` using
`has_block("acf/{slug}")` on the `wp_enqueue_scripts` hook at priority 20.
