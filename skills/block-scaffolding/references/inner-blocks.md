Deep reference for InnerBlocks in ACF Composer blocks. Loaded on demand from `skills/block-scaffolding/SKILL.md`.

# InnerBlocks in ACF Composer Blocks

InnerBlocks renders a nested block editor area inside a parent ACF Composer block, letting editors drop other blocks into a container.

## What InnerBlocks Does

`InnerBlocks` renders a nested block editor area inside a parent block.
Use it for container blocks (sections, columns, cards) that let editors drop
other blocks inside. The rendered inner content is available in the Blade view
via the `$content` variable.

## Block PHP Class — Container Configuration

```php
class SectionWrapper extends Block
{
    public $name = 'Section Wrapper';
    public $category = 'theme-blocks';
    public $icon = 'layout';

    /**
     * Blocks allowed inside this container.
     * Empty array [] allows all blocks.
     */
    public $allowedBlocks = [
        'acf/hero-block',
        'acf/text-block',
        'core/image',
    ];

    /**
     * Default block template pre-populated when the block is first inserted.
     * Each entry: [ 'block-name', attributes, innerBlocks ]
     */
    public $template = [
        ['acf/hero-block', [], []],
    ];

    /**
     * Prevent editors from changing the template structure.
     * 'all' = locked; 'insert' = can edit content but not add/remove blocks.
     */
    // public $templateLock = 'all';

    public function fields(): array
    {
        $fields = new FieldsBuilder('section-wrapper');
        // Fields for the container itself (background colour, spacing override, etc.)
        return $fields->build();
    }

    public function assets(array $block): void
    {
        // Keep empty — enqueue via ThemeServiceProvider
    }
}
```

## Blade View — Rendering InnerBlocks

```blade
@unless ($block->preview)
  <?php $block_attrs = get_block_wrapper_attributes(); ?>
  <section {!! $block_attrs !!}>
@endunless

<block-section-wrapper class="flex flex-col gap-8">
  {{-- $content is the rendered HTML of all inner blocks --}}
  @isset($content)
    {!! $content !!}
  @else
    {{-- Shown only in the editor when no inner blocks are present --}}
    <p class="text-gray-400 text-sm">Add blocks inside this section.</p>
  @endisset
</block-section-wrapper>

@unless ($block->preview)
  </section>
@endunless
```

## $content Variable

ACF Composer automatically populates `$content` with the rendered HTML of
all inner blocks when the block type supports InnerBlocks. `$content` is:

- A string of rendered HTML in the frontend and in editor "preview" mode.
- `null` / empty string when no inner blocks have been added yet.
- **Never escape it** — use `{!! $content !!}` (unescaped), not `{{ $content }}`.

## allowedBlocks

Restricts which blocks can be inserted as children:

```php
// Allow only ACF blocks from this theme
public $allowedBlocks = [
    'acf/card-block',
    'acf/text-block',
];

// Allow all blocks (default when property is omitted)
public $allowedBlocks = [];
```

## template

Pre-populates the inner block area when the container block is first inserted:

```php
public $template = [
    // [ block-name, attributes, innerBlocks ]
    ['acf/hero-block',   ['align' => 'wide'], []],
    ['core/paragraph',   ['placeholder' => 'Add description…'], []],
];
```

## templateLock

| Value | Behaviour |
|---|---|
| `false` (default) | Fully unlocked — editors can add/remove/reorder |
| `'insert'` | Editors can edit existing blocks but not add or remove |
| `'all'` | Completely locked — editors can only edit content inside existing blocks |

## Passing ACF Field Data to Inner Block Context

ACF fields on the container block are accessible in `with()` as usual.
Inner blocks render independently — they cannot directly access the parent's
ACF fields. Pass shared data via Block Context if needed:

```php
// In the parent block class
public $providesContext = [
    'theme/section-style' => 'style',
];

// In the child block class
public $usesContext = ['theme/section-style'];
```

Then in the child block's Blade view: `{{ $block->context['theme/section-style'] ?? '' }}`

## Common Patterns

| Pattern | Implementation |
|---|---|
| Section with free content | `$allowedBlocks = []`, no template |
| Card grid with fixed structure | `$template = [['acf/card', ...]]`, `$templateLock = 'insert'` |
| Column layout | Two container blocks side by side, each with own `$allowedBlocks` |
| Accordion items | Parent locks structure; child blocks render individual panels |
