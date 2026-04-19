# Onda 1 — Validation Report

> **Status:** Automated checks PASS. Manual smoke + token measurement pending.

---

## Validator

```
node scripts/validate-skills.mjs
Summary: 43 passed, 21 warnings, 0 errors
```

- 0 skills exceed 500 lines (new soft-limit check operational).
- 21 warnings are pre-existing missing-section warnings from skills outside Onda 1 scope — not regressions.

```
node scripts/test-validate-skills.mjs
9 passed, 0 failed
```

All 4 test cases pass including the new >500-line warning test.

---

## Skills refactored (Onda 1)

| Skill | Before | After | References | Scripts | Assets |
|---|---|---|---|---|---|
| `acorn-middleware` | 817 L | 145 L | 4 | 1 | 2 |
| `acorn-queues` | 745 L | 181 L | 5 | 2 | 2 |
| `acorn-livewire` | 744 L | 171 L | 5 | 2 | 2 |
| `acorn-routes` | 672 L | 296 L | 5 | 1 | 2 |
| `acorn-eloquent` | 597 L | 252 L | 7 | 2 | 2 |
| `block-scaffolding` | 547 L | 329 L | 5 | 1 | 3 |
| `wp-performance` | 505 L | 271 L | 6 | 2 | 0 |

All 7 skills now have `SKILL.md ≤ 500 lines`. `CLAUDE.md` plugin-level rules installed.

---

## Cross-platform smoke

> **Manual — requires user action.** Run in a real Sage/Lando project.

### Claude Code smoke

Open a fresh Claude Code session in a Sage project. Run `/onboarding`. Then:
> "Create a new Livewire component called `ContactForm` with an email field."

Expected:
- `acorn-livewire` skill activates.
- Claude calls `scripts/create-component.sh` (not manual stubs).
- No errors, no missing references.

**Result:** `PASS / FAIL — <notes>`

### Cursor smoke (if configured)

Same prompt in Cursor. Verify skill activation works.

**Result:** `PASS / FAIL / N/A — <notes>`

---

## Token measurement (session-padrão)

> **Manual — requires user action.** Measure tokens in a real Claude Code session.

**Session-padrão definition:**
1. Open reference Sage project.
2. Run `/onboarding`.
3. Run `/building` on a simple hero block until Claude produces the first code diff.
4. Capture total input tokens at that point.

| Metric | Before Onda 1 | After Onda 1 | Δ |
|---|---|---|---|
| `/onboarding` preamble input tokens | `<measure>` | `<measure>` | `<%>` |
| `/building` first-diff input tokens | `<measure>` | `<measure>` | `<%>` |

**Target:** ≥ 30% reduction on `/onboarding` preamble.

**Result:** `PASS (≥30%) / MISS (<30%) — <notes>`

---

## Fallback decision (Onda 6 gate)

> Populated after Onda 5 ships and real-world data is available.

- ≥ 20% of observed projects run WP < 6.9: `<TBD>`
- ≥ 10% of projects run without Lando: `<TBD>`
- Users explicitly request fallback: `<TBD>`
- Measurable token-reduction value demonstrated: `<TBD>`

**Go / No-go:** `<TBD after Onda 5>`
