# Plugin Expansion — Onda 4 Implementation Plan (scoped)

> **Status:** Scoped scaffolding. Expand to full TDD when Onda 3 closes.

**Goal:** Add three specialized subagents that operate in isolated context to offload heavy analysis from the main session.

**Architecture:** Each subagent is a markdown file in `agents/` with trigger-rich description, declared tools, and a clear operational checklist. Subagents are invoked via the Task tool by the main agent when the user's task matches.

**Tech Stack:** Markdown, YAML frontmatter, standard agent tool allowlist pattern.

**Source spec:** `docs/superpowers/specs/2026-04-18-plugin-expansion-design.md`
**Prerequisite:** Onda 2 done for `4.1` (migration agent references refactored Acorn skills); Onda 1 done for `4.3` (livewire-debugger references refactored livewire skill).

---

## Microplan scope

| ID | Agent | Purpose | Tools |
|---|---|---|---|
| 4.1 | `agents/acorn-migration.md` | Analyze procedural legacy WP plugin code, propose incremental migration to Acorn (Service Providers, Facades, Eloquent) | Read, Grep, Glob, Bash |
| 4.2 | `agents/tailwind-v4-auditor.md` | Four-category audit: v3→v4 syntax migration + arbitrary value tokenization + PHP color-prop resolution + CSS variable cascade coverage. See expanded spec below. | Read, Grep, Glob |
| 4.3 | `agents/livewire-debugger.md` | Diagnose components that fail to mount/update: component + view + Alpine bindings + network | Read, Grep, Bash |

## Quality bar

**B**. Each agent ships with:
- Trigger-rich YAML description (audited per 2.5 standards).
- Operational checklist in the body (explicit steps).
- Tool allowlist minimally scoped.
- One manual eval scenario per agent documented in `agents/__evals__/<agent>.md`.

## Dependencies

- 4.1 references skills refactored in Onda 1 + 2 (acorn-routes, acorn-eloquent, acorn-middleware).
- 4.3 references `acorn-livewire` refactor from 1.3.
- 4.2 is independent and can run first.

## Success criteria

- Each agent invokable via Task tool with a fixture prompt and returns structured output.
- No agent loads more than its stated references (verify via trace of Read calls during eval).
- Cross-platform: Cursor and Claude Code both can invoke each agent.

---

## MP 4.2 — Expanded spec: `agents/tailwind-v4-auditor.md`

> **Source feedback:** `interioresdecora.com.br/docs/superpowers/feedback/2026-04-19-design-system-component-architecture.md`

The auditor runs four categories sequentially and produces a severity-ranked report.

### Audit Category A — v3→v4 syntax migration (original scope)

| Check | Signal | Severity |
|---|---|---|
| `tailwind.config.js` exists | v3 config still present | CRITICAL |
| `theme()` function in CSS | should be `var(--*)` in v4 | HIGH |
| `@apply` outside component primitives | prefer utility composition | MEDIUM |
| Deprecated v3 utilities (e.g. `transform`, `filter` bare classes) | use v4 equivalents | MEDIUM |
| `@tailwind base/components/utilities` directives | replaced by `@import "tailwindcss"` | HIGH |

### Audit Category B — Arbitrary value tokenization

Grep for `[value]` patterns in Blade/CSS files. For each hit, determine whether a semantic token exists in `@theme` or should be added.

| Pattern | Example | Action |
|---|---|---|
| `text-[Npx]` | `text-[9px]` | Map to `@theme` font-size token; suggest name (e.g. `text-xs-btn`) |
| `tracking-[Npx]` | `tracking-[1.2px]` | Map to `@theme` letter-spacing token; suggest name |
| `max-w-[Npx]` / `w-[Npx]` / `h-[Npx]` | `max-w-[640px]` | Suggest semantic token or Tailwind scale equivalent |
| `gap-[Npx]` / `p-[Npx]` | `gap-[24px]` | Map to spacing token |
| `bg-[#hex]` / `text-[#hex]` | `text-[#F4EFE8]` | Map to `@theme` color token |

Severity: **CRITICAL** for values in shared components (they block design-system consistency). **HIGH** for values in block views.

### Audit Category C — PHP color-prop resolution (G10)

Detect patterns where Tailwind class strings are computed in PHP based on a color-context prop, bypassing CSS variable inheritance.

**Patterns to detect:**

```php
// match($tone) → Tailwind class string
$textClass = match ($tone) { 'fg' => 'text-fg', ... };

// Ternary building class string
$cls = $dark ? 'text-depth-fg bg-depth' : 'text-fg bg-white';

// Variable interpolation in class string
<div class="text-{{ $color }}">
```

**Component prop patterns to flag:**
- Component signatures with `tone`, `on-dark`, `color-context`, `variant` props that encode color (not layout)
- Blade components called with `tone="fg"` / `tone="identity"` / `variant="dark"` from block views

**Severity:** CRITICAL for components used across many blocks (eyebrow, button, section-header). HIGH for block-local usage.

**Recommended fix:** CSS custom property inheritance. Components declare `--eyebrow-color`, `--heading-color`, `--decorator-color` etc. with `:root` defaults. Blocks override them in their `.css` file for their color context. Views become color-agnostic — no tone props.

```css
/* :root defaults in app.css */
:root {
  --eyebrow-color: var(--color-fg);
  --heading-color: var(--color-fg);
  --decorator-color: var(--color-identity);
}

/* Block variation — single CSS rule, no view changes */
.is-style-dark block-value-proposition {
  --heading-color: var(--color-depth-fg);
  --eyebrow-color: var(--color-depth-fg);
  --decorator-color: var(--color-depth-fg);
}
```

### Audit Category D — CSS variable cascade coverage

Check whether blocks properly initialize their color context via CSS variables instead of hardcoded utility classes.

**Signals of missing cascade:**

1. **Block `.css` file only contains `display: block`** — no CSS variable declarations. The block's color context is unspecified; components will fall back to `:root` defaults even when the block has a colored background.

2. **Hardcoded color utilities on semantic elements** — `<h2 class="text-fg">`, `<p class="text-depth-fg">` inside block views instead of `style="color: var(--heading-color)"` or `text-[var(--heading-color)]`.

3. **Block styles only add variations via JS-class conditionals in PHP** instead of CSS `is-style-*` selectors with variable overrides.

**Output for this category:** For each block CSS file, report whether it declares CSS variables, and flag hardcoded color classes in the corresponding view.

**Dark-mode readiness note:** A project with complete CSS variable cascade coverage can implement dark mode in a single `@media (prefers-color-scheme: dark)` block at `:root`. Blocks with hardcoded color classes require per-block touch. Flag total affected block count.

### Audit output format

```
## Tailwind v4 Audit — <project name>

### Summary
- Category A (v3 syntax): N issues (X critical, Y high)
- Category B (arbitrary values): N issues across N files
- Category C (PHP color props): N components affected, N block calls flagged
- Category D (CSS variable cascade): N/N blocks have cascade declarations

### CRITICAL
[list with file:line, pattern found, recommended fix snippet]

### HIGH
[list]

### MEDIUM / LOW
[list, grouped by category]

### Dark-mode readiness score
N/N blocks cascade-ready. Estimated effort to add dark mode: N files.
```

### Eval scenario

Prompt: "Run the Tailwind v4 auditor on this theme."

Expected: Agent reads `resources/css/app.css`, globs `resources/css/blocks/`, globs `resources/views/components/`, globs `resources/views/blocks/`, and returns a structured report with all four categories populated. No false positives on correctly tokenized utilities.

---

## Handoff note

Expand each microplan to full TDD when Onda 3 closes. For 4.2, the agent body must implement all four audit categories as explicit checklist steps, with grep patterns documented inline so the agent executes them deterministically.
