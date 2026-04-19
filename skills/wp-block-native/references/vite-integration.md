Deep reference for vite-integration. Loaded on demand from `skills/wp-block-native/SKILL.md`.

# Building Native Blocks with Vite

Building native blocks with Vite in a Sage theme — wiring `block.json` `editorScript` to a Vite entry point and avoiding `@wordpress/scripts` conflicts.

## Architecture Overview

Sage uses Vite as the build tool, not `@wordpress/scripts`. This means:
- Block JS is compiled by Vite, not `wp-scripts build`
- `block.json` `editorScript` and `viewScript` fields must point to files that Vite knows about
- WordPress script dependencies (`wp-blocks`, `wp-element`, etc.) must be declared manually — Vite does not auto-extract them from import statements like `@wordpress/scripts` does

## Vite Configuration

Create a dedicated editor entry point:

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
// resources/scripts/editor/index.js — imports all blocks
import './blocks/hero';
import './blocks/card';
import './blocks/card-grid';
```

## Enqueuing the Editor Bundle

```php
add_action('enqueue_block_editor_assets', function () {
    wp_enqueue_script(
        'sage-editor-blocks',
        Vite::asset('resources/scripts/editor/index.js'),
        ['wp-blocks', 'wp-element', 'wp-block-editor', 'wp-components'],
        null,
        true
    );
});
```

Declare all `@wordpress/*` packages your blocks use as dependencies. WordPress loads these from its own bundled copies; do not bundle them with Vite.

## block.json editorScript with Vite

Because Vite builds a bundle (not individual files per block), the `editorScript` field in `block.json` cannot point directly to the Vite-compiled output for each block individually. Instead:

**Option A — Single bundle approach (simplest):**

Leave `editorScript` out of `block.json` and use the `enqueue_block_editor_assets` hook above to enqueue the single compiled bundle. All blocks register themselves when the bundle loads.

**Option B — Per-block entry points:**

Configure Vite with multiple entries and use `wp_register_block_script_handle` or point `editorScript` to a Vite-generated asset:

```php
// Register each block type manually with the compiled asset URL
add_action('init', function () {
    $heroAsset = Vite::asset('resources/scripts/editor/blocks/hero/index.js');
    wp_register_script('sage-block-hero', $heroAsset, ['wp-blocks', 'wp-element', 'wp-block-editor'], null, true);

    register_block_type(resource_path('scripts/editor/blocks/hero/block.json'), [
        'editor_script' => 'sage-block-hero',
    ]);
});
```

## Avoiding @wordpress/scripts Conflicts

If `@wordpress/scripts` is installed alongside Vite (e.g., via a dependency), ensure it does not run its own build step that overwrites Vite output:

- Remove `build` and `start` scripts in `package.json` that point to `wp-scripts`
- Import `@wordpress/*` packages as externals in Vite — do not bundle them:

```js
// vite.config.js
export default defineConfig({
    build: {
        rollupOptions: {
            external: [
                '@wordpress/blocks',
                '@wordpress/block-editor',
                '@wordpress/components',
                '@wordpress/element',
                '@wordpress/i18n',
                '@wordpress/data',
            ],
            output: {
                globals: {
                    '@wordpress/blocks': 'wp.blocks',
                    '@wordpress/block-editor': 'wp.blockEditor',
                    '@wordpress/components': 'wp.components',
                    '@wordpress/element': 'wp.element',
                    '@wordpress/i18n': 'wp.i18n',
                    '@wordpress/data': 'wp.data',
                },
            },
        },
    },
});
```

## Block Structure in Sage

```
resources/
  scripts/
    editor/
      blocks/
        hero/
          index.js          # Block registration (registerBlockType)
          edit.js            # Editor React component
          save.js            # Save function (or null for dynamic blocks)
          style.css          # Front-end styles
          editor.css         # Editor-only styles
          block.json        # Block metadata
      index.js              # Entry: imports all blocks
```

## Failure Modes

- **Block not appearing in inserter:** Editor bundle not enqueued or `registerBlockType` not called. Check browser console for JS errors.
- **Editor script errors — "wp is not defined":** `@wordpress/*` packages bundled by Vite instead of treated as externals. Add them to the externals list.
- **Vite HMR not working for editor:** Editor scripts may need a full page reload. Vite HMR works best for front-end assets; accept the reload workflow for block development.
- **Block styles not loading:** `style.css` or `editor.css` not listed in `block.json` or not in the Vite input list.
