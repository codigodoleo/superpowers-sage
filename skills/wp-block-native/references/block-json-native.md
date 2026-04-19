Deep reference for block-json-native. Loaded on demand from `skills/wp-block-native/SKILL.md`.

# block.json for Native Gutenberg Blocks

`block.json` fields for native Gutenberg blocks — apiVersion, attributes, supports, editorScript, viewScript, and the PHP/JS split.

## Complete block.json Example

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

## Key Fields Reference

| Field | Purpose | Notes |
|---|---|---|
| `apiVersion` | Block API version | Use `3` for WP 6.3+; enables `interactivity` API |
| `name` | Block identifier | Format: `namespace/block-name`. Use `sage/` prefix |
| `attributes` | Block data definition | Typed; source binds to DOM (html/attribute/text) |
| `supports` | Automatic UI controls | Color, spacing, typography add editor controls without code |
| `editorScript` | JS bundle for editor | Relative `file:` path from block.json location |
| `viewScript` | JS for front-end | Only loaded on pages rendering the block |
| `style` | CSS for both contexts | Loaded in editor and front-end |
| `editorStyle` | CSS for editor only | Adds editor-specific visual polish |
| `render` | PHP render template | Replaces `save` for dynamic blocks |

## Attribute Source Types

```json
{
    "attributes": {
        "content": {
            "type": "string",
            "source": "html",
            "selector": "p"
        },
        "url": {
            "type": "string",
            "source": "attribute",
            "selector": "img",
            "attribute": "src"
        },
        "alignment": {
            "type": "string",
            "default": "left"
        },
        "items": {
            "type": "array",
            "default": []
        }
    }
}
```

- `"source": "html"` — reads inner HTML of the selector
- `"source": "attribute"` — reads an HTML attribute
- No `source` — stored in the block comment delimiter (JSON in `<!-- wp:... -->`)

## Block Supports

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

## Registering a Block in Sage

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
