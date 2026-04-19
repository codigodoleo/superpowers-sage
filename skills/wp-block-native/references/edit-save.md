Deep reference for edit-save. Loaded on demand from `skills/wp-block-native/SKILL.md`.

# Block edit and save Functions

The `edit` function (interactive editor UI) and `save` function (static serialized output) — their contract, constraints, and when `ServerSideRender` replaces `save`.

## The Contract

- **`edit`** — React component rendered in the block editor. Can be interactive, use hooks, and access WordPress data stores. Output is not stored.
- **`save`** — Pure function that returns the static HTML stored in the post. Must be deterministic and produce the same output given the same attributes.

If `save` output changes (after a code update), previously saved blocks show "This block contains unexpected or invalid content." Fix by adding a [deprecation](./dynamic-blocks.md) or converting to a dynamic block.

## Block Registration Entry Point

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

## edit Component

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

## save Function

The `save` function must be a pure function — no hooks, no API calls, no side effects:

```jsx
// resources/scripts/editor/blocks/hero/save.js
import { useBlockProps, RichText } from '@wordpress/block-editor';

export default function Save({ attributes }) {
    const blockProps = useBlockProps.save({ className: 'hero' });

    return (
        <div {...blockProps}>
            {attributes.mediaUrl && <img src={attributes.mediaUrl} alt="" />}
            <RichText.Content tagName="h1" value={attributes.heading} />
        </div>
    );
}
```

## Block Deprecations (Safe Markup Changes)

**MUST include deprecations when changing saved markup.** Without them, previously saved blocks show "unexpected or invalid content" errors.

```jsx
const deprecated = [
    {
        // v1: original markup used h2
        attributes: {
            heading: { type: 'string', source: 'html', selector: 'h2' },
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
    save,       // v2: now uses h1 instead of h2
    deprecated,
});
```

WordPress tries each deprecation in order (newest to oldest) until one successfully validates. An optional `migrate` function transforms attributes between versions.

## When to Use ServerSideRender Instead

If the block's front-end output depends on live WordPress data (posts, options, user state), use `ServerSideRender` in the editor with a PHP render callback on the front end:

```jsx
import { useBlockProps } from '@wordpress/block-editor';
import ServerSideRender from '@wordpress/server-side-render';

export default function Edit({ attributes }) {
    const blockProps = useBlockProps();
    return (
        <div {...blockProps}>
            <ServerSideRender block="sage/hero" attributes={attributes} />
        </div>
    );
}
```

This calls the PHP render callback for a live preview in the editor. Use `save: () => null` with this pattern (dynamic block — no static save).

## Common Failure Modes

- **"This block contains unexpected or invalid content":** Save function output does not match stored HTML. Either fix the save function or add a deprecation.
- **`useBlockProps()` missing in save:** Block supports (color, spacing) won't apply. Always spread `useBlockProps.save()` on the root element.
- **InnerBlocks not rendering on front end:** For dynamic blocks using InnerBlocks, the `$content` variable contains the inner blocks' rendered HTML. Make sure to `echo $content` in the PHP template.
