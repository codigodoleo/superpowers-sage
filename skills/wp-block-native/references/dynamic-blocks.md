Deep reference for dynamic-blocks. Loaded on demand from `skills/wp-block-native/SKILL.md`.

# Dynamic Blocks

Dynamic blocks skip the `save` function and render via PHP — the recommended pattern for blocks that query WordPress data.

## Why Dynamic Blocks

Use a dynamic block when the rendered output depends on live data:
- Post lists, recent posts, related content
- User-specific output (login state, capabilities)
- Options or settings that change independently of post content
- Any block whose markup must always reflect the current state of the database

Static blocks (with a `save` function) serialize their output into the post content. If the data changes, the stored HTML becomes stale. Dynamic blocks always re-render fresh.

## Setting Up a Dynamic Block

In `block.json`, use the `render` key instead of relying on `save`:

```json
{
    "name": "sage/recent-projects",
    "render": "file:./render.php"
}
```

In JS, set `save: () => null`:

```jsx
import { registerBlockType } from '@wordpress/blocks';
import Edit from './edit';
import metadata from './block.json';

registerBlockType(metadata.name, {
    edit: Edit,
    save: () => null,   // Dynamic block — no static output
});
```

## PHP Render Template

```php
// resources/scripts/editor/blocks/recent-projects/render.php
<?php
/** @var array $attributes */
/** @var string $content */
/** @var WP_Block $block */

$projects = new WP_Query([
    'post_type'      => 'project',
    'posts_per_page' => (int) ($attributes['count'] ?? 3),
    'post_status'    => 'publish',
]);
?>
<div <?php echo get_block_wrapper_attributes(['class' => 'recent-projects']); ?>>
    <?php foreach ($projects->posts as $project): ?>
        <article>
            <h2><a href="<?php echo esc_url(get_permalink($project)); ?>">
                <?php echo esc_html($project->post_title); ?>
            </a></h2>
        </article>
    <?php endforeach; ?>
</div>
```

**Important:** Always call `get_block_wrapper_attributes()` on the root element — this applies block supports (color, spacing, custom classes) defined in `block.json`.

## Blade Integration

For deeper Sage/Blade integration, wrap the PHP render in a Blade view call:

```php
// render.php
echo \Roots\view('blocks.recent-projects', [
    'attributes' => $attributes,
    'content'    => $content,
    'block'      => $block,
])->render();
```

```blade
{{-- resources/views/blocks/recent-projects.blade.php --}}
<div {!! get_block_wrapper_attributes(['class' => 'recent-projects']) !!}>
    @foreach($projects as $project)
        <article>
            <h2><a href="{{ get_permalink($project) }}">{{ $project->post_title }}</a></h2>
        </article>
    @endforeach
</div>
```

## Editor Preview with ServerSideRender

Show a live server-rendered preview in the editor:

```jsx
import ServerSideRender from '@wordpress/server-side-render';
import { useBlockProps, InspectorControls } from '@wordpress/block-editor';
import { PanelBody, RangeControl } from '@wordpress/components';

export default function Edit({ attributes, setAttributes }) {
    const blockProps = useBlockProps();
    return (
        <>
            <InspectorControls>
                <PanelBody title="Settings">
                    <RangeControl
                        label="Number of projects"
                        value={attributes.count}
                        onChange={(count) => setAttributes({ count })}
                        min={1}
                        max={12}
                    />
                </PanelBody>
            </InspectorControls>
            <div {...blockProps}>
                <ServerSideRender block="sage/recent-projects" attributes={attributes} />
            </div>
        </>
    );
}
```

## InnerBlocks with Dynamic Rendering

Dynamic blocks can also use InnerBlocks. The `$content` variable in the PHP render template contains the rendered inner blocks HTML:

```php
<div <?php echo get_block_wrapper_attributes(); ?>>
    <?php echo $content; ?>  <?php // Inner blocks rendered HTML ?>
</div>
```

```jsx
// In the JS save function — must output InnerBlocks placeholder for the block editor
import { useBlockProps, useInnerBlocksProps } from '@wordpress/block-editor';

export default function Save() {
    const blockProps = useBlockProps.save();
    const innerBlocksProps = useInnerBlocksProps.save(blockProps);
    return <div {...innerBlocksProps} />;
}
```

Note: even for dynamic blocks using InnerBlocks, the `save` function must return the InnerBlocks placeholder (not `null`). Only the outer wrapper is re-rendered dynamically; the inner blocks are stored and passed as `$content`.
