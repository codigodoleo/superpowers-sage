Deep reference for ACF Composer block variants and the $styles system. Loaded on demand from `skills/block-scaffolding/SKILL.md`.

# Block Variants and $styles

The `$styles` array on an ACF Composer block registers named Gutenberg style variations, each applying an `is-style-{name}` CSS class that the Blade view can target.

## $styles — The Gutenberg Style Picker

`$styles` on an ACF Composer block registers named style variations in the
Gutenberg editor. The selected style applies an `is-style-{name}` class on
the block wrapper in the editor and on the `<section>` wrapper on the frontend.

```php
public $styles = [
    ['label' => 'Light',   'name' => 'light',   'isDefault' => true],
    ['label' => 'Neutral', 'name' => 'neutral'],
    ['label' => 'Dark',    'name' => 'dark'],
];
```

## How the Class Lands in the DOM

- **Editor:** WordPress adds `is-style-{name}` to the block wrapper div.
- **Frontend:** ACF Composer passes block attributes (including `className` which contains `is-style-{name}`) through `get_block_wrapper_attributes()`, which lands on the `<section>` tag via `{!! $block_attrs !!}` in the block view.

Both locations are an **ancestor** of `<block-{slug}>`, so the CSS selector
`.is-style-dark block-{slug}` works identically in editor and frontend.

## CSS Structure for Variants

```css
@reference "../app.css";

block-hero {
  display: block;

  /* Default (Light) tokens */
  --block-bg:   var(--color-surface);
  --block-text: var(--color-foreground);

  color: var(--block-text);
  background: var(--block-bg);
}

.is-style-neutral block-hero {
  --block-bg:   var(--color-surface-muted);
}

.is-style-dark block-hero {
  --block-bg:   var(--color-surface-inverse);
  --block-text: var(--color-foreground-on-inverse);
}
```

**Key rules:**
- One selector per variation — never `&.is-style-neutral, .is-style-neutral &`.
- Only override the tokens that change; inherit all others from the base block rule.
- Never hardcode color values — always use CSS custom properties from the design system.

## $variant in the Blade View

The current style name is available in the view as `$block->style`:

```blade
@php
    $variant = $block->style ?? 'light';
@endphp

<block-hero class="flex flex-col {{ $variant === 'dark' ? 'py-24' : 'py-16' }}">
  {{-- Content --}}
</block-hero>
```

Use `$block->style` sparingly — prefer CSS-driven variants via custom properties.
PHP conditionals are appropriate for structural differences (different Blade
sub-templates, different field combinations) but not for color or spacing tweaks.

## Conditional Fields per Variant

Show or hide ACF fields depending on the selected style:

```php
public function fields(): array
{
    $fields = new FieldsBuilder('hero-block');

    $fields
        ->addText('titulo')
        ->addImage('background_image', [
            'label'             => 'Background Image',
            'conditional_logic' => [
                [
                    [
                        'field'    => 'block_style',  // ACF's internal style field key
                        'operator' => '==',
                        'value'    => 'dark',
                    ],
                ],
            ],
        ]);

    return $fields->build();
}
```

> **Note:** The internal ACF field key for block style is `block_style`. Check
> Field Groups > ACF Composer auto-generated fields if the key differs.

## When to Use PHP vs CSS for Variants

| Scenario | Approach |
|---|---|
| Color / spacing change | CSS custom property override in `.is-style-*` selector |
| Different Blade template | `$block->style` conditional in view |
| Different ACF fields shown | `conditional_logic` on field definition |
| Completely different layout | Separate block classes (avoid over-loading one block) |

## Multiple Dimension Variants

For blocks that need two independent variation axes (e.g. size + color theme),
use ACF select fields rather than `$styles`. `$styles` supports only one active
variant at a time; ACF fields allow arbitrary combinations.

```php
$fields
    ->addSelect('tamanho', [
        'choices' => ['small' => 'Small', 'large' => 'Large'],
    ])
    ->addSelect('tema', [
        'choices' => ['light' => 'Light', 'dark' => 'Dark'],
    ]);
```

Then compose classes in the view:

```blade
<block-hero class="is-size-{{ $tamanho }} is-tema-{{ $tema }}">
```

And handle each combination in CSS with the appropriate selectors.
