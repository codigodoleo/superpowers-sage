---
name: superpowers-sage:block-refactoring
description: Evolve an existing ACF block — detect design drift vs latest reference, reduce unused CSS, expand variations leveraging new design tokens, detect implementation gaps, and migrate legacy v1 blocks to the v2 custom element pattern. Uses block-scaffolding as pattern reference.
user-invocable: true
argument-hint: "<BlockClassName or block-slug>"
---

# Block Refactoring — Evolution of Existing Blocks

Analyze and improve an existing block after its first implementation. Four axes of
evolution: design drift detection, CSS coverage analysis, variation expansion, and
gap/migration detection.

**Announce at start:** "I'm using the block-refactoring skill to evolve the block."

## When to use

- Block shipped in a previous PR and design has evolved since
- CSS bundle includes rules/tokens that are no longer used
- New design tokens exist in `app.css`/`design-tokens.md` that the block could leverage
- Legacy block still uses v1 pattern (`.b-{slug}` class, dual selector, no custom element)
- You suspect implementation diverged from design reference during initial build

## When NOT to use

- **Creating a new block from scratch** → use `/block-scaffolding` instead
- **Project-wide convention audit** → use `/reviewing`
- **Non-block UI component** → Blade components are not ACF blocks

## Input

$ARGUMENTS

Resolve to `{ClassName}` and `{slug}`. If not provided, ask.

---

## The 4 evolution axes

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

Refactoring NEVER rebuilds from scratch. For a full re-scaffold, delegate to
`/block-scaffolding` as a fallback.

---

## Procedure

### Phase 0 — Resolve block identity and locate files

From the argument, identify:
- `{ClassName}` — e.g. `HeroSection`
- `{slug}` — e.g. `hero-section`
- 5 target files (one may be absent on legacy blocks):
  - `app/Blocks/{ClassName}.php`
  - `resources/views/blocks/{slug}.blade.php`
  - `resources/css/blocks/{slug}.css`
  - `resources/js/blocks/{slug}.js` (may not exist — legacy)
  - `resources/css/editor.css` (check for `@import './blocks/{slug}.css'`)

Read all present files.

### Phase 1 — Classify current pattern version

Inspect the view file and the CSS file:

| Signal | Version |
|---|---|
| View has `<block-{slug}>` custom element | **v2** |
| View uses `$attributes->merge()` on a `<section class="b-{slug}">` | **v1** |
| CSS scoped to `block-{slug}` tag selector | **v2** |
| CSS scoped to `.b-{slug}` class selector | **v1** |
| CSS has dual selector `&.is-style-*, .is-style-* &` | **v1** |
| CSS has single selector `.is-style-* block-{slug}` | **v2** |
| JS file at `resources/js/blocks/{slug}.js` | **v2** |

Mark the block's current version (`v1` / `v2` / `mixed`) before proceeding.

---

### AXIS 1 — Design drift detection

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
3. If DRIFT: capture the exact divergences (typography size, color hex, spacing px) for
   Phase 6 report

---

### AXIS 2 — CSS coverage analysis

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

---

### AXIS 3 — Variation expansion

**Read** `resources/css/app.css` `@theme` block and `docs/plans/*/assets/design-tokens.md`
to get the current token catalog.

**Read** the block's `$styles` array in the controller and current CSS variation
selectors.

**Compare:**
- Are there token families (e.g. `--color-warm-*`, `--color-brand-*`) that DIDN'T EXIST
  when the block was built but now do?
- Are there semantic roles (e.g. `--color-surface-accent`) that would make sense as a
  new variation (e.g. `is-style-accent`)?

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

---

### AXIS 4 — Gap / migration detection

Run these checks — every failure becomes a line item in Phase 6:

#### G1. v1 → v2 migration (if Phase 1 classified as v1 or mixed)

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

#### G2. Missing `$spacing` / `$supports` in controller

```php
public $spacing = ['padding' => null, 'margin' => null];
public $supports = [
    'align'      => ['wide', 'full'],
    'color'      => ['background' => true, 'text' => true],
    'typography' => ['fontSize' => false],
];
```

#### G3. Arbitrary Tailwind values in view

Grep for `\[#`, `\[rgba`, `\[px`, `\[em`, `\[[0-9]+px` in the view. Each is CRITICAL —
replace with token reference or design-system class.

#### G4. Hardcoded tokens without custom property

Look for `bg-bg-primary`, `text-text-primary`, `font-display`, etc. directly applied in
the view. These should move to the block CSS as custom properties.

#### G5. `$styles` using legacy format

`['light' => true, 'dark']` or `['value' => 'light']` → migrate to
`[['label' => 'Light', 'name' => 'light', 'isDefault' => true]]`.

#### G6. `assets()` method with enqueue logic

`wp_enqueue_style()` inside `assets()` → move to `ThemeServiceProvider::boot()`.

#### G7. Missing `--localize` strings

Look for static user-facing strings in the view not wrapped in `__()` / `esc_html__()`.
If they exist, propose wrapping them.

#### G8. Mixed-language identifiers

Grep view, controller, CSS for non-English tokens in class names, variable names,
comments. Each instance is CRITICAL (violates the language policy in `sageing`).

---

## Phase 6 — Report and propose

Produce a structured report:

```markdown
## Block Refactoring: {ClassName}

### Current pattern version
{v1 | v2 | mixed} — {brief justification}

### Axis 1 — Design drift
- Status: {MATCH | DRIFT | MISSING | NOT_VERIFIED}
- Divergences: {list or "none"}

### Axis 2 — CSS coverage
- Unused custom properties: {list}
- Unused selectors: {list}
- Proposed removals: {list}

### Axis 3 — Variation expansion
- New tokens available: {list}
- Proposed new variations: {names + CSS blocks}

### Axis 4 — Gaps / migration
- G1 v1 → v2 migration: {needed | N/A}
- G2 Missing $spacing/$supports: {yes | no}
- G3 Arbitrary Tailwind values: {count + locations}
- G4 Hardcoded tokens in view: {count + locations}
- G5 Legacy $styles format: {yes | no}
- G6 assets() enqueue logic: {yes | no}
- G7 Missing localization: {count}
- G8 Mixed-language identifiers: {count + locations}

### Suggested action
{"Ready to apply all proposals" | "Review proposals then re-run"}
```

---

## Phase 7 — Apply approved changes

After user approves proposals:

1. Apply CSS coverage removals
2. Apply variation expansions (CSS + `$styles`)
3. Apply gap fixes (G1–G8 as approved)
4. If G1 v1 → v2 migration was approved:
   - Ensure `BaseCustomElement.js` exists in theme
   - Rewrite view, CSS, create JS file, update provider
   - If the full rewrite is too invasive, delegate to `/block-scaffolding` as fallback

Then:

```bash
lando theme-build   # must exit 0
lando flush         # clear caches
```

---

## Phase 8 — Verification

| Level | Source | What to validate | Required |
|---|---|---|---|
| A | Playwright MCP | `document.querySelector('block-{slug}').constructor.name === 'Block{PascalSlug}'` | If v2 |
| B | Playwright MCP | Screenshot at canonical width; compare against reference | Yes |
| C | Playwright MCP | All variations render as proposed | Yes (Full mode) |
| D | Human | Approve changes before commit | First apply |

Then commit:

```
git commit -m "refactor(blocks): {slug} — {summary of applied changes}"
```

---

## Anti-drift — don't reintroduce

See `/block-scaffolding` anti-drift table — same rules apply during refactor. Every
proposal in Phase 6 should, after applied, produce code that would pass `/block-scaffolding`
as if the block were being created today.
