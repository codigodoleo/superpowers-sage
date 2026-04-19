<!-- Loaded on demand from skills/sage-design-system/SKILL.md -->

# Component Phases

Phases 2–5 of design system implementation — from atomic UI components to structural page layouts with Tailwind v4 and Blade.

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
Playwright MCP not configured — automatic screenshot unavailable.
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
