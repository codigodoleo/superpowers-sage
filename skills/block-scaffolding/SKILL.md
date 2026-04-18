---
name: superpowers-sage:block-scaffolding
description: Scaffold a new ACF Composer block with custom element identity, 4-layer CSS contract, theme variations via native $styles, selective CSS+JS enqueue, and block README. Auto-invoked by /building after acorn scaffold. For evolving existing blocks, use /block-refactoring instead.
user-invocable: true
argument-hint: "<BlockClassName or block-slug>"
---

# Block Scaffolding — Custom Element Contract per Block

Scaffold a new ACF block with the full custom element architecture: scoped CSS, theme
variations, optional JS lifecycle, correct enqueue, and documentation.

**Announce at start:** "I'm using the block-scaffolding skill to create the block."

## When to use

- **Auto-invoked by `/building`**: after `lando acorn acf:block` produces a new stub
- **Standalone new block**: a block outside of a plan

## When NOT to use

- **Existing block that needs evolution** → use `/block-refactoring` instead. This skill
  creates from scratch; it does NOT audit or retrofit.
- **Non-block UI component (Button, Eyebrow, Card)** → those are Blade components, not
  ACF blocks. Create via standard Blade component files.

## Input

$ARGUMENTS

Resolve to `{ClassName}` (PascalCase) and `{slug}` (kebab-case) before proceeding. If
not provided, ask the user which block to scaffold.

---

## Hard prerequisites

### P1. Slug must produce a valid custom element tag

The custom element tag name is `block-{slug}`. The Custom Elements spec requires a
hyphen in the tag name — the `block-` prefix always provides it, so any slug is valid.

### P2. Design system foundation

```
resources/css/design-tokens.css   — must exist
resources/views/components/ui/    — must contain at least button + heading
```

If missing:
```
⛔ Design system not validated.
   Run /sage-design-system first, then return here.
```

### P3. BaseCustomElement in theme

```
resources/js/core/BaseCustomElement.js   — must exist
```

If missing, copy from the plugin template at `templates/BaseCustomElement.js` to the
theme path. Do NOT proceed without it.

---

## Operation modes

| Mode | When to use | `$styles` | CSS variation blocks |
|---|---|---|---|
| **Full** | Block needs light/neutral/dark theme switching | 3 entries | 3 `.is-style-*` selectors |
| **Minimal** | Block has a single fixed appearance (footer, nav, ticker, decorative) | absent | base tokens only |

Both modes always produce: scoped CSS via tag selector `block-{slug}`, custom element
definition, optional JS stub, selective enqueue, README.

---

## The 5-layer contract

```
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 1 · design-tokens.css + UI Blade components               │
│  Typography via <x-ui.heading :level="N">, buttons via           │
│  <x-ui.button variant="primary">. Foundation from                │
│  /sage-design-system.                                            │
├──────────────────────────────────────────────────────────────────┤
│  LAYER 2 · resources/css/blocks/{slug}.css                       │
│  Visual appearance scoped to tag selector block-{slug}.          │
│  Theme variations via .is-style-* ancestor selectors.            │
│  display: block/flex/grid declared (overrides inline default).   │
├──────────────────────────────────────────────────────────────────┤
│  LAYER 3 · resources/js/blocks/{slug}.js (lifecycle)             │
│  Class extends BaseCustomElement. init() holds behavior.         │
│  Empty init() is valid for static blocks.                        │
├──────────────────────────────────────────────────────────────────┤
│  LAYER 4 · Blade view                                            │
│  @unless ($block->preview) <section {{ $attributes }}> wrapper   │
│  + <block-{slug}> custom element inner.                          │
│  Structural utilities (flex, grid, gap) on the custom element.   │
├──────────────────────────────────────────────────────────────────┤
│  LAYER 5 · ThemeServiceProvider::boot()                          │
│  Selective enqueue: has_block("acf/{slug}") priority 20.         │
│  Enqueue CSS always; JS only if file exists.                     │
│  NEVER enqueue in assets() — timing issue documented in S2.      │
└──────────────────────────────────────────────────────────────────┘
```

**Golden rule:** a block is correct when you can switch all variations via WordPress
style picker without editing Blade, and the custom element upgrades cleanly whether JS
is present or not.

---

## Phase 0 — Generate with localization

```bash
lando acorn acf:block {ClassName} --localize
```

This produces:
- `app/Blocks/{ClassName}.php` — controller stub with localization-ready wrappers
- `resources/views/blocks/{slug}.blade.php` — view stub

---

## Phase 1 — Decide mode

Ask (or infer): does this block need theme variations (light/neutral/dark)?

- Yes → **Full mode**
- No → **Minimal mode**

---

## Phase 2 — Implement S1–S5

### S1 — `resources/css/blocks/{slug}.css`

**Full mode:**

```css
@reference "../app.css";

block-{slug} {
  display: block;

  /* Light (default) */
  --block-bg:        var(--color-surface);
  --block-text:      var(--color-foreground);
  --block-text-sub:  var(--color-foreground-muted);
  --block-border:    var(--color-border);
  --block-btn-bg:    var(--color-foreground);
  --block-btn-text:  var(--color-foreground-on-inverse);
  --block-btn-hover: var(--color-surface-inverse);

  color: var(--block-text);
  background: var(--block-bg);
  overflow: hidden;
}

/* Neutral — class lives on an ancestor (WP wrapper in editor, section in frontend) */
.is-style-neutral block-{slug} {
  --block-bg:     var(--color-surface-muted);
  --block-border: var(--color-border-strong);
}

/* Dark */
.is-style-dark block-{slug} {
  --block-bg:        var(--color-surface-inverse);
  --block-text:      var(--color-foreground-on-inverse);
  --block-text-sub:  color-mix(in srgb, var(--color-foreground-on-inverse) 60%, transparent);
  --block-border:    color-mix(in srgb, var(--color-foreground-on-inverse) 20%, transparent);
  --block-btn-bg:    var(--color-foreground-on-inverse);
  --block-btn-text:  var(--color-foreground);
  --block-btn-hover: color-mix(in srgb, var(--color-foreground-on-inverse) 90%, transparent);
}
```

**Minimal mode** (omit variation selectors):

```css
@reference "../app.css";

block-{slug} {
  display: block;

  --block-bg:       var(--color-surface);
  --block-text:     var(--color-foreground);
  --block-text-sub: var(--color-foreground-muted);
  --block-border:   var(--color-border);

  color: var(--block-text);
  background: var(--block-bg);
  overflow: hidden;
}
```

**Implementation notes:**
- `@reference` (NOT `@import`) — grants Tailwind token access at build time without
  duplicating the full stylesheet
- Tag selector `block-{slug}` — no class needed; the custom element IS the hook
- `.is-style-* block-{slug}` — single-selector variation, works in both frontend and
  editor because `is-style-*` always lands on an ancestor
- `display: block` — mandatory; custom elements default to `inline`

### S2 — `app/Blocks/{ClassName}.php`

Extend the generated stub with the full canonical shape:

```php
<?php

namespace App\Blocks;

use Log1x\AcfComposer\Block;
use StoutLogic\AcfBuilder\FieldsBuilder;

class {ClassName} extends Block
{
    public $name = '{Human Name}';
    public $description = '{One-line description}';
    public $category = '{project-category}';
    public $icon = '{dashicons-name}';
    public $keywords = ['{keyword1}', '{keyword2}'];

    /**
     * The default block spacing.
     * null = control enabled; empty array = disabled.
     */
    public $spacing = [
        'padding' => null,
        'margin'  => null,
    ];

    /**
     * The supported block features.
     */
    public $supports = [
        'align'      => ['wide', 'full'],
        'color'      => ['background' => true, 'text' => true],
        'typography' => ['fontSize' => false],
    ];

    /**
     * The block theme variations.
     * name (not value) required by register_block_style() WP 6.x+.
     * Omit entirely for Minimal mode.
     */
    public $styles = [
        ['label' => 'Light',   'name' => 'light',   'isDefault' => true],
        ['label' => 'Neutral', 'name' => 'neutral'],
        ['label' => 'Dark',    'name' => 'dark'],
    ];

    public function with(): array
    {
        return [
            //
        ];
    }

    public function fields(): array
    {
        $fields = new FieldsBuilder('{slug}');

        $fields
            // ->addText('titulo')
            // ->addTextarea('descricao')
            ;

        return $fields->build();
    }

    /**
     * Intentionally empty — CSS and JS are conditionally enqueued by
     * ThemeServiceProvider::boot() via has_block() on wp_enqueue_scripts
     * priority 20. This method registers enqueue_block_assets inside
     * render(), which fires during the_content — AFTER wp_head() has
     * already executed. Assets enqueued here never reach <head> on the
     * frontend.
     *
     * Source: vendor/log1x/acf-composer/src/Block.php lines 797–803.
     */
    public function assets(array $block): void
    {
        //
    }
}
```

**Rules:**
- Always declare `$spacing` and `$supports` — editor controls users expect
- Omit `$styles` entirely in Minimal mode
- `assets()` remains empty — CSS/JS enqueue lives in ThemeServiceProvider
- All user-facing strings translatable via `__()` / `esc_html__()` (generated by `--localize`)

### S3 — `resources/js/blocks/{slug}.js`

Always generate, even for static blocks:

```js
import BaseCustomElement from '../core/BaseCustomElement.js';

export default class Block{PascalSlug} extends BaseCustomElement {
  static tagName = 'block-{slug}';

  init() {
    // Block behavior. Empty is valid for static blocks.
  }
}

BaseCustomElement.register(Block{PascalSlug});
```

**Rules:**
- Class name: `Block{PascalSlug}` — PascalCase of the slug prefixed with `Block`
  (e.g. `BlockHeroSection`, `BlockFaq`, `BlockParaArquitetos`)
- `static tagName` — always `block-{slug}` matching the CSS selector
- `init()` empty means static block — still registers the element for future upgrades
- `BaseCustomElement.register(Class)` at the bottom — idempotent, safe on re-runs

### S4 — `resources/views/blocks/{slug}.blade.php`

```blade
@unless ($block->preview)
  <section {{ $attributes }}>
@endunless

<block-{slug} class="flex flex-col">
  {{--
    Layer contract:
    - Typography: use <x-ui.heading> and <x-ui.button> — do NOT hardcode font classes
    - Colors: inherit from `color: var(--block-text)` on block-{slug} — do NOT add color classes
    - Background: applied in CSS — do NOT add bg-* class here
    - Structure (flex, gap, px): Tailwind utilities ARE appropriate on block-{slug} or children
  --}}

  <x-ui.heading :level="2">{{ $titulo ?? '' }}</x-ui.heading>
  <p class="text-[var(--block-text-sub)] mt-4">{{ $descricao ?? '' }}</p>

  @if (!empty($cta_label) && !empty($cta_url))
    <x-ui.button variant="primary" :href="$cta_url" class="mt-8">
      {{ $cta_label }}
    </x-ui.button>
  @endif
</block-{slug}>

@unless ($block->preview)
  </section>
@endunless
```

**Rules:**
- `@unless ($block->preview)` wrapping `<section>` — skipped in Gutenberg editor
  (WP provides the wrapper with `is-style-*` classes there); present on frontend
  (carries `$attributes`: spacing, alignment, variation classes, wp-block-acf-{slug})
- `<block-{slug}>` is the root of the block content — CSS and JS key off this tag
- Structural utilities (flex, grid, gap, px-*, max-w-*) go on `<block-{slug}>` or its children
- Hardcoded colors, typography classes, background utilities — all forbidden at this layer
- Text color NOT in view — inherited via `color: var(--block-text)` on the element

### S5 — `resources/css/editor.css`

Add one `@import` per scaffolded block:

```css
@import 'tailwindcss';
@import './design-tokens.css';

@source "../views/blocks/**/*.blade.php";

/* Block styles — one entry per scaffolded block */
@import './blocks/{slug}.css';
```

---

## Phase 3 — Enqueue guard

Check if `ThemeServiceProvider::boot()` already has the `has_block()` pattern.

**Search for:** `has_block` in `app/Providers/ThemeServiceProvider.php`.

### If the pattern EXISTS — add the new slug:

Add `'{slug}' => true,` to the `$blocks` array.

### If the pattern does NOT EXIST — implement it:

```php
public function boot(): void
{
    parent::boot();

    /*
     * Selective block asset enqueue.
     *
     * Why NOT assets(): ACF Composer's assets() method registers
     * enqueue_block_assets inside render(), which fires during
     * the_content — AFTER wp_head() has already executed. Assets
     * enqueued there never reach <head> on the frontend.
     * Source: vendor/log1x/acf-composer/src/Block.php lines 797–803.
     */
    add_action('wp_enqueue_scripts', function () {
        $blocks = [
            '{slug}' => true,
            // Add slugs here as blocks are scaffolded
        ];

        foreach (array_keys($blocks) as $slug) {
            if (! has_block("acf/{$slug}")) {
                continue;
            }

            $cssAsset = \Roots\asset("css/blocks/{$slug}.css");
            if ($cssAsset->exists()) {
                wp_enqueue_style(
                    "block-{$slug}",
                    $cssAsset->uri(),
                    [],
                    $cssAsset->version()
                );
            }

            $jsAsset = \Roots\asset("js/blocks/{$slug}.js");
            if ($jsAsset->exists()) {
                wp_enqueue_script(
                    "block-{$slug}",
                    $jsAsset->uri(),
                    [],
                    $jsAsset->version(),
                    true  // in_footer
                );
            }
        }
    }, 20);
}
```

**Rules:**
- `wp_enqueue_script` last arg `true` = footer enqueue
- JS enqueue gated on `exists()` — static blocks without JS stay zero-cost
- `[]` dependencies — compiled block CSS/JS is self-contained
- Editor interactivity (rare) requires a separate `enqueue_block_editor_assets` action

---

## Phase 4 — Block README (`docs/blocks/{slug}.md`)

Create documentation for every scaffolded block:

```markdown
# Block: {Human Name}

> {One-sentence objective — what this block does and where it is used.}

## Custom element

`<block-{slug}>` — registered by `resources/js/blocks/{slug}.js` via class `Block{PascalSlug}`.

## ACF Fields

| Field | Type | Required | Description |
|---|---|---|---|
| titulo | Text | yes | Main heading |
| descricao | Textarea | no | Supporting description |

## Theme variations

| Name | Gutenberg class | Appearance |
|---|---|---|
| Light (default) | `is-style-light` | Light surface background |
| Neutral | `is-style-neutral` | Muted surface background |
| Dark | `is-style-dark` | Inverse surface, inverted text |

_(omit this section for Minimal mode)_

## Available CSS custom properties

| Token | Description |
|---|---|
| `--block-bg` | Block background color |
| `--block-text` | Primary text color (inherited via `color: inherit`) |
| `--block-text-sub` | Secondary / muted text |
| `--block-border` | Internal border color |

## Dependencies

- Controller: `App\Blocks\{ClassName}` (`app/Blocks/{ClassName}.php`)
- View: `resources/views/blocks/{slug}.blade.php`
- CSS: `resources/css/blocks/{slug}.css`
- JS: `resources/js/blocks/{slug}.js`
- Enqueue: `ThemeServiceProvider::boot()` via `has_block("acf/{slug}")`
- Editor CSS: imported in `resources/css/editor.css`
- JS class: `Block{PascalSlug}` extending `BaseCustomElement`
```

---

## Phase 5 — Verification (Definition of Done)

| Level | Source | What to validate | Required |
|---|---|---|---|
| A | MCP design tool | Geometry and styles of the section | Yes |
| B | Playwright MCP | Screenshot at canonical width from `plan.md` | Yes |
| C | Playwright MCP | `document.querySelector('block-{slug}').constructor.name === 'Block{PascalSlug}'` | Yes (custom element upgraded) |
| D | Human | Side-by-side design vs browser | First delivery |

### Normative gate — execute all:

```bash
lando theme-build   # must exit 0; block-{slug}-*.css AND block-{slug}-*.js in output
lando flush         # clear Acorn/Blade/OPcache
```

Then:

1. Navigate to the page with the block (canonical width from `plan.md`)
2. Take a screenshot
3. Verify `<link href="*/block-{slug}-*.css">` and `<script src="*/block-{slug}-*.js">` in DOM
4. Evaluate custom element upgrade: `document.querySelector('block-{slug}').constructor !== HTMLElement`
5. If Full mode: test each variation via DevTools adding `is-style-neutral` / `is-style-dark` to the outer `<section>` and confirm `--block-bg` resolves correctly
6. `git commit -m "feat(blocks): scaffold {slug} — custom element, CSS, variations, enqueue, README"` + `git push`

**Textual summary does NOT substitute tool invocation.** Cite: screenshot path, URL
navigated, build output excerpt, custom element upgrade assertion.

---

## Anti-drift — common errors

| Wrong | Correct |
|---|---|
| `<section class="b-{slug}">` root + `$attributes->merge()` | `@unless preview <section {{ $attributes }}>` + `<block-{slug}>` inner |
| `.b-{slug} { ... }` CSS selector | `block-{slug} { ... }` tag selector |
| `&.is-style-neutral, .is-style-neutral &` dual selector | `.is-style-neutral block-{slug}` single selector |
| Custom element without `display: block` | Explicit `display: block/flex/grid` always |
| Tag without hyphen (e.g. `<hero>`) | `<block-hero>` — `block-` prefix guarantees hyphen |
| `assets()` with `wp_enqueue_style()` | `assets()` empty — enqueue via ThemeServiceProvider |
| `@import "../app.css"` in block CSS | `@reference "../app.css"` — avoids duplication |
| `['value' => 'dark']` in `$styles` | `['name' => 'dark']` — WP 6.x format |
| Skipping `$spacing` / `$supports` | Always declare — editor controls users expect |
| Scaffold without `--localize` | `lando acorn acf:block {Name} --localize` — i18n-ready from day one |
| `h1 { font-size: 72px }` in block CSS | `<x-ui.heading :level="1">` — typography via UI component |
| Skipping JS file for static block | Generate stub with empty `init()` — zero cost, future-ready |
| Declaring done without git commit | `git commit` + `git push` before done — Git state is part of DoD |
