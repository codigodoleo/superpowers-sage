Deep reference for block refactoring report format. Loaded on demand from `skills/block-refactoring/SKILL.md`.

# Report Format

The structured output format for a block refactoring report — current state assessment, proposed changes, migration risk, and rollback plan.

## Block Refactoring Report Template

Produce this structured report in Phase 6:

````markdown
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
- G9 Component reuse gap: {count + locations}
- G10 CSS custom property cascade not used: {count + locations} — when flagged, see G10 section below
- G11 nl2br on text fields: {count + locations}

### Suggested action
{"Ready to apply all proposals" | "Review proposals then re-run"}

### Decision Log

| Proposal | Status | Reason if deferred |
|---|---|---|
| {proposal from Phase 6} | Applied / Deferred | {reason} |
````

---

When G10 is flagged, include this section in the Phase 6 report:

````markdown
### G10 — CSS custom property cascade not used

**Current:** `<x-eyebrow :label="$eyebrow" tone="fg" />` (color hardcoded via prop)
**Impact:** Each new variation or dark mode requires touching every block view.

**Proposed fix — `resources/css/blocks/{slug}.css`:**

```css
@reference "../app.css";

block-{slug} {
  @apply block overflow-hidden;

  --eyebrow-color:   var(--color-identity);
  --heading-color:   var(--color-fg);
  --body-color:      var(--color-fg);
  --decorator-color: var(--color-identity);
}
```

*(For dark-background blocks, replace values per the decision table in SKILL.md G10 step 3.)*

**Proposed fix — `resources/views/blocks/{slug}.blade.php`:**
Remove `tone="fg"` from `<x-eyebrow>` and `<x-section-header>` calls.
Child components will inherit color from CSS variables automatically.
````

## Approval Gate — Before Phase 7

After presenting the complete Phase 6 report (including G10 CSS diffs when applicable):

```
Apply all proposed fixes listed above? [y/N]
```

On `y` → Phase 7 applies all fixes atomically.
On `N` → stop; user reviews report individually and re-runs with specific items.

## Applying Approved Changes (Phase 7)

After user approves:

1. Apply CSS coverage removals
2. Apply variation expansions (CSS + `$styles`)
3. Apply gap fixes (G1–G11 as approved)
   - If **G8 includes a slug rename**: generate a **single consolidated migration script** covering
     field key renames + slug/group key rewrite + block type in `post_content`. This avoids two
     separate human-gate cycles. Structure: PASS 1 (field keys), PASS 2 (group key references),
     PASS 3 (`<!-- wp:acf/{old-slug}` → `<!-- wp:acf/{new-slug}` in `post_content`). Use
     `git mv` for the four filename renames to preserve history.
4. If G1 v1 → v2 migration was approved:
   - Ensure `BaseCustomElement.js` exists in theme
   - Rewrite view, CSS, create JS file, update provider
   - If the full rewrite is too invasive, delegate to `/block-scaffolding` as fallback

Then:

```bash
lando theme-build   # must exit 0
lando flush         # clear caches
```

## Verification (Phase 8)

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
