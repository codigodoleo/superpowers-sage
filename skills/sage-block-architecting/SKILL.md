---
name: superpowers-sage:sage-block-architecting
description: Architect the visual layer of an ACF block — scoped CSS contract with custom properties, theme variations via native $styles, selective enqueue via ThemeServiceProvider, and block README. Invoked after every ACF block scaffold by /building, or standalone for refactoring existing blocks.
user-invocable: true
argument-hint: "[block class name or slug, e.g. HeroSection or hero-section]"
---

# Sage Block Architecting — CSS Contract per Block

Define the visual architecture of an ACF Composer block: scoped CSS, theme variations, correct enqueue, and documentation.

**Announce at start:** "I'm using the sage-block-architecting skill to architect the visual layer."

## When to use

- **Auto-invoked by `/building`**: after every ACF controller PHP + Blade view scaffold, before moving to the next component
- **Standalone manual refactor**: user calls `/sage-block-architecting HeroSection` to retrofit an existing block
- **New block**: called right after `lando acorn make:block` produces the PHP stub

## Inputs

$ARGUMENTS

Detect the target block from arguments, active plan context, or ask the user which block to architect.

---

## Hard prerequisite

Before doing anything, verify the design system foundation exists:

```
resources/css/design-tokens.css   — must exist
resources/views/components/ui/    — must contain at least button + heading
```

If missing:
```
⛔ Design system not validated.
   Run /sage-design-system first, then return here.
```

Do NOT proceed until the design system is in place.

---

## Operation modes

| Mode | When to use | `$styles` | CSS |
|---|---|---|---|
| **Full** | Blocks that need light/neutral/dark theme switching | 3 entries | 3 `&.is-style-*` variation blocks |
| **Minimal** | Blocks with a single fixed appearance (footer, nav, ticker, decorative) | absent | `.b-{slug}` scope + base custom props only |

Both modes maintain **complete CSS isolation** — the `.b-{slug}` scope, `@reference`, and custom properties are always present. The only difference is presence/absence of variation blocks and `$styles`.

**Deciding the mode:** ask the user, or infer from the block's nature — if it's a structural/framing element with no design variation, use Minimal.

---

## The 4-layer contract

```
┌──────────────────────────────────────────────────────────────────┐
│  LAYER 1 · design-tokens.css + UI/layout Blade components        │
│  Typography via <x-ui.heading :level="N">, buttons via           │
│  <x-ui.button variant="primary">. Foundation from /sage-design-  │
│  system — provides correct specificity against WP admin styles.  │
├──────────────────────────────────────────────────────────────────┤
│  LAYER 2 · resources/css/blocks/{slug}.css                       │
│  Visual appearance only: --block-bg, --block-text, etc.          │
│  Theme variations via &.is-style-* + .is-style-* & (dual         │
│  selector required — WP applies is-style-* on wrapper parent     │
│  in editor, on root element in frontend).                        │
│  @apply only for bg and overflow — zero layout here.             │
├──────────────────────────────────────────────────────────────────┤
│  LAYER 3 · Blade view + Tailwind utilities                       │
│  Structural CSS only: flex, grid, gap, px-*, max-w-*, overflow.  │
│  Zero hardcoded colors. Zero typography classes.                 │
│  Colors from layer 2 custom props. Typography from layer 1.      │
├──────────────────────────────────────────────────────────────────┤
│  LAYER 4 · ThemeServiceProvider::boot()                          │
│  Selective enqueue: has_block("acf/{slug}") priority 20.         │
│  NEVER enqueue in assets() — timing issue: assets() fires        │
│  during the_content, after wp_head() has already executed.       │
│  Source: vendor/log1x/acf-composer/src/Block.php lines 797–803. │
└──────────────────────────────────────────────────────────────────┘
```

**Golden rule:** a block is architecturally correct when you can switch between all 3 theme variations without changing a single line of the Blade view.

---

## Phase 1 — Audit or skip

**New block:** skip directly to Phase 2.

**Existing block:** classify every CSS rule and Tailwind class currently in the block:

- **Structural** (flex, grid, gap, padding, max-w) → stays in Blade view
- **Visual** (background colors, text colors, borders, shadows) → moves to `blocks/{slug}.css` as custom props
- **Typographic** (font-size, font-weight, font-family) → should use `<x-ui.heading>` component; remove from block CSS entirely
- **Hardcoded tokens** (`bg-[#F4EFE8]`, `text-[#1E1C1A]`) → replace with `var(--block-*)` references

List the changes needed before implementing.

---

## Phase 2 — Decide mode

Ask (or infer): does this block need theme variations (light/neutral/dark)?

- Yes → **Full mode**
- No → **Minimal mode**

---

## Phase 3 — Implement A1–A4

### A1 — `resources/css/blocks/{slug}.css`

**Full mode:**

```css
@reference "../app.css";

.b-{slug} {
  /* ── Light (default) ──────────────────────────────── */
  --block-bg:        var(--color-surface);
  --block-text:      var(--color-foreground);
  --block-text-sub:  var(--color-foreground-muted);
  --block-border:    var(--color-border);
  --block-btn-bg:    var(--color-foreground);
  --block-btn-text:  var(--color-foreground-on-inverse);
  --block-btn-hover: var(--color-surface-inverse);

  /* ── Neutral ───────────────────────────────────────── */
  /* Dual selector: &.is-style-* for frontend (class on root),
     .is-style-* & for Gutenberg editor (WP places class on wrapper parent) */
  &.is-style-neutral,
  .is-style-neutral & {
    --block-bg:     var(--color-surface-muted);
    --block-border: var(--color-border-strong);
  }

  /* ── Dark ──────────────────────────────────────────── */
  &.is-style-dark,
  .is-style-dark & {
    --block-bg:        var(--color-surface-inverse);
    --block-text:      var(--color-foreground-on-inverse);
    --block-text-sub:  color-mix(in srgb, var(--color-foreground-on-inverse) 60%, transparent);
    --block-border:    color-mix(in srgb, var(--color-foreground-on-inverse) 20%, transparent);
    --block-btn-bg:    var(--color-foreground-on-inverse);
    --block-btn-text:  var(--color-foreground);
    --block-btn-hover: color-mix(in srgb, var(--color-foreground-on-inverse) 90%, transparent);
  }

  /* color on container feeds color:inherit to children in editor */
  color: var(--block-text);

  @apply bg-[var(--block-bg)] overflow-hidden;
}
```

**Minimal mode** (omit variation blocks):

```css
@reference "../app.css";

.b-{slug} {
  --block-bg:       var(--color-surface);
  --block-text:     var(--color-foreground);
  --block-text-sub: var(--color-foreground-muted);
  --block-border:   var(--color-border);

  color: var(--block-text);

  @apply bg-[var(--block-bg)] overflow-hidden;
}
```

**Implementation notes:**
- `@reference` (NOT `@import`) — grants access to Tailwind tokens at build time without duplicating the full CSS
- Dual selector `&.is-style-* + .is-style-* &` **always required in Full mode** — WP places `is-style-*` on the wrapper parent in the Gutenberg editor, on the root element in the frontend; both contexts must be covered
- Declare only the custom properties the block actually needs — not all must be present
- Vite auto-discovers block CSS via glob in `vite.config.js` — no manual import needed in `app.css`

### A2 — `app/Blocks/{ClassName}.php`

**Full mode — add `$styles`:**

```php
/**
 * Block theme variations.
 * name (not value) is required by register_block_style() / WP 6.x+.
 */
public $styles = [
    ['label' => 'Light',   'name' => 'light',   'isDefault' => true],
    ['label' => 'Neutral', 'name' => 'neutral'],
    ['label' => 'Dark',    'name' => 'dark'],
];

/**
 * Intentionally empty. Block CSS is conditionally enqueued by
 * ThemeServiceProvider::boot() via has_block() on wp_enqueue_scripts
 * priority 20. This method fires enqueue_block_assets inside render(),
 * which is called during the_content — after wp_head() has already
 * executed. CSS enqueued here never reaches <head> on the frontend.
 * Source: vendor/log1x/acf-composer/src/Block.php lines 797–803.
 */
public function assets(array $block): void
{
    //
}
```

**Minimal mode:** omit `$styles` entirely. Keep `assets()` empty with the same comment.

### A3 — `resources/views/blocks/{slug}.blade.php`

```blade
<section {{ $attributes->merge(['class' => 'b-{slug} flex flex-col']) }}>
  {{--
    Layer contract:
    - Typography: use <x-ui.heading> and <x-ui.button> — do NOT hardcode font classes
    - Colors: inherit from `color: var(--block-text)` defined in CSS — do NOT add color classes
    - Background: applied via @apply in CSS — do NOT add bg-* class here
    - Structure (flex, gap, px): Tailwind utilities ARE appropriate here
  --}}

  <x-ui.heading :level="2">{{ $titulo ?? '' }}</x-ui.heading>
  <p class="text-[var(--block-text-sub)] mt-4">{{ $descricao ?? '' }}</p>

  @if (!empty($cta_label) && !empty($cta_url))
    <x-ui.button variant="primary" :href="$cta_url" class="mt-8">
      {{ $cta_label }}
    </x-ui.button>
  @endif
</section>
```

**Implementation notes:**
- `$attributes->merge()` injects WP's `is-style-*`, `alignfull`, `alignwide`, editor classes into the root element — required for variations to work
- `bg-[var(--block-bg)]` does NOT go in the view — it's already in the CSS via `@apply`
- Text color does NOT go in the view — inherited from `color: var(--block-text)` on the root
- Use `<x-ui.heading>`, `<x-ui.button>` whenever element matches a UI component

### A4 — `resources/css/editor.css`

Add one `@import` entry per architected block:

```css
@import 'tailwindcss';
@import './design-tokens.css';

@source "../views/blocks/**/*.blade.php";

/* Block styles — one entry per architected block */
@import './blocks/{slug}.css';
```

---

## Phase 4 — Enqueue guard

Check if `ThemeServiceProvider::boot()` already has a `has_block()` pattern.

**Search for:** `has_block` in `app/Providers/ThemeServiceProvider.php`.

### If the pattern EXISTS — add the new block entry:

```php
// Inside the existing $blocks array:
'{slug}' => \Roots\asset('css/blocks/{slug}.css'),
```

### If the pattern does NOT EXIST — implement the full pattern first:

```php
public function boot(): void
{
    parent::boot();

    // Selective block CSS enqueue.
    // Why not assets(): assets() registters enqueue_block_assets inside render(),
    // called during the_content — after wp_head() has already executed.
    // CSS enqueued there never reaches <head> on the frontend.
    add_action('wp_enqueue_scripts', function () {
        $blocks = [
            '{slug}' => \Roots\asset('css/blocks/{slug}.css'),
            // Add new blocks here as they are architected
        ];

        foreach ($blocks as $slug => $asset) {
            if (has_block("acf/{$slug}")) {
                wp_enqueue_style(
                    "block-{$slug}",
                    $asset->uri(),
                    [],
                    $asset->version()
                );
            }
        }
    }, 20);
}
```

**Note:** `wp_enqueue_style` dependencies should be `[]` — compiled block CSS is self-contained.

---

## Phase 5 — Block README (`docs/blocks/{slug}.md`)

Create documentation for every architected block at `docs/blocks/{slug}.md`:

```markdown
# Block: {Human Name}

> {One-sentence objective — what this block does and where it is used.}

## ACF Fields

| Field | Type | Required | Description |
|---|---|---|---|
| titulo | Text | yes | Main heading |
| descricao | Textarea | no | Supporting description |
| cta_label | Text | no | CTA button label |
| cta_url | URL | no | CTA button href |

## Theme variations

| Name | Gutenberg class | Appearance |
|---|---|---|
| Light (default) | `is-style-light` | Light surface background |
| Neutral | `is-style-neutral` | Muted surface background |
| Dark | `is-style-dark` | Inverse surface, inverted text |

_(omit this section for Minimal mode blocks)_

## Available CSS tokens

| Token | Description |
|---|---|
| `--block-bg` | Block background color |
| `--block-text` | Primary text color (inherited by children via `color: inherit`) |
| `--block-text-sub` | Secondary / muted text |
| `--block-border` | Internal border color |
| `--block-btn-bg` | CTA button background |
| `--block-btn-text` | CTA button text |

## How to use in the editor

1. Add block: search for "{Human Name}" in the block inserter
2. Fill fields in the right panel
3. Switch variation: Styles panel → Light | Neutral | Dark

## Dependencies

- Controller: `App\Blocks\{ClassName}` (`app/Blocks/{ClassName}.php`)
- View: `resources/views/blocks/{slug}.blade.php`
- CSS: `resources/css/blocks/{slug}.css`
- Enqueue: `ThemeServiceProvider::boot()` via `has_block("acf/{slug}")`
- Editor: imported in `resources/css/editor.css`
```

---

## Phase 6 — Verification (Definition of Done)

| Level | Source | What to validate | Required |
|---|---|---|---|
| **A** | MCP design tool — geometry | `get_metadata` (Figma) / `get_node_info` (Paper) / `batch_get(readDepth:4)` (Pencil) — x/y/width of child frames | Yes for multi-column / offset layouts |
| **B** | MCP design tool — styles | `get_design_context` (Figma) / `get_computed_styles` (Paper) / `batch_get(resolveVariables:true)` (Pencil) / `get_screen` (Stitch) — typography, shadows, radii, colors | Always |
| **C** | Playwright MCP | `mcp__plugin_playwright_playwright__browser_take_screenshot` at canonical width from `plan.md` | Yes |
| **E** | Human | Side-by-side design vs browser | Required on first delivery |

**Accepted reference method:** "live reference" via MCP design tool (Figma / Paper / Pencil / Stitch) + Playwright screenshot. `*-ref.png` on disk is optional when a live MCP reference is available.

### Normative gate — execute ALL of these before declaring done:

```bash
lando theme-build   # must exit 0; {slug}-*.css must appear in output
lando flush         # clear Acorn/Blade/OPcache
```

Then:

1. `mcp__plugin_playwright_playwright__browser_navigate` to the page containing the block (canonical width from `plan.md`)
2. `mcp__plugin_playwright_playwright__browser_take_screenshot` — save screenshot
3. Verify `<link href="*/{slug}-*.css">` is present in `<head>` (selective enqueue working)
4. If Full mode: test each variation by adding `is-style-neutral` / `is-style-dark` via DevTools and confirming `--block-bg` resolves correctly
5. `git commit -m "feat(blocks): {slug} — CSS contract, variations, enqueue, README"` + `git push`

**Textual summary does NOT substitute tool invocation. Cite: screenshot path, URL navigated, build output excerpt. If these are not cited, the work is not complete.**

---

## Anti-drift — common errors

| Wrong | Correct |
|---|---|
| `assets()` with `wp_enqueue_style()` | `assets()` empty — timing issue post `wp_head()` |
| `&.is-style-dark` alone | `&.is-style-dark, .is-style-dark &` — dual selector required |
| `@import "../app.css"` in block CSS | `@reference "../app.css"` — avoids duplicating the full stylesheet |
| `bg-[#F4EFE8]` hardcoded in view | `var(--block-bg)` defined in block CSS |
| `['value' => 'dark']` in `$styles` | `['name' => 'dark']` — WP 6.x format |
| `wp_enqueue_style(..., ['theme'], ...)` | `wp_enqueue_style(..., [], ...)` — block CSS is self-contained |
| `h1 { font-size: 72px }` in block CSS | Use `<x-ui.heading :level="1">` — typography via UI component |
| Hardcoded `font-display text-[72px]` in view | `<x-ui.heading :level="1">` — correct specificity via component |
| README file in `resources/views/blocks/` | README file in `docs/blocks/{slug}.md` |
| `*-ref.png` mandatory for verification | Live MCP design tool reference is accepted |
| Minimal block without CSS scope | `.b-{slug}` scope + custom props always required |
| Declaring done without commit | `git commit` + `git push` before done — Git state is part of DoD |
| Only `&.is-style-*` in editor | Always add `.is-style-* &` — WP applies class on parent wrapper in editor |
