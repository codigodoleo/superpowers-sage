Deep reference for Tailwind v4 design token setup in Sage. Loaded on demand from `skills/sage-design-system/SKILL.md`.

# Tokens Setup

How to classify a design file (Paper/Figma/CSS spec) and extract it into `@theme` tokens in `resources/css/app.css`.

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
