Deep reference for ACF Composer field groups and blocks. Loaded on demand from `skills/sage-lando/SKILL.md`.

# ACF Composer

`log1x/acf-composer` is the class-based ACF integration for Acorn — every block, field group, partial, options page, and widget is a PHP class auto-discovered and registered via the service container.

## Overview

`log1x/acf-composer` brings ACF (Advanced Custom Fields) into the Acorn service provider pattern. Blocks, field groups, partials, options pages, and widgets are PHP classes that are auto-discovered and registered.

**Always generate with CLI:** `lando acorn acf:block`, `acf:field`, `acf:partial`, `acf:options`, `acf:widget`. Never create these files manually.

---

## Installing ACF Pro via Composer

ACF Pro is distributed through a private Composer repository at `connect.advancedcustomfields.com`. Authentication requires the license email and license key from your ACF account (`https://www.advancedcustomfields.com/my-account/`).

### Step 1 — Export credentials as environment variables

```bash
export ACF_PRO_EMAIL="your@email.com"
export ACF_PRO_KEY="your-license-key-here"
```

These two variables drive `auth.json` generation. Do not hard-code them anywhere — never commit `auth.json` to git.

### Step 2 — Create `auth.json` at the project root

```bash
cat > auth.json << EOF
{
    "http-basic": {
        "connect.advancedcustomfields.com": {
            "username": "${ACF_PRO_EMAIL}",
            "password": "${ACF_PRO_KEY}"
        }
    }
}
EOF
```

Confirm `auth.json` is in `.gitignore` (Bedrock includes this by default):

```bash
grep auth.json .gitignore
```

### Step 3 — Add the private repository to `composer.json`

This goes in the **project root** `composer.json` (Bedrock level), not the theme's.

```json
"repositories": [
    {
        "type": "composer",
        "url": "https://connect.advancedcustomfields.com"
    }
]
```

Add it with Composer to avoid editing JSON manually:

```bash
lando composer config repositories.acf-pro composer https://connect.advancedcustomfields.com
```

### Step 4 — Require ACF Pro

```bash
lando composer require wpengine/advanced-custom-fields-pro
```

Composer will authenticate against `connect.advancedcustomfields.com` using `auth.json` and install the latest Pro release into `web/app/plugins/` (Bedrock's plugin directory).

### Step 5 — Add `ACF_PRO_KEY` to `.env`

Even after installing via Composer, ACF Pro requires the license key at runtime for update checks:

```env
ACF_PRO_KEY=your-license-key-here
```

### Step 6 — Install `log1x/acf-composer` in the theme

ACF Pro is a WordPress plugin (installed at root level). `acf-composer` is a theme-level Laravel package:

```bash
lando theme-composer require log1x/acf-composer
```

Then publish the config:

```bash
lando acorn vendor:publish --provider="Log1x\AcfComposer\AcfComposerServiceProvider"
```

### CI / Team onboarding

For CI pipelines or teammates, `auth.json` must be regenerated from environment variables. Add a bootstrap step:

```bash
# In CI or onboarding script — run before composer install
cat > auth.json << EOF
{
    "http-basic": {
        "connect.advancedcustomfields.com": {
            "username": "${ACF_PRO_EMAIL}",
            "password": "${ACF_PRO_KEY}"
        }
    }
}
EOF
lando composer install
```

Make `ACF_PRO_EMAIL` and `ACF_PRO_KEY` available as secrets in your CI environment (GitHub Actions: Repository Secrets; Forge/Envoyer: Environment Variables).

### Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Could not find package wpengine/advanced-custom-fields-pro` | Repository not added | Run Step 3 |
| `403 Forbidden` from `connect.advancedcustomfields.com` | Wrong credentials in `auth.json` | Re-export envs and recreate `auth.json` |
| `auth.json` not found inside Lando container | File exists on host but not mounted | It should be at the project root — Lando mounts the full project root into `/app` |
| ACF shows "license inactive" in WP admin | `ACF_PRO_KEY` missing from `.env` | Add it (Step 5) |
| Composer asks for credentials interactively | `auth.json` missing or malformed | Recreate from envs |

---

## Blocks

### Anatomy of a Block class

```php
namespace App\Blocks;

use Log1x\AcfComposer\Block;
use Log1x\AcfComposer\Builder;

class Hero extends Block
{
    // -- Metadata --
    public $name = 'Hero';
    public $description = 'Full-width hero section with background image and call-to-action.';
    public $category = 'theme';
    public $icon = 'superhero-alt';
    public $mode = 'preview';
    public $post_types = [];  // Empty = all post types

    // -- Features --
    public $supports = [
        'align' => false,
        'anchor' => true,
        'jsx' => true,
        'mode' => true,
    ];

    // -- Block styles (user selects in editor) --
    public $styles = [
        ['name' => 'light', 'label' => 'Light', 'isDefault' => true],
        ['name' => 'dark', 'label' => 'Dark'],
    ];

    // -- Preview data --
    public $example = [
        'attributes' => [
            'preview' => true,
            'data' => [
                'title' => 'Welcome to Our Site',
                'subtitle' => 'Discover what we can do for you',
            ],
        ],
    ];

    public function with(): array
    {
        return [
            'title' => get_field('title') ?: '',
            'subtitle' => get_field('subtitle') ?: '',
            'background' => get_field('background_image'),
            'cta' => get_field('cta_button'),
            'isPreview' => $this->preview,
        ];
    }

    public function fields(): array
    {
        $fields = Builder::make('hero');

        $fields
            ->addTab('Content')
            ->addText('title', [
                'label' => 'Title',
                'required' => true,
            ])
            ->addTextarea('subtitle', [
                'label' => 'Subtitle',
                'rows' => 2,
            ])
            ->addTab('Media')
            ->addImage('background_image', [
                'label' => 'Background Image',
                'return_format' => 'array',
                'preview_size' => 'medium',
            ])
            ->addTab('CTA')
            ->addLink('cta_button', [
                'label' => 'Call to Action',
                'return_format' => 'array',
            ]);

        return $fields->build();
    }

    public function assets(array $block): void
    {
        // Optional: enqueue block-specific styles/scripts
    }
}
```

### Property reference

- `$name` — display name in the editor block inserter.
- `$description` — shown beneath the block name in the inserter.
- `$category` — block category; use `'theme'` for custom blocks.
- `$icon` — dashicon name without the `dashicons-` prefix.
- `$mode` — `'preview'` renders the Blade view, `'edit'` shows form fields, `'auto'` toggles between both.
- `$post_types` — restrict to specific post types; empty array means all post types.
- `$supports` — controls editor features. Set `jsx: true` to allow `<InnerBlocks />`.
- `$styles` — block style variations selectable in the editor sidebar.
- `$example` — preview data shown in the block inserter and when `$this->preview` is `true`.

### Method reference

- `with()` — returns an associative array of variables available in the Blade view.
- `fields()` — defines ACF fields using the Builder API.
- `assets()` — enqueue block-specific CSS or JS files.

### Block Blade view

```blade
{{-- resources/views/blocks/hero.blade.php --}}
<section class="{{ $block->classes }} relative overflow-hidden">
  @if ($background)
    <img
      src="{{ $background['url'] }}"
      alt="{{ $background['alt'] }}"
      class="absolute inset-0 w-full h-full object-cover"
    />
  @endif

  <div class="relative z-10 container mx-auto px-6 py-24">
    @if ($title)
      <h1 class="text-5xl font-bold">{{ $title }}</h1>
    @endif

    @if ($subtitle)
      <p class="mt-4 text-xl">{{ $subtitle }}</p>
    @endif

    @if ($cta)
      <a href="{{ $cta['url'] }}" target="{{ $cta['target'] }}" class="mt-8 inline-block px-8 py-3 bg-primary text-white rounded-lg">
        {{ $cta['title'] }}
      </a>
    @endif
  </div>
</section>
```

- `$block->classes` includes the block's CSS classes (alignment, custom classes, active style variation).
- Variables come from the `with()` method.
- Always null-check fields — they may be empty in the editor.

## Builder API Reference

### Field types — most commonly used methods

```php
$fields = Builder::make('group_name');

// Text inputs
$fields->addText('field_name', ['label' => 'Label', 'required' => true]);
$fields->addTextarea('field_name', ['label' => 'Label', 'rows' => 4]);
$fields->addNumber('field_name', ['label' => 'Label', 'min' => 0, 'max' => 100]);
$fields->addEmail('field_name', ['label' => 'Label']);
$fields->addUrl('field_name', ['label' => 'Label']);
$fields->addPassword('field_name', ['label' => 'Label']);

// Rich content
$fields->addWysiwyg('field_name', ['label' => 'Label', 'media_upload' => false, 'toolbar' => 'basic']);
$fields->addOembed('field_name', ['label' => 'Label']);

// Selection
$fields->addSelect('field_name', [
    'label' => 'Label',
    'choices' => ['value1' => 'Label 1', 'value2' => 'Label 2'],
    'default_value' => 'value1',
    'return_format' => 'value',
]);
$fields->addRadio('field_name', ['label' => 'Label', 'choices' => [...]]);
$fields->addCheckbox('field_name', ['label' => 'Label', 'choices' => [...]]);
$fields->addTrueFalse('field_name', ['label' => 'Label', 'default_value' => false, 'ui' => true]);
$fields->addButtonGroup('field_name', ['label' => 'Label', 'choices' => [...]]);

// Media
$fields->addImage('field_name', [
    'label' => 'Label',
    'return_format' => 'array',  // 'array', 'url', or 'id'
    'preview_size' => 'medium',
    'mime_types' => 'jpg, jpeg, png, webp',
]);
$fields->addFile('field_name', ['label' => 'Label', 'return_format' => 'array']);
$fields->addGallery('field_name', ['label' => 'Label', 'return_format' => 'array']);

// Relational
$fields->addLink('field_name', ['label' => 'Label', 'return_format' => 'array']);
$fields->addRelationship('field_name', [
    'label' => 'Label',
    'post_type' => ['post'],
    'filters' => ['search', 'post_type'],
    'return_format' => 'object',
]);
$fields->addPostObject('field_name', ['label' => 'Label', 'post_type' => ['page'], 'return_format' => 'object']);
$fields->addPageLink('field_name', ['label' => 'Label', 'post_type' => ['page']]);
$fields->addTaxonomy('field_name', ['label' => 'Label', 'taxonomy' => 'category']);
$fields->addUser('field_name', ['label' => 'Label', 'role' => ['editor', 'author']]);

// Layout
$fields->addTab('Tab Label');
$fields->addAccordion('Accordion Label');
$fields->addMessage('Info', 'message', ['message' => 'Helper text for editors.']);

// Special
$fields->addColorPicker('field_name', ['label' => 'Label', 'default_value' => '#000000']);
$fields->addDatePicker('field_name', ['label' => 'Label', 'display_format' => 'd/m/Y', 'return_format' => 'Y-m-d']);
$fields->addGoogleMap('field_name', ['label' => 'Label', 'center_lat' => -23.55, 'center_lng' => -46.63]);
```

### Repeater fields

```php
$fields
    ->addRepeater('items', ['label' => 'Items', 'layout' => 'block', 'min' => 1, 'max' => 10])
        ->addText('title', ['label' => 'Title'])
        ->addTextarea('description', ['label' => 'Description'])
        ->addImage('icon', ['label' => 'Icon', 'return_format' => 'array'])
    ->endRepeater();
```

### Group fields

```php
$fields
    ->addGroup('address', ['label' => 'Address'])
        ->addText('street')
        ->addText('city')
        ->addText('state')
        ->addText('zip')
    ->endGroup();
```

### Flexible Content

```php
$fields
    ->addFlexibleContent('sections', ['label' => 'Page Sections'])
        ->addLayout('hero', ['label' => 'Hero Section'])
            ->addText('title')
            ->addImage('background', ['return_format' => 'array'])
        ->addLayout('content', ['label' => 'Content Section'])
            ->addWysiwyg('body')
        ->addLayout('gallery', ['label' => 'Gallery Section'])
            ->addGallery('images', ['return_format' => 'array'])
    ->endFlexibleContent();
```

### Conditional logic

```php
$fields
    ->addTrueFalse('has_cta', ['label' => 'Add Call to Action?', 'ui' => true])
    ->addLink('cta_link', ['label' => 'CTA Link'])
        ->conditional('has_cta', '==', '1');
```

## Field Groups (standalone)

For meta boxes on post types (not Gutenberg blocks):

```php
namespace App\Fields;

use Log1x\AcfComposer\Field;
use Log1x\AcfComposer\Builder;

class PostMeta extends Field
{
    public function fields(): array
    {
        $fields = Builder::make('post_meta');

        $fields->setLocation('post_type', '==', 'post');

        $fields
            ->addText('subtitle', ['label' => 'Subtitle'])
            ->addImage('featured_banner', [
                'label' => 'Featured Banner',
                'return_format' => 'array',
            ]);

        return $fields->build();
    }
}
```

### setLocation() — where the field group appears

- `->setLocation('post_type', '==', 'post')` — on posts
- `->setLocation('post_type', '==', 'page')->or('post_type', '==', 'custom_type')` — multiple post types
- `->setLocation('page_template', '==', 'views/template-about.blade.php')` — specific page template
- `->setLocation('options_page', '==', 'global-settings')` — options page

## Partials (reusable field sets)

Created with `lando acorn acf:partial`. Share field definitions across multiple blocks or field groups:

```php
namespace App\Fields\Partials;

use Log1x\AcfComposer\Partial;
use Log1x\AcfComposer\Builder;

class CtaFields extends Partial
{
    public function fields(): array
    {
        $fields = Builder::make('cta_fields');

        $fields
            ->addLink('cta_link', ['label' => 'Link', 'return_format' => 'array'])
            ->addSelect('cta_style', [
                'label' => 'Button Style',
                'choices' => ['primary' => 'Primary', 'secondary' => 'Secondary', 'outline' => 'Outline'],
                'default_value' => 'primary',
            ]);

        return $fields->build();
    }
}
```

### Using a partial in a Block or Field

```php
use App\Fields\Partials\CtaFields;

public function fields(): array
{
    $fields = Builder::make('hero');
    $fields
        ->addText('title')
        ->addFields($this->get(CtaFields::class));
    return $fields->build();
}
```

## Options Pages

Created with `lando acorn acf:options GlobalSettings`:

```php
namespace App\Options;

use Log1x\AcfComposer\Options as Field;
use Log1x\AcfComposer\Builder;

class GlobalSettings extends Field
{
    public $name = 'Global Settings';
    public $slug = 'global-settings';

    public function fields(): array
    {
        $fields = Builder::make('global_settings');

        $fields
            ->addTab('Social Media')
            ->addUrl('facebook_url', ['label' => 'Facebook URL'])
            ->addUrl('instagram_url', ['label' => 'Instagram URL'])
            ->addUrl('linkedin_url', ['label' => 'LinkedIn URL'])
            ->addTab('Contact')
            ->addEmail('contact_email', ['label' => 'Contact Email'])
            ->addText('phone_number', ['label' => 'Phone Number']);

        return $fields->build();
    }
}
```

Accessing options values: `get_field('facebook_url', 'option')` — always pass `'option'` as the second argument.

## Widgets

Created with `lando acorn acf:widget`. With Gutenberg and block-based widget areas, traditional widgets are rarely needed. Use only when the project explicitly requires classic widgets.

---

## Field Keys in Block Data

### Two contexts — two different behaviours

**Inside `with()` (ACF Composer context):**
`get_field('badge_label')` works correctly. ACF Composer sets up the block meta context
automatically — you always use the field **name**.

**Inside block `data` attribute (WP-CLI / raw Gutenberg JSON):**
The Gutenberg block `data` attribute requires field **keys**, not names.
Using field names here returns `null` with no error.

### Field key convention

`field_<block-slug>_<field-name>`

Examples:
| Block slug | Field name | Field key |
|---|---|---|
| `hero` | `badge_label` | `field_hero_badge_label` |
| `about` | `heading` | `field_about_heading` |
| `hero` | `feature_cards` (repeater) | `field_hero_feature_cards` |

### Populating via WP-CLI

```bash
# ✅ Correct — use field key
wp post update 5 --post_content='<!-- wp:acf/hero {"name":"acf/hero","data":{"field_hero_badge_label":"01 / HELLO"}} /-->'

# ❌ Wrong — field name returns null
wp post update 5 --post_content='<!-- wp:acf/hero {"name":"acf/hero","data":{"badge_label":"01 / HELLO"}} /-->'
```

### Diagnostic

```bash
# Confirm a field key works
lando wp eval 'acf_setup_meta(["field_hero_badge_label" => "Test"], 0, true); var_dump(get_field("badge_label"));'
# Expected: string(4) "Test"
```

### Symptom

`get_field()` returns `null` even though the block is on the page and has data in its attributes.
Check the browser DevTools → block markup → `data-*` attributes to see what keys are stored.

---

## Gotchas — validated traps

### `Builder::setLocation()` returns `LocationBuilder`, NOT `$this`

Field classes that chain `setLocation()` into the `Builder::make()` assignment produce
broken field groups with MD5-hash keys (`group_d41d8cd98f00b204...`).

```php
// ❌ Wrong — chain-assign. $fields becomes a LocationBuilder, build() outputs wrong shape.
$fields = Builder::make('depoimento_fields')
    ->setLocation('post_type', '==', 'depoimento');

return $fields->build();


// ✅ Correct — two statements. $fields stays as FieldsBuilder.
$fields = Builder::make('depoimento_fields');
$fields->setLocation('post_type', '==', 'depoimento');

return $fields->build();
```

**Sanity check** after generating a field class:

```bash
lando wp eval 'var_dump(acf_get_field_group("group_<your-field-group-name>"));'
# If result shows `group_d41d8cd98f...` (MD5 empty hash), the field group is broken.
# Split setLocation into a separate statement.
```

### `assets()` never reaches `<head>` on the frontend

ACF Composer's `public function assets(array $block)` registers
`enqueue_block_assets` **inside** `render()`, which fires during `the_content` —
after `wp_head()` has already executed. CSS/JS enqueued there never reaches `<head>`
on the frontend.

**Rule:** `assets()` must remain empty. Enqueue block CSS/JS from
`ThemeServiceProvider::boot()` via `wp_enqueue_scripts` priority 20, gated on
`has_block('acf/{slug}')`. See `block-scaffolding` skill Phase 3 for the canonical
enqueue pattern.

Source: `vendor/log1x/acf-composer/src/Block.php` lines 797–803.

### `$styles` format changed in WP 6.x

| Wrong (old format) | Correct (WP 6.x+) |
|---|---|
| `public $styles = ['light', 'dark'];` | `[['label' => 'Light', 'name' => 'light', 'isDefault' => true], ['label' => 'Dark', 'name' => 'dark']]` |
| `['label' => '...', 'value' => 'light']` | `['label' => '...', 'name' => 'light']` — key is `name`, not `value` |

`register_block_style()` silently ignores entries with the legacy format,
producing a block with no selectable variations.

### `wp_enqueue_style` dependencies must be `[]`

Block CSS compiled by Vite is self-contained — it does not depend on a theme
stylesheet to resolve tokens. Declaring `['theme']` as a dependency causes
WordPress to skip the block CSS when the theme stylesheet is not loaded
(e.g. admin pages with a custom enqueue order).

```php
// ✅ Correct
wp_enqueue_style("block-{$slug}", $asset->uri(), [], $asset->version());

// ❌ Wrong — breaks enqueue when 'theme' isn't loaded
wp_enqueue_style("block-{$slug}", $asset->uri(), ['theme'], $asset->version());
```

### Localizing Block Metadata — `getName()` / `getDescription()` / `getStyles()`

`$name` and `$description` are class properties evaluated at class-load time — they cannot contain localization calls like `__()` because the text domain may not be registered yet. To produce translatable block metadata, override the getter methods instead:

```php
class HeroSection extends Block
{
    public $name = 'Hero Section';  // Fallback (English) — still required
    public $description = 'Full-width hero with background and CTA.';

    public function getName(): string
    {
        return __('Hero Section', 'sage');
    }

    public function getDescription(): string
    {
        return __('Full-width hero with background and CTA.', 'sage');
    }

    public function getStyles(): array
    {
        return [
            ['label' => __('Light', 'sage'), 'name' => 'light', 'isDefault' => true],
            ['label' => __('Dark', 'sage'),  'name' => 'dark'],
        ];
    }
}
```

**When to use:** any project where block names or style labels must appear translated in the Gutenberg block inserter or the editor sidebar.

**Why `$styles` needs override too:** The `$styles` array is echoed into the block inserter UI — style labels appear in the "Styles" panel. If the project has a Spanish or Portuguese admin locale, style labels like "Light" / "Dark" should be translated.
