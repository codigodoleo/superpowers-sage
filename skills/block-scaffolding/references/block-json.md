Deep reference for block.json schema and its relationship with ACF Composer. Loaded on demand from `skills/block-scaffolding/SKILL.md`.

# block.json in ACF Composer Blocks

## When to Use block.json

ACF Composer generates a PHP class that handles registration — `block.json` is **optional** for ACF blocks. Add it when you need:

- `editor_script` / `editor_style` to load custom JS/CSS only in the block editor
- `style` for a stylesheet loaded only when the block is present (both editor and frontend)
- `viewScript` for a frontend-only script
- Block `variations` defined declaratively
- Fine-grained `supports` not expressible via the PHP class properties

## Location and Naming

Place alongside the block class:

```
app/Blocks/HeroBlock.php
app/Blocks/hero-block/block.json   ← optional
```

ACF Composer picks up `block.json` automatically if the file exists in a
directory named after the slug derived from the class.

## Minimal block.json

```json
{
    "$schema": "https://schemas.wp.org/trunk/block.json",
    "apiVersion": 3,
    "name": "acf/hero-block",
    "title": "Hero Block",
    "category": "theme-blocks",
    "icon": "align-wide",
    "description": "Full-width hero with headline and CTA.",
    "keywords": ["hero", "banner"],
    "acf": {
        "mode": "preview",
        "renderTemplate": "resources/views/blocks/hero-block.blade.php"
    }
}
```

## editor_script and editor_style

Load JavaScript or CSS only when the block editor is active:

```json
{
    "editor_script": "file:./editor.js",
    "editor_style":  "file:./editor.css"
}
```

Paths are relative to the `block.json` location. Use `file:` prefix for local assets.

## style (frontend + editor)

For a stylesheet that loads whenever the block is present, on both the
frontend and inside the editor:

```json
{
    "style": "file:./style.css"
}
```

> **Note for Sage:** Prefer the `ThemeServiceProvider::boot()` selective enqueue
> pattern (via `has_block()`) over `style` in `block.json`. The service provider
> approach gives full control over versioning, dependencies, and conditional loading.

## Block Variations

Define editor-level variations (distinct presets) declaratively:

```json
{
    "variations": [
        {
            "name": "hero-centered",
            "title": "Centered Hero",
            "description": "Hero with centered content alignment.",
            "attributes": {
                "className": "is-style-centered"
            },
            "isDefault": true
        },
        {
            "name": "hero-split",
            "title": "Split Hero",
            "attributes": {
                "className": "is-style-split"
            }
        }
    ]
}
```

Variations appear as sub-choices when inserting the block. Each variation can
preset attributes, including `className` to apply an `is-style-*` class.

## Full block.json with Variations

```json
{
    "$schema": "https://schemas.wp.org/trunk/block.json",
    "apiVersion": 3,
    "name": "acf/hero-block",
    "title": "Hero Block",
    "category": "theme-blocks",
    "icon": "align-wide",
    "description": "Full-width hero with headline and CTA.",
    "keywords": ["hero", "banner"],
    "supports": {
        "align": ["wide", "full"],
        "color": {
            "background": true,
            "text": true
        },
        "spacing": {
            "padding": true,
            "margin": true
        }
    },
    "acf": {
        "mode": "preview",
        "renderTemplate": "resources/views/blocks/hero-block.blade.php"
    },
    "variations": [
        {
            "name": "hero-light",
            "title": "Hero — Light",
            "attributes": { "className": "is-style-light" },
            "isDefault": true
        },
        {
            "name": "hero-dark",
            "title": "Hero — Dark",
            "attributes": { "className": "is-style-dark" }
        }
    ]
}
```

## PHP Class vs block.json

When both exist, `block.json` takes precedence for fields it declares.
Prefer PHP class properties for fields ACF Composer manages (`$styles`, `$supports`,
`$spacing`). Use `block.json` only for editor-specific concerns (`editor_script`,
`editor_style`, `variations`) to avoid duplication.
