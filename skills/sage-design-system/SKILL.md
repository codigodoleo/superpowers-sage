---
name: superpowers-sage:sage-design-system
description: Establish the visual foundation of a Sage theme before any block, view or structural layout. Creates design-tokens.css, UI atomic components (button, heading, badge, text-link, icon), layout structural components (section, container, grid, stack, split), kitchensink validation page, and structural layouts (site-header, site-footer). Must run before /architecting and /building.
user-invocable: true
argument-hint: "[design tool URL or path, or 'detect' to auto-detect]"
---

# Sage Design System — Visual Foundation

Establish the complete visual foundation of a Sage/Acorn theme: design tokens → UI atoms → layout components → kitchensink → structural layouts. This must run before any block, view, or page implementation.

**Announce at start:** "I'm using the sage-design-system skill to establish the visual foundation."

## When to use

- **Standalone**: user invokes `/sage-design-system` at project start
- **Auto-gate from `/architecting`**: before any architecture discovery, `/architecting` checks if design system is validated (kitchensink route exists + `design-tokens.css` present). If not, it invokes this skill first and waits.
- **Resuming**: if some phases are already complete, detect which files exist and skip completed phases

## Inputs

$ARGUMENTS

If a design tool URL or path is provided, use it. Otherwise invoke `/designing` to detect the active design tool (Figma / Paper / Pencil / Stitch).

---

## Phase 0 — Classify the design file

Before writing a single token, complete this checklist. Do NOT skip.

- [ ] **Design tool active?** Run `/designing` to detect: Figma URL → Paper URL → `.pen` file (Pencil) → Stitch URL → offline assets
- [ ] **File fidelity?** Classify as: `wireframe-gray` / `partial-ui-kit` / `high-fidelity`
- [ ] **Brand variables present?** If the file has real color variables/styles → extract real tokens. **FORBIDDEN**: writing `/* placeholder */` on any token without explicit user decision recorded in `plan.md` as `design-status: placeholder-por-decisao`.
- [ ] **Primary reference frame?** Identify node-id (Figma), screen-id (Paper/Stitch), or frame name (Pencil). Record in `plan.md` frontmatter as `design-reference-node: <id>`.
- [ ] **Canonical QA width?** Ask user or read from design file frame dimensions (e.g. 1366px vs 1440px). Record in `plan.md` frontmatter as `design-canonical-width: <px>`. This propagates to every `browser_resize` call for this project.

**Record in `plan.md` frontmatter:**

```yaml
design-tool: figma | paper | pencil | stitch | offline
design-reference-node: "123:456"
design-canonical-width: 1366
design-status: high-fidelity | partial-ui-kit | wireframe-gray | placeholder-por-decisao
```

---

## Phase 1 — Design tokens (`resources/css/design-tokens.css`)

Create `resources/css/design-tokens.css` with a `@theme {}` block. Each token must carry a traceability comment.

```css
/**
 * Design tokens — extracted from [DESIGN_TOOL] on [DATE].
 * Every token references its origin node for traceability.
 * Import: @import './design-tokens.css' in app.css and editor.css.
 */

@theme {
  /* ── Surfaces ─────────────────────────────────────────── */
  --color-surface:        oklch(100% 0 0deg);         /* MCP node 123:100 — surface/default */
  --color-surface-muted:  oklch(96.5% 0.003 280deg);  /* MCP node 123:101 — surface/muted */
  --color-surface-inverse: oklch(22% 0.01 50deg);     /* MCP node 123:102 — surface/inverse */

  /* ── Brand ────────────────────────────────────────────── */
  --color-brand-primary:   oklch(86% 0.16 95deg);     /* MCP node 123:110 — brand/primary */
  --color-brand-secondary: oklch(78% 0.14 95deg);     /* MCP node 123:111 — brand/secondary */

  /* ── Foreground ───────────────────────────────────────── */
  --color-foreground:           oklch(22% 0.01 280deg); /* MCP node 123:120 — text/default */
  --color-foreground-muted:     oklch(38% 0.02 280deg); /* MCP node 123:121 — text/muted */
  --color-foreground-on-inverse: oklch(98% 0.01 280deg);/* MCP node 123:122 — text/on-inverse */
  --color-foreground-on-primary: oklch(22% 0.01 280deg);/* MCP node 123:123 — text/on-primary */

  /* ── Borders & Focus ──────────────────────────────────── */
  --color-border:       oklch(88% 0.02 280deg); /* MCP node 123:130 — border/default */
  --color-border-strong: oklch(72% 0.04 280deg);/* MCP node 123:131 — border/strong */
  --color-ring:          oklch(48% 0.14 250deg);/* MCP node 123:132 — focus/ring */

  /* ── Typography ───────────────────────────────────────── */
  --font-sans:    'Inter', ui-sans-serif, system-ui, sans-serif;
  --font-display: 'Montserrat', ui-sans-serif, system-ui, sans-serif;

  --text-display: clamp(2.25rem, 5vw, 4rem);   /* MCP node 123:140 — type/display */
  --text-h2:      clamp(1.75rem, 2.5vw, 2.25rem);
  --text-h3:      1.25rem;
  --text-body:    1rem;
  --text-lead:    1.125rem;
  --text-sm:      0.875rem;

  --leading-display: 1.125;
  --leading-tight:   1.2;
  --leading-snug:    1.35;
  --leading-body:    1.55;

  /* ── Spacing & Layout ─────────────────────────────────── */
  --spacing-section:    clamp(3rem, 8vw, 6rem);
  --max-width-content:  90rem;

  /* ── Radii ────────────────────────────────────────────── */
  --radius-button: 624.9375rem; /* pill */
  --radius-card:   1rem;

  /* ── Elevation ────────────────────────────────────────── */
  --shadow-card: 0 1px 3px 0 oklch(0% 0 0deg / 8%);
}
```

**Rules:**
- Every token must have `/* MCP node <id> — <description> */` OR `/* design decision: <reason> */`
- No hex values inline in views — only token references
- Imported by `app.css` and `editor.css` via `@import './design-tokens.css'`
- Update `app.css` to `@import './design-tokens.css'` before `@import 'tailwindcss'`
- Update `editor.css` to `@import './design-tokens.css'` at the top

---

## Phase 2 — UI components (atoms)

Location: `resources/views/components/ui/`

| Component | Min props | Required variants |
|---|---|---|
| `button.blade.php` | `variant`, `size`, `href` | primary, secondary, ghost, inverse |
| `heading.blade.php` | `level` (1–4) | dynamic tag `h1`–`h4` + semantic classes per level |
| `badge.blade.php` | `variant` | neutral, brand |
| `text-link.blade.php` | `href`, `variant` | default, muted |
| `icon.blade.php` | `name`, `size` | — |

**Rules:**
- `@props([...])` with explicit defaults
- `$attributes->merge(['class' => ...])` on root element
- No hardcoded values — only tokens via utility classes or `var(--token)`
- No `@apply` for layout — only for appearance helpers specific to the component

**Reference implementation — `button.blade.php`:**

```blade
@props([
    'variant' => 'primary',
    'size'    => 'md',
    'type'    => 'button',
    'href'    => null,
])

@php
  $base = 'inline-flex items-center justify-center gap-2 font-sans font-semibold no-underline transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50';

  $variantClass = match ($variant) {
      'secondary' => 'border border-border-strong bg-surface text-foreground hover:bg-surface-muted',
      'ghost'     => 'bg-transparent text-foreground hover:bg-surface-muted',
      'inverse'   => 'bg-surface-inverse text-foreground-on-inverse hover:opacity-95',
      default     => 'bg-brand-primary text-foreground-on-primary hover:bg-brand-secondary',
  };

  $sizeClass = match ($size) {
      'sm' => 'min-h-9 px-3 text-sm',
      'lg' => 'min-h-12 px-6 text-lead',
      default => 'min-h-10 px-4 text-body',
  };

  $classes = trim("{$base} {$variantClass} {$sizeClass}");
@endphp

@if ($href)
  <a href="{{ $href }}" {{ $attributes->merge(['class' => $classes]) }}>
    {{ $slot }}
  </a>
@else
  <button type="{{ $type }}" {{ $attributes->merge(['class' => $classes]) }}>
    {{ $slot }}
  </button>
@endif
```

**Reference implementation — `heading.blade.php`:**

```blade
@props([
    'level' => 2,
    'align' => 'left',
])

@php
  $tag = match ((int) $level) {
      1 => 'h1',
      2 => 'h2',
      3 => 'h3',
      4 => 'h4',
      default => 'h2',
  };

  $textClass = match ((int) $level) {
      1 => 'font-display text-display leading-display text-foreground',
      2 => 'font-display text-h2 leading-tight text-foreground',
      3 => 'font-sans text-h3 leading-snug text-foreground',
      4 => 'font-sans text-body leading-body text-foreground font-semibold',
      default => 'font-display text-h2 leading-tight text-foreground',
  };

  $alignClass = $align === 'center' ? 'text-center' : 'text-left';
@endphp

<{{ $tag }} {{ $attributes->merge(['class' => "{$textClass} {$alignClass}"]) }}>
  {{ $slot }}
</{{ $tag }}>
```

---

## Phase 3 — Layout components (structure only)

Location: `resources/views/components/layout/`

| Component | Min props | Responsibility |
|---|---|---|
| `section.blade.php` | `background`, `padding` | Section wrapper with surface + py-section |
| `container.blade.php` | `size` (default, wide, narrow) | max-w + centered px |
| `grid.blade.php` | `cols`, `gap` | Responsive grid |
| `stack.blade.php` | `gap`, `align` | flex-col with gap |
| `split.blade.php` | `reverse` | flex-row 2-column responsive |

**Rule:** these components have **zero appearance** — no colors, no typography. Structure only (flex, grid, padding, max-w, gap).

**Reference implementation — `section.blade.php`:**

```blade
@props([
    'background' => 'default',
    'padding'    => true,
])

@php
  $surface = match ($background) {
      'muted'   => 'bg-surface-muted text-foreground',
      'inverse' => 'bg-surface-inverse text-foreground-on-inverse',
      default   => 'bg-surface text-foreground',
  };

  $py = $padding ? 'py-[var(--spacing-section)]' : '';
@endphp

<section {{ $attributes->merge(['class' => trim("{$surface} {$py}")]) }}>
  {{ $slot }}
</section>
```

**Reference implementation — `container.blade.php`:**

```blade
@props([
    'size' => 'default',
])

@php
  $maxW = match ($size) {
      'wide'   => 'max-w-[var(--max-width-content)] mx-auto px-6 lg:px-12',
      'narrow' => 'max-w-2xl mx-auto px-6',
      default  => 'max-w-[var(--max-width-content)] mx-auto px-6 lg:px-8',
  };
@endphp

<div {{ $attributes->merge(['class' => $maxW]) }}>
  {{ $slot }}
</div>
```

---

## Phase 4 — Kitchensink

Create `resources/views/kitchensink.blade.php` + a dev-only route at `/kitchensink`.

**Required content:** every UI component in every variant + every layout component with placeholder content. Must be visually readable without any CSS external to the theme.

**Dev route** (add in `routes/web.php` or a service provider, guarded by `WP_DEBUG`):

```php
// Dev only — remove before production or guard with environment check
if (defined('WP_DEBUG') && WP_DEBUG) {
    Route::get('/kitchensink', function () {
        return view('kitchensink');
    });
}
```

### Playwright gate (required before validation)

Before running the screenshot validation, ToolSearch for `mcp__plugin_playwright_playwright__browser_take_screenshot`.

If NOT found:
```
⛔ Playwright MCP not configured — automatic screenshot unavailable.
   Install: claude mcp add playwright -- npx -y @anthropic/playwright-mcp
   Restart session after installing.
   Alternative: manual validation by user. Record in plan.md:
     playwright-gate: deferred
```

If found, proceed:

1. `lando theme-build` — must complete without errors
2. `mcp__plugin_playwright_playwright__browser_navigate` to `https://{project}.lndo.site/kitchensink`
3. `mcp__plugin_playwright_playwright__browser_take_screenshot` — confirm components render correctly; save to `docs/plans/<active-plan>/assets/kitchensink-ref.png`
4. Report: which components are visible and correctly styled

**The agent MUST have executed items 1–4 before declaring the design system validated. Textual summary does NOT substitute tool invocation. Cite the screenshot path and build output.**

---

## Phase 5 — Structural layouts

These are **composite** components — they use UI + layout components. Zero own CSS; all appearance via tokens + Tailwind classes.

```
resources/views/components/{theme}/site-header.blade.php
resources/views/components/{theme}/site-footer.blade.php
```

Where `{theme}` is the theme slug prefix (e.g. `adrimar`, `interioresdecora`).

Commit separately after manual validation.

---

## Completion

After all phases:

1. Confirm `resources/css/design-tokens.css` exists with traceability comments
2. Confirm `resources/views/components/ui/` has all 5 atoms
3. Confirm `resources/views/components/layout/` has all 5 structure components
4. Confirm kitchensink screenshot was taken and saved
5. Commit:

```bash
git add resources/css/design-tokens.css \
        resources/views/components/ui/ \
        resources/views/components/layout/ \
        resources/views/kitchensink.blade.php \
        routes/web.php \
        docs/plans/<active-plan>/assets/kitchensink-ref.png
git commit -m "feat(theme): design system foundation — tokens, ui, layout components, kitchensink"
git push
```

**Do NOT proceed to `/architecting` or `/building` until this commit exists.**
