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

### Suggested action
{"Ready to apply all proposals" | "Review proposals then re-run"}
````

## Applying Approved Changes (Phase 7)

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
