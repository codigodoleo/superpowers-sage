Deep reference for keeping block edit preview and frontend render consistent. Loaded on demand from `skills/block-scaffolding/SKILL.md`.

# Edit Preview vs Frontend Parity

## The Problem

ACF blocks render twice: once in the Gutenberg editor (preview mode) and once
on the frontend. Differences in CSS loading order, wrapper structure, and
JavaScript availability mean the two renders can diverge.

## Wrapper Structure Differences

The `@unless ($block->preview)` pattern controls which wrapper exists in each context:

```blade
@unless ($block->preview)
  <section {{ $attributes }}>   {{-- only on frontend --}}
@endunless

<block-hero class="flex flex-col">
  ...content...
</block-hero>

@unless ($block->preview)
  </section>                     {{-- only on frontend --}}
@endunless
```

- **Frontend:** `<section>` carries `$attributes` including `is-style-*` classes → CSS variants work.
- **Editor preview:** No `<section>`. WordPress provides its own block wrapper with `is-style-*`. The `block-hero` element is still present and styled correctly.

**Do not** remove `@unless ($block->preview)` — without it, the `<section>` appears
inside the Gutenberg editor iframe, double-wrapping the content.

## CSS Loading in the Editor

Editor CSS is loaded via `resources/css/editor.css`. Every block CSS file must
be imported here for preview styles to match the frontend:

```css
/* resources/css/editor.css */
@import 'tailwindcss';
@import './design-tokens.css';

@source "../views/blocks/**/*.blade.php";

@import './blocks/hero-block.css';
@import './blocks/text-block.css';
/* one import per scaffolded block */
```

If a block CSS file is missing from `editor.css`, the preview is unstyled.

## enqueue_block_assets vs wp_enqueue_scripts

| Hook | When it fires | Use for |
|---|---|---|
| `wp_enqueue_scripts` | Before `wp_head()` | Frontend CSS/JS (preferred for block assets) |
| `enqueue_block_assets` | During block render, inside `the_content` | Dynamically registering editor-only assets |
| `enqueue_block_editor_assets` | Before the editor iframe loads | Scripts/styles only for the block editor |

**For Sage blocks: always use `wp_enqueue_scripts` via `ThemeServiceProvider::boot()`.**
`enqueue_block_assets` fires after `wp_head()` — assets enqueued there never reach `<head>`.

## JavaScript and Custom Elements in the Editor

The Gutenberg editor runs inside an iframe. Custom element definitions loaded
by `wp_enqueue_script` in the frontend context are **not** automatically available
in the editor iframe.

Options:
1. **Accept the gap** — block JS handles interactivity; editor shows static preview (most common).
2. **`enqueue_block_editor_assets`** — load a separate editor-specific script that
   defines the custom element inside the editor iframe.
3. **`editor_script` in block.json** — declare an editor script loaded by WordPress
   directly into the editor context.

For static or near-static blocks, option 1 is correct — the editor preview
does not need the custom element to upgrade.

## Common Drift Causes

| Symptom | Root cause | Fix |
|---|---|---|
| Block looks unstyled in editor | Missing `@import` in `editor.css` | Add the block CSS import |
| Variation colors wrong in editor | `is-style-*` not on an ancestor in editor context | Verify `@unless ($block->preview)` wrapper is present |
| Layout broken in editor only | Different box model for editor wrapper | Add `display: block` on the custom element |
| Custom element not upgrading in editor | JS not loaded in editor iframe | Accept the gap or add `enqueue_block_editor_assets` |
| `$attributes` missing spacing classes | `$spacing` not declared in block class | Always declare `$spacing` |
| Preview and frontend spacing differ | Block CSS has pixel values instead of design tokens | Replace with `var(--block-*)` tokens |

## Verifying Parity

1. Open the block in the Gutenberg editor — preview should match the design.
2. Visit the published page — frontend should match the editor preview.
3. Switch between style variants in the editor (Light / Neutral / Dark) and
   confirm colors update immediately.
4. Run `lando theme-build` and hard-refresh to rule out stale caches.
5. Check DevTools: `<link href="*/block-{slug}-*.css">` should be present in the
   `<head>` on the frontend.
