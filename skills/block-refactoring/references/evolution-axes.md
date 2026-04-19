Deep reference for block refactoring evolution axes. Loaded on demand from `skills/block-refactoring/SKILL.md`.

# Evolution Axes

The four dimensions along which ACF Composer blocks evolve — rendering model, field composition, variant system, and InnerBlocks adoption — and when each upgrade is worth the cost.

## The 4 Evolution Axes

```
┌──────────────────────────────────────────────────────────────┐
│  AXIS 1 · Design drift detection                             │
│  Compare implementation vs LATEST design reference.          │
│  Detect: geometry, spacing, typography, color divergence.    │
├──────────────────────────────────────────────────────────────┤
│  AXIS 2 · CSS coverage analysis                              │
│  Identify declared custom properties, selectors, variations  │
│  that no element in the view actually uses.                  │
├──────────────────────────────────────────────────────────────┤
│  AXIS 3 · Variation expansion                                │
│  Find new design tokens introduced after the block was       │
│  built. Propose additional variations that exploit them.     │
├──────────────────────────────────────────────────────────────┤
│  AXIS 4 · Gap / migration detection                          │
│  Find implementation divergences from the canonical pattern: │
│  v1 legacy (.b-{slug}), missing wrapper, missing $spacing,   │
│  arbitrary values, mixed-language terms, hardcoded tokens.   │
└──────────────────────────────────────────────────────────────┘
```

Refactoring NEVER rebuilds from scratch. For a full re-scaffold, delegate to `/block-scaffolding` as a fallback.

## Axis 1 — Design drift detection

**Prerequisites:** a design reference must be available. Check in order:
1. MCP design tool with the project's file open (Pencil / Paper / Figma / Stitch)
2. `docs/plans/*/assets/section-{slug}-ref.png` on disk
3. `docs/plans/*/assets/section-{slug}-spec.md` on disk

If none available, report `drift: NOT_VERIFIED` and skip to Axis 2.

**Execution:**
1. Dispatch `visual-verifier` agent with:
   - `url`: current environment's URL for a page rendering the block
   - `selector`: `block-{slug}` (v2) or `.b-{slug}` (v1)
   - `ref`: the reference path found above
   - `spec`: spec file path if available
2. Collect: MATCH | DRIFT | MISSING | FAIL_ARBITRARY_VALUES
3. If DRIFT: capture the exact divergences (typography size, color hex, spacing px) for Phase 6 report

## Axis 2 — CSS coverage analysis

**Read** `resources/css/blocks/{slug}.css` and inventory:
- Every `--block-*` custom property declared (in root or variation blocks)
- Every CSS rule (selectors inside `block-{slug}` or `.b-{slug}`)

**Read** the view and inventory:
- Every class referenced on DOM elements
- Every `var(--block-*)` reference in arbitrary values or style attributes
- Every `<x-ui.*>` component rendered (they have their own CSS, not the block's)

**Report unused items:**

| Item | Status |
|---|---|
| `--block-btn-hover` declared but `var(--block-btn-hover)` never referenced | UNUSED — propose removal |
| `.b-{slug}__icon-wrapper` selector but no `.b-{slug}__icon-wrapper` in view | UNUSED — propose removal |
| `--block-divider` declared but view has `<hr class="border-[var(--block-divider)]">` | USED — keep |

**Propose removals** in the Phase 6 report for user approval. Do NOT auto-delete.

## Axis 3 — Variation expansion

**Read** `resources/css/app.css` `@theme` block and `docs/plans/*/assets/design-tokens.md` to get the current token catalog.

**Read** the block's `$styles` array in the controller and current CSS variation selectors.

**Compare:**
- Are there token families (e.g. `--color-warm-*`, `--color-brand-*`) that DIDN'T EXIST when the block was built but now do?
- Are there semantic roles (e.g. `--color-surface-accent`) that would make sense as a new variation (e.g. `is-style-accent`)?

**Propose new variations** with concrete CSS:

```css
/* Proposed new variation: Accent (leverages --color-surface-accent introduced 2026-04-14) */
.is-style-accent block-{slug} {
  --block-bg:   var(--color-surface-accent);
  --block-text: var(--color-foreground-on-accent);
}
```

AND the matching `$styles` entry:

```php
['label' => 'Accent', 'name' => 'accent'],
```

User approves or rejects per proposal.

## Axis 4 — Gap / migration detection

Run these checks — every failure becomes a line item in Phase 6:

### G1. v1 → v2 migration (if Phase 1 classified as v1 or mixed)

Propose the upgrade:
1. Replace `<section {{ $attributes->merge(['class' => 'b-{slug}']) }}>` with:
   ```blade
   @unless ($block->preview)
     <section {{ $attributes }}>
   @endunless

   <block-{slug} class="...">
     ...
   </block-{slug}>

   @unless ($block->preview)
     </section>
   @endunless
   ```
2. Rewrite CSS: `.b-{slug}` → `block-{slug}` (tag selector), add `display: block`
3. Simplify dual selectors to single: `.is-style-neutral block-{slug}`
4. Create `resources/js/blocks/{slug}.js` with empty `init()`
5. Ensure `resources/js/core/BaseCustomElement.js` exists — copy from plugin template if missing
6. Update `ThemeServiceProvider::boot()` enqueue to include the JS path

### G2. Missing `$spacing` / `$supports` in controller

```php
public $spacing = ['padding' => null, 'margin' => null];
public $supports = [
    'align'      => ['wide', 'full'],
    'color'      => ['background' => true, 'text' => true],
    'typography' => ['fontSize' => false],
];
```

### G3. Arbitrary Tailwind values in view

Grep for `\[#`, `\[rgba`, `\[px`, `\[em`, `\[[0-9]+px` in the view. Each is CRITICAL — replace with token reference or design-system class.

### G4. Hardcoded tokens without custom property

Look for `bg-bg-primary`, `text-text-primary`, `font-display`, etc. directly applied in the view. These should move to the block CSS as custom properties.

### G5. `$styles` using legacy format

`['light' => true, 'dark']` or `['value' => 'light']` → migrate to `[['label' => 'Light', 'name' => 'light', 'isDefault' => true]]`.

### G6. `assets()` method with enqueue logic

`wp_enqueue_style()` inside `assets()` → move to `ThemeServiceProvider::boot()`.

### G7. Missing localization — CRITICAL

Grep the view for any user-facing string literals not wrapped in a localization function:

```bash
grep -n '"[A-Z][a-z]\|"[A-Z][A-Z]' resources/views/blocks/{slug}.blade.php
```

Also check for Portuguese/Spanish strings (mixed-language G8 overlap):
```bash
grep -n '"[A-Z][a-zãáâàéêíóôõúçñ]' resources/views/blocks/{slug}.blade.php
```

Every unlocalized string is **CRITICAL** — same severity as arbitrary Tailwind values.

**Fix:** Replace bare strings with localization calls:
```blade
{{-- Before --}}
<span>Saiba mais</span>

{{-- After --}}
<span>{{ esc_html__('Saiba mais', 'sage') }}</span>
```

If the project uses a non-`sage` text domain, check `functions.php` or `ThemeServiceProvider::boot()` for the registered domain. See `references/localization.md` for the full localization cycle.

### G8. Mixed-language identifiers

Grep view, controller, CSS for non-English tokens in class names, variable names, comments. Each instance is CRITICAL (violates the language policy in `sageing`).
