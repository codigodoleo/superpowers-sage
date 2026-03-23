---
name: wp-block-native
description: "Native WordPress block development — when ACF Composer doesn't suffice, block.json, deprecations, InnerBlocks, block supports"
user-invocable: false
---
# Native WordPress Block Development

## When to use

When building editor blocks that require capabilities beyond what ACF Composer provides: InnerBlocks nesting, block transforms, block variations, JS-heavy editor UI, or block deprecations. Also use when you need fine-grained control over the editor experience or when a block's primary complexity is in its editor behavior rather than its field configuration.

## Inputs required

- The block's purpose and editor behavior requirements
- Whether ACF Composer could handle it (use the decision table below)
- Target WordPress version (determines apiVersion and available block supports)
- Whether the block needs InnerBlocks, transforms, or deprecations

## Procedure

### 1. Decision table: ACF Composer vs Native blocks

| Requirement | ACF Composer | Native Block |
|---|---|---|
| Complex field groups (repeaters, flexible content) | Best choice | Avoid |
| Options UI / settings panels | Best choice | Possible but more work |
| InnerBlocks (nested block areas) | Not supported | Required |
| Block transforms (convert between block types) | Not supported | Required |
| Block variations (same block, different presets) | Limited | Full support |
| JS-heavy editor controls | Limited | Full support |
| Block deprecations (safe markup changes) | Not applicable | Required |
| Quick data-entry blocks | Best choice | Overkill |
| Design-system components | Good | Good |

**Both can coexist in the same project.** ACF blocks and native blocks appear side by side in the inserter. Choose per-block based on requirements.

### 2. Block structure in a Sage project

```
resources/
  scripts/
    editor/
      blocks/
        hero/
          index.js          # Block registration (edit + save)
          edit.js            # Editor component
          save.js            # Save component (or null for dynamic)
          style.css          # Front-end styles
          editor.css         # Editor-only styles
  views/
    blocks/
      hero.blade.php        # PHP render template (dynamic blocks)
app/
  Blocks/
    Hero.php                # Optional: PHP registration class
block.json                  # OR in resources/scripts/editor/blocks/hero/
```

### 3. block.json as single source of truth

Use apiVersion 3 for WordPress 6.3+:

```json
{
    "$schema": "https://schemas.wp.org/trunk/block.json",
    "apiVersion": 3,
    "name": "sage/hero",
    "version": "1.0.0",
    "title": "Hero",
    "category": "theme",
    "icon": "cover-image",
    "description": "A hero banner with heading, text, and call-to-action.",
    "keywords": ["banner", "hero", "header"],
    "textdomain": "sage",
    "attributes": {
        "heading": {
            "type": "string",
            "source": "html",
            "selector": "h1"
        },
        "mediaId": {
            "type": "number"
        },
        "mediaUrl": {
            "type": "string",
            "source": "attribute",
            "selector": "img",
            "attribute": "src"
        }
    },
    "supports": {
        "align": ["wide", "full"],
        "anchor": true,
        "color": {
            "background": true,
            "text": true,
            "gradients": true
        },
        "spacing": {
            "padding": true,
            "margin": ["top", "bottom"]
        },
        "typography": {
            "fontSize": true,
            "lineHeight": true
        }
    },
    "editorScript": "file:./index.js",
    "editorStyle": "file:./editor.css",
    "style": "file:./style.css",
    "render": "file:./render.php"
}
```

### 4. Editor script (edit component)

```jsx
// resources/scripts/editor/blocks/hero/index.js
import { registerBlockType } from '@wordpress/blocks';
import Edit from './edit';
import save from './save';
import metadata from './block.json';

registerBlockType(metadata.name, {
    edit: Edit,
    save,  // Use `save: () => null` for dynamic (PHP-rendered) blocks
});
```

```jsx
// resources/scripts/editor/blocks/hero/edit.js
import { useBlockProps, RichText, MediaUpload, MediaUploadCheck } from '@wordpress/block-editor';
import { Button } from '@wordpress/components';

export default function Edit({ attributes, setAttributes }) {
    const blockProps = useBlockProps({ className: 'hero' });

    return (
        <div {...blockProps}>
            <MediaUploadCheck>
                <MediaUpload
                    onSelect={(media) => setAttributes({ mediaId: media.id, mediaUrl: media.url })}
                    allowedTypes={['image']}
                    value={attributes.mediaId}
                    render={({ open }) => (
                        <Button onClick={open} variant="secondary">
                            {attributes.mediaUrl ? 'Replace Image' : 'Upload Image'}
                        </Button>
                    )}
                />
            </MediaUploadCheck>
            {attributes.mediaUrl && <img src={attributes.mediaUrl} alt="" />}
            <RichText
                tagName="h1"
                value={attributes.heading}
                onChange={(heading) => setAttributes({ heading })}
                placeholder="Enter heading..."
            />
        </div>
    );
}
```

### 5. Dynamic rendering with PHP

For blocks that render via PHP (recommended for Sage/Blade integration), set `save: () => null` in JS and use the `render` key in block.json:

```php
// resources/scripts/editor/blocks/hero/render.php
// OR use a Blade template via a wrapper:

<?php
/** @var array $attributes */
/** @var string $content */
/** @var WP_Block $block */
?>
<div <?php echo get_block_wrapper_attributes(['class' => 'hero']); ?>>
    <?php if (!empty($attributes['mediaUrl'])): ?>
        <img src="<?php echo esc_url($attributes['mediaUrl']); ?>" alt="" />
    <?php endif; ?>
    <?php if (!empty($attributes['heading'])): ?>
        <h1><?php echo wp_kses_post($attributes['heading']); ?></h1>
    <?php endif; ?>
</div>
```

### 6. Block deprecations

**MUST include deprecations when changing saved markup.** Without them, previously saved blocks show "This block contains unexpected or invalid content" errors.

```jsx
// In save.js or index.js
const deprecated = [
    {
        // v1: original markup
        attributes: {
            heading: { type: 'string', source: 'html', selector: 'h2' },  // Was h2
        },
        save({ attributes }) {
            const blockProps = useBlockProps.save();
            return (
                <div {...blockProps}>
                    <h2>{attributes.heading}</h2>
                </div>
            );
        },
    },
];

registerBlockType(metadata.name, {
    edit: Edit,
    save,  // v2: now uses h1 instead of h2
    deprecated,
});
```

WordPress tries each deprecation in order (newest to oldest) until one successfully validates. The validated content is then migrated using an optional `migrate` function.

### 7. InnerBlocks

The primary reason to choose native blocks over ACF Composer:

```jsx
import { useBlockProps, useInnerBlocksProps } from '@wordpress/block-editor';

export default function Edit() {
    const blockProps = useBlockProps({ className: 'card-grid' });
    const innerBlocksProps = useInnerBlocksProps(blockProps, {
        allowedBlocks: ['sage/card', 'core/paragraph'],
        template: [
            ['sage/card', {}],
            ['sage/card', {}],
            ['sage/card', {}],
        ],
        templateLock: false,  // false | 'all' | 'insert' | 'contentOnly'
        orientation: 'horizontal',
    });

    return <div {...innerBlocksProps} />;
}

// save.js for InnerBlocks
import { useBlockProps, useInnerBlocksProps } from '@wordpress/block-editor';

export default function Save() {
    const blockProps = useBlockProps.save({ className: 'card-grid' });
    const innerBlocksProps = useInnerBlocksProps.save(blockProps);

    return <div {...innerBlocksProps} />;
}
```

### 8. Block supports

Block supports automatically add UI controls and apply styles without custom code:

```json
{
    "supports": {
        "align": true,
        "anchor": true,
        "className": true,
        "color": {
            "background": true,
            "text": true,
            "gradients": true,
            "link": true
        },
        "spacing": {
            "padding": true,
            "margin": true,
            "blockGap": true
        },
        "typography": {
            "fontSize": true,
            "lineHeight": true,
            "fontFamily": true
        },
        "html": false
    }
}
```

Styles from block supports are applied automatically via `get_block_wrapper_attributes()` in PHP or `useBlockProps()` in JS.

### 9. Block patterns and variations

**Variations** (different presets of the same block):

```jsx
// In index.js
registerBlockType(metadata.name, {
    edit: Edit,
    save,
    variations: [
        {
            name: 'hero-centered',
            title: 'Hero (Centered)',
            attributes: { alignment: 'center' },
            isDefault: true,
        },
        {
            name: 'hero-left',
            title: 'Hero (Left Aligned)',
            attributes: { alignment: 'left' },
        },
    ],
});
```

**Patterns** (predefined block arrangements):

```php
// In ServiceProvider boot()
register_block_pattern('sage/hero-with-cta', [
    'title' => 'Hero with CTA',
    'categories' => ['hero'],
    'content' => '<!-- wp:sage/hero {"align":"full"} -->
        <!-- wp:paragraph --><p>Welcome</p><!-- /wp:paragraph -->
        <!-- wp:buttons --><div class="wp-block-buttons"><!-- wp:button --><div class="wp-block-button"><a class="wp-block-button__link">Learn More</a></div><!-- /wp:button --></div><!-- /wp:buttons -->
    <!-- /wp:sage/hero -->',
]);
```

### 10. Registering blocks in Sage

```php
// In a ServiceProvider boot() method
public function boot(): void
{
    add_action('init', function () {
        register_block_type(
            resource_path('scripts/editor/blocks/hero/block.json')
        );
    });
}
```

### 11. Editor assets with Vite

Create a separate Vite entry point for editor scripts:

```js
// vite.config.js
export default defineConfig({
    plugins: [
        laravel({
            input: [
                'resources/css/app.css',
                'resources/js/app.js',
                'resources/scripts/editor/index.js',  // Editor entry point
            ],
        }),
    ],
});
```

```js
// resources/scripts/editor/index.js
import './blocks/hero';
import './blocks/card';
import './blocks/card-grid';
```

Enqueue the editor bundle:

```php
add_action('enqueue_block_editor_assets', function () {
    // Use Vite's asset helper to enqueue the editor bundle
    wp_enqueue_script(
        'sage-editor-blocks',
        Vite::asset('resources/scripts/editor/index.js'),
        ['wp-blocks', 'wp-element', 'wp-block-editor', 'wp-components'],
        null,
        true
    );
});
```

### 12. Coexistence with ACF blocks

ACF blocks and native blocks use different registration methods but appear in the same inserter:

- **ACF blocks:** Registered via `acf_register_block_type()` or ACF Composer classes. Use PHP render callbacks. Fields defined in ACF.
- **Native blocks:** Registered via `register_block_type()` with block.json. Use JS edit/save or PHP render. Attributes defined in block.json.

Both work in the same editor. No conflicts as long as block names are unique.

## Verification

1. Block appears in the editor inserter under the correct category.
2. Block renders correctly in the editor (edit component).
3. Block saves without validation errors (save component matches output).
4. Block renders correctly on the front end (PHP render or saved HTML).
5. Block supports (color, spacing, typography) apply styles correctly.
6. Deprecations: edit a post with an old version of the block, update the block code, and confirm the editor recovers gracefully without "Invalid block" errors.
7. InnerBlocks: child blocks can be added, removed, and reordered within the parent.

## Failure modes

- **"This block contains unexpected or invalid content":** Save function output does not match stored HTML. Either fix save function or add a deprecation.
- **Block not appearing in inserter:** block.json not found by `register_block_type()`, or editor script not enqueued. Check file paths.
- **Styles not applying:** Missing `get_block_wrapper_attributes()` in PHP render or `useBlockProps()` in JS. Block supports require these wrappers.
- **InnerBlocks empty on front end:** For dynamic blocks using InnerBlocks, the `$content` variable in the render template contains the inner blocks' rendered HTML. Make sure to echo it.
- **Editor script errors:** Missing WordPress script dependencies. Ensure `wp-blocks`, `wp-element`, `wp-block-editor` are listed as dependencies.
- **Vite HMR not working for editor:** Editor scripts may need a full page reload. Vite HMR works best for front-end assets.

## Escalation

- If block deprecations are not recovering old content, check that the deprecated `save` function exactly reproduces the old output. Use browser console to compare expected vs actual HTML.
- If `register_block_type()` silently fails, enable `WP_DEBUG` and check for errors. Common cause: invalid block.json syntax or missing required fields.
- For complex InnerBlocks patterns (deeply nested, template-locked), consider whether a block pattern might be simpler than a custom parent block.
- When the editor experience requires extensive custom JS (custom sidebars, complex state), consider whether a plugin-based approach might be cleaner than embedding everything in the theme.
