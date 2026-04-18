---
name: superpowers-sage:acf-block-refactor
description: Refactor an existing ACF block to the per-block CSS pattern with theme variations via native WP $styles. Separates CSS responsibility, eliminates unused styles, adds light/neutral/dark variants, and double-checks implementation against the latest design reference.
user-invocable: true
argument-hint: "<BlockClassName or block-slug>"
---

# ACF Block Refactor

Applies the validated per-block CSS pattern to any ACF Composer block: visual logic separated
into a dedicated CSS file, theme variations via native `$styles`, selective CSS enqueue (loaded
only when the block is present on the page), and a final visual double-check against the design reference.

## When to use

- Newly created ACF block that needs light/neutral/dark variations
- Legacy block with hardcoded Tailwind classes that needs to be refactored
- Any block where CSS should be conditionally loaded (not bundled globally)

## Input

$ARGUMENTS

Resolve to block slug and class name before proceeding. If not provided, ask.

---

## Procedure

### 0) Resolve block identity

From the argument, identify:
- `{ClassName}` — e.g. `HeroSection`
- `{slug}` — e.g. `hero-section`
- 4 target files:
  - `app/Blocks/{ClassName}.php`
  - `resources/views/blocks/{slug}.blade.php`
  - `resources/css/blocks/{slug}.css`
  - `resources/css/editor.css`

Read the current state of all 4 files before making any changes.

### 1) Read available design tokens

Read `resources/css/app.css` (or `@theme` block) to extract:
- All `--color-*` tokens
- All semantic typography classes (`display`, `leading`, `eyebrow`, etc.)

Read `docs/plans/*/assets/design-tokens.md` if it exists — use those tokens as authoritative source.

### 2) Create `resources/css/blocks/{slug}.css`

**H01** — Create (or replace) the block CSS file:

```css
@reference "../app.css";

.b-{slug} {
  /* Light variation (default) */
  --block-bg:        var(--color-bg-primary);
  --block-text:      var(--color-text-primary);
  --block-text-sub:  var(--color-text-muted);
  --block-eyebrow:   var(--color-neutral);
  --block-border:    var(--color-border-light);
  --block-btn-bg:    var(--color-text-primary);
  --block-btn-text:  var(--color-text-inverse);
  --block-btn-hover: var(--color-bg-dark);

  /* Neutral — applied as class on the root element (frontend) or parent wrapper (editor) */
  &.is-style-neutral,
  .is-style-neutral & {
    --block-bg:     var(--color-bg-neutral);
    --block-border: var(--color-border-medium);
  }

  /* Dark — same dual-selector pattern */
  &.is-style-dark,
  .is-style-dark & {
    --block-bg:        var(--color-bg-dark);
    --block-text:      var(--color-text-inverse);
    --block-text-sub:  color-mix(in srgb, var(--color-text-inverse) 60%, transparent);
    --block-border:    var(--color-border-dark);
    --block-btn-bg:    var(--color-text-inverse);
    --block-btn-text:  var(--color-text-primary);
    --block-btn-hover: color-mix(in srgb, var(--color-text-inverse) 90%, transparent);
  }

  /* Root text color — children inherit via color:inherit */
  color: var(--block-text);

  @apply bg-[var(--block-bg)] overflow-hidden;
}
```

**Rules:**
- Only declare custom properties this block actually uses
- `@reference` grants Tailwind token access at build-time without duplicating CSS
- Vite auto-discovers via glob in `vite.config.js` — no manual import needed
- Do NOT put typography (font-size, font-weight, line-height) here — it belongs in `app.css` semantic classes

### 3) Update `app/Blocks/{ClassName}.php`

**H02** — Add `$styles` and empty `assets()`:

```php
public $styles = [
    ['label' => 'Light',   'name' => 'light',   'isDefault' => true],
    ['label' => 'Neutral', 'name' => 'neutral'],
    ['label' => 'Dark',    'name' => 'dark'],
];

/**
 * Assets enqueued when rendering the block.
 *
 * Intentionally empty. CSS is conditionally enqueued by ThemeServiceProvider::boot()
 * via has_block() + wp_enqueue_scripts (priority 20), because this method registers
 * enqueue_block_assets inside render() — which fires during the_content, after wp_head()
 * has already executed. See: vendor/log1x/acf-composer/src/Block.php
 */
public function assets(array $block): void
{
    //
}
```

**Rules:**
- `$styles` uses `name` (not `value`) — required by `register_block_style()` / WP 6.9+
- `assets()` must remain EMPTY — timing issue: fires after `wp_head()`
- CSS enqueue must happen in `ThemeServiceProvider::boot()` via `has_block()`

### 4) Update `resources/views/blocks/{slug}.blade.php`

**H03** — Replace hardcoded tokens with custom properties and `$attributes->merge()`:

```blade
<section {{ $attributes->merge(['class' => 'b-{slug} flex']) }}>
  {{-- Typography via semantic classes from design system (app.css) --}}
  {{-- Color inherits from `color: var(--block-text)` in block CSS — do not repeat in view --}}
  <h1 class="display mb-[28px]">...</h1>
  <p class="leading mb-[52px] text-[var(--block-text-sub)]">...</p>

  {{-- Eyebrow --}}
  <span class="eyebrow text-[var(--block-eyebrow)]">...</span>

  {{-- Primary CTA --}}
  <a class="bg-[var(--block-btn-bg)] text-[var(--block-btn-text)] hover:bg-[var(--block-btn-hover)]">...</a>
</section>
```

**Rules:**
- `$attributes->merge()` injects WP classes (`is-style-*`, `alignfull`, etc.) on the root element
- `bg-[var(--block-bg)]` goes in the CSS via `@apply` — NOT in the view
- Heading/body color NOT in view — inherits from `color: var(--block-text)` on root
- Semantic classes (`display`, `leading`, `eyebrow`) come from `app.css`
- Remove ALL hardcoded tokens: `bg-bg-primary`, `text-text-primary`, `font-display`, `text-[72px]`, etc.

### 5) Update `resources/css/editor.css`

**H04** — Add `@import` for the block CSS:

```css
@import './blocks/{slug}.css';
```

One `@import` per refactored block, in alphabetical order.

### 6) Verify selective CSS enqueue in ThemeServiceProvider

Check that `app/Providers/ThemeServiceProvider.php` has a `has_block()` conditional for this block:

```php
add_action('wp_enqueue_scripts', function () {
    if (has_block('acf/{slug}')) {
        wp_enqueue_style(
            'block-{slug}',
            Vite::asset('resources/css/blocks/{slug}.css'),
            [],
            null
        );
    }
}, 20);
```

If missing, add it. The `priority 20` ensures it runs after `wp_head()`.

### 7) Build and cache flush

```bash
lando theme-build   # must exit 0 and list {slug}-*.css in output
lando flush         # clear Acorn/Blade/OPcache
```

### 8) Double-check: implementation vs. design reference

Compare the refactored block against the latest available design reference:

**8a) Locate reference:**
1. Check `docs/plans/*/assets/section-{slug}-ref.png` or `section-{slug}-spec.md`
2. If no plan asset — check `docs/plans/*/assets/` for any overview reference
3. If no reference at all — skip to step 8c and note in report

**8b) Dispatch `visual-verifier`** with:
- `url`: project's Lando URL (from `.lando.yml` proxy config)
- `selector`: `[data-block="acf/{slug}"]`
- `ref`: found reference image path
- `spec`: found spec file path (if any)

Collect: MATCH | DRIFT | MISSING | FAIL_ARBITRARY_VALUES

**8c) Cross-check variation rendering:**
Verify manually (or instruct user to verify) in browser:
1. Light (default) — `--block-bg` resolves to `var(--color-bg-primary)`
2. Apply `is-style-neutral` via DevTools — `--block-bg` resolves to `var(--color-bg-neutral)`
3. Apply `is-style-dark` via DevTools — `--block-bg` resolves to `var(--color-bg-dark)`
4. Confirm `<link href="*/{slug}-*.css">` in `<head>` — selective enqueue working

### 9) Report

```markdown
## ACF Block Refactor: {ClassName}

### Files Changed
- [x] H01 `resources/css/blocks/{slug}.css` — created
- [x] H02 `app/Blocks/{ClassName}.php` — $styles + empty assets()
- [x] H03 `resources/views/blocks/{slug}.blade.php` — $attributes->merge() + var(--block-*)
- [x] H04 `resources/css/editor.css` — @import added
- [x] ThemeServiceProvider — has_block() enqueue verified

### Visual Double-Check
- Reference: {path or "none found"}
- Result: {MATCH | DRIFT | MISSING}
- Drift details: {list or "none"}

### Variation Check
- Light: {✅ / ⚠️}
- Neutral: {✅ / ⚠️}
- Dark: {✅ / ⚠️}
- Selective enqueue: {✅ confirmed / ⚠️ not verified}

### Remaining Issues
{list or "none — ready to commit"}
```

---

## Anti-drift reference

| Wrong | Correct |
|---|---|
| `$styles = ['light' => true, 'neutral', 'dark']` | `[['name' => 'light', 'isDefault' => true], ...]` |
| `['label' => '...', 'value' => 'light']` | `['label' => '...', 'name' => 'light']` |
| `assets()` with `wp_enqueue_style(...)` | `assets()` empty — timing issue fires after `wp_head()` |
| `@import "../app.css"` in block CSS | `@reference "../app.css"` — `@import` duplicates all CSS |
| `bg-bg-primary` hardcoded in view | `bg-[var(--block-bg)]` via CSS `@apply` |
| Arbitrary token `bg-[#F4EFE8]` | Always use tokens: `var(--color-bg-primary)` |
| `&.is-style-dark` only | `&.is-style-dark, .is-style-dark &` — Gutenberg applies `is-style-*` on parent wrapper in editor |
| `h1 { font-size: 72px }` in block CSS | Semantic class `h1.display` in `app.css` — typography belongs to design system |
| `font-display text-[72px] font-light` in view | `class="display"` — unlayered in `app.css`, wins WP admin specificity |
