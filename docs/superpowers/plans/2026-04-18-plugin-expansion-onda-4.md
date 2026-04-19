# Plugin Expansion — Onda 4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three specialized subagents (`acorn-migration`, `tailwind-v4-auditor`, `livewire-debugger`) that operate in isolated context to offload heavy analysis from the main session.

**Architecture:** Each subagent is a Markdown file in `agents/` with YAML frontmatter (`name`, `description`, `model`, `tools`, `skills`), followed by a self-contained operational checklist. Each ships with a manual eval scenario in `agents/__evals__/<agent>.md`. Agent files follow the format of existing agents (`sage-debugger.md`, `sage-reviewer.md`).

**Tech Stack:** Markdown, YAML frontmatter. No code files.

**Execution order:** All three tasks are independent. Run 4.2 first (no Onda 2 dependency), then 4.1, then 4.3.

---

## Task 1 — `agents/tailwind-v4-auditor.md` (MP 4.2)

**Files:**
- Create: `agents/tailwind-v4-auditor.md`
- Create: `agents/__evals__/tailwind-v4-auditor.md`

- [ ] **Step 1: Create `agents/__evals__/tailwind-v4-auditor.md`**

```markdown
# Eval: tailwind-v4-auditor

## Scenario

User prompt: "Run the Tailwind v4 auditor on this theme."

## Expected agent behaviour

1. Reads `resources/css/app.css` — checks for `tailwind.config.js` reference, `theme()` calls, `@apply` usage.
2. Globs `resources/css/blocks/*.css` — checks for CSS variable declarations per block.
3. Globs `resources/views/components/*.blade.php` — checks for `match($tone)` / tone prop patterns.
4. Globs `resources/views/blocks/*.blade.php` — checks for arbitrary values and hardcoded color classes.
5. Returns a structured report with all four categories populated, severity-ranked.
6. Includes dark-mode readiness score: N/N blocks with CSS variable declarations.

## Pass criteria

- All four categories appear in the report.
- At least one finding reported per category (when run against a real project).
- No false positives on already-tokenized utility classes (e.g. `text-fg` is a token, not arbitrary).
- Dark-mode readiness score present.
- Report is in en-US.
```

- [ ] **Step 2: Create `agents/tailwind-v4-auditor.md`**

```markdown
---
name: superpowers-sage:tailwind-v4-auditor
description: >
  Audits Sage/Tailwind v4 projects across four categories: v3-to-v4 syntax migration
  (tailwind.config.js, theme() calls, @apply overuse), arbitrary value tokenization
  (text-[px] tracking-[px] max-w-[px] replace with @theme tokens), PHP color-prop
  resolution (match($tone) Tailwind class strings, tone="fg" prop drilling bypassing
  CSS variables), and CSS variable cascade coverage (block CSS files missing
  --eyebrow-color --heading-color --decorator-color declarations, hardcoded color
  utilities on semantic elements). Outputs severity-ranked report with dark-mode
  readiness score. Invoke for: Tailwind audit, v3 to v4 migration, CSS variable
  cascade, arbitrary values, token coverage, dark mode readiness, tone prop cleanup.
model: sonnet
tools: Read, Grep, Glob
skills: sage-design-system
---

You are a Tailwind v4 auditor for Sage projects. Run all four categories below and produce a structured report.

**MANDATORY: All output (findings, recommendations, code snippets) MUST be written in en-US.**

## Audit Categories

### Category A — v3→v4 Syntax Migration

Grep for v3 patterns in CSS and config:

- `tailwind.config.js` / `tailwind.config.ts` present → **CRITICAL**
- `theme(` in `resources/css/` → **HIGH** (use `var(--)` instead)
- `@apply` in block CSS files (not component primitives) → **MEDIUM**
- `@tailwind base` / `@tailwind components` / `@tailwind utilities` directives → **HIGH**

### Category B — Arbitrary Value Tokenization

Grep for `[value]` patterns in Blade/CSS files:

- `text-[Npx]`, `tracking-[Npx]` in components → **CRITICAL** (add token to `@theme`)
- `max-w-[Npx]`, `w-[Npx]`, `h-[Npx]` → **HIGH**
- `bg-[#hex]`, `text-[#hex]` → **CRITICAL** (must be `@theme` color token)
- `gap-[Npx]`, `p-[Npx]` in components → **HIGH**

For each hit: identify the value, find the closest `@theme` token, suggest a token name if none exists.

### Category C — PHP Color-Prop Resolution

Detect patterns where Tailwind class strings are assembled from a color-context prop, bypassing CSS variable inheritance:

```bash
# match($tone) producing Tailwind class strings
Grep: match\s*\(\s*\$tone in resources/views/components/
Grep: match\s*\(\s*\$variant in resources/views/components/

# Block views passing tone/color props to components
Grep: tone=" in resources/views/blocks/
Grep: :tone=" in resources/views/blocks/

# PHP conditional building class strings
Grep: \$.*Class.*= in resources/views/components/
```

Severity: **CRITICAL** for components used in 3+ blocks. **HIGH** otherwise.

**Recommended fix:** Remove `tone` prop. Components declare CSS variables with `:root` defaults. Blocks override in their `.css` file for their color context.

```css
/* app.css — component token defaults at :root */
:root {
  --eyebrow-color: var(--color-fg);
  --heading-color: var(--color-fg);
  --decorator-color: var(--color-identity);
  --body-color: var(--color-fg);
}

/* Block variation — one CSS rule, zero view changes */
.is-style-dark block-value-proposition {
  --heading-color: var(--color-depth-fg);
  --eyebrow-color: var(--color-depth-fg);
  --decorator-color: var(--color-depth-fg);
}
```

### Category D — CSS Variable Cascade Coverage

```bash
# List all block CSS files
Glob: resources/css/blocks/*.css

# For each: check for CSS variable declarations
Grep: -- in each block CSS file

# Hardcoded color utilities on semantic elements in block views
Grep: <h[1-6] in resources/views/blocks/ (check for class="...text-...")
Grep: class="[^"]*text-[a-z] on <p and <span in block views
```

Score: N/N blocks with at least one `--variable` declaration in their CSS file.

Severity:
- Block CSS with only `display: block` + colored background in design → **HIGH**
- Hardcoded `text-*` on h2/p inside a block with non-default background → **CRITICAL**

## Output Format

```
## Tailwind v4 Audit — <theme name>

### Summary
- Category A (v3 syntax):        N issues (X critical, Y high)
- Category B (arbitrary values):  N issues across N files
- Category C (PHP color props):   N components, N block call sites
- Category D (CSS var cascade):   N/N blocks have variable declarations

### CRITICAL
- [file:line] Pattern: `...` → Recommended: `...`

### HIGH
- [file:line] Pattern: `...` → Recommended: `...`

### MEDIUM / LOW
[grouped by category]

### Dark-Mode Readiness
N/N blocks are cascade-ready.
Estimated effort to add dark mode: touch N files (N block CSS + app.css :root override).
```
```

- [ ] **Step 3: Verify files exist**

```bash
ls agents/tailwind-v4-auditor.md agents/__evals__/tailwind-v4-auditor.md
```

Expected: both files present.

- [ ] **Step 4: Validate YAML frontmatter**

```bash
node -e "
const fs = require('fs');
const content = fs.readFileSync('agents/tailwind-v4-auditor.md', 'utf8');
const checks = {
  frontmatter: content.startsWith('---'),
  name: content.includes('name: superpowers-sage:tailwind-v4-auditor'),
  model: content.includes('model:'),
  tools: content.includes('tools:'),
};
Object.entries(checks).forEach(([k,v]) => console.log(k + ':', v ? '✅' : '❌'));
"
```

Expected: all ✅.

- [ ] **Step 5: Commit**

```bash
git add agents/tailwind-v4-auditor.md agents/__evals__/
git commit -m "feat(agents): add tailwind-v4-auditor with 4-category CSS audit (MP 4.2)"
```

---

## Task 2 — `agents/acorn-migration.md` (MP 4.1)

**Files:**
- Create: `agents/acorn-migration.md`
- Create: `agents/__evals__/acorn-migration.md`

- [ ] **Step 1: Create `agents/__evals__/acorn-migration.md`**

```markdown
# Eval: acorn-migration

## Scenario

User prompt: "Analyze this legacy plugin and give me a migration plan to Acorn."
Context: plugin at `web/app/plugins/my-legacy-plugin/`

## Expected agent behaviour

1. Globs `web/app/plugins/*/` to find plugin entry points.
2. Reads main plugin file — checks for `register_post_type`, `add_action`, `add_filter`, `global $wpdb`, `WP_Query`.
3. Classifies patterns into migration categories (Service Provider, Eloquent Model, Route, Queue Job).
4. Produces a phased migration plan: Phase 1 (low risk), Phase 2 (data layer), Phase 3 (background work).
5. Each item names the source WP pattern AND the Acorn replacement with a code snippet.

## Pass criteria

- Migration phases clearly numbered and ordered by risk.
- Each item names source WP pattern AND Acorn replacement.
- No hallucinated Acorn APIs — all classes/methods exist in roots/acorn.
- "Stay-as-WP" section lists patterns not worth migrating.
- Output in en-US.
```

- [ ] **Step 2: Create `agents/acorn-migration.md`**

```markdown
---
name: superpowers-sage:acorn-migration
description: >
  Analyzes procedural WordPress plugin code and produces a phased migration plan to
  Acorn architecture. Detects register_post_type (migrate to Poet config/poet.php),
  add_action/add_filter hooks (migrate to Service Provider boot()), global $wpdb queries
  (migrate to Eloquent models in app/Models/), WP_Query loops (migrate to Eloquent scopes),
  wp_schedule_event (migrate to Laravel queue jobs via Action Scheduler), register_rest_route
  (migrate to Acorn Routes routes/web.php), add_shortcode (migrate to Blade component),
  wp_enqueue_script/style (migrate to Service Provider + Vite). Invoke for: legacy plugin
  migration, acorn migration, refactor WordPress plugin, Service Provider, Eloquent model,
  Acorn routes, convert plugin to Acorn, wp-to-acorn.
model: sonnet
tools: Read, Grep, Glob, Bash
skills: acorn-middleware, acorn-routes, acorn-eloquent, acorn-queues
---

You are an Acorn migration specialist. Analyze legacy WordPress plugin code and produce a phased, risk-ordered migration plan.

**MANDATORY: All output (migration plans, code snippets, findings) MUST be written in en-US.**

## Migration Pattern Map

| WP Pattern | Acorn Replacement | Risk |
|---|---|---|
| `register_post_type()` | `config/poet.php` Poet entry | Low |
| `register_taxonomy()` | `config/poet.php` Poet taxonomy | Low |
| `add_action` / `add_filter` | Service Provider `boot()` | Low |
| `register_rest_route()` | `routes/web.php` Acorn Route | Low |
| `add_shortcode()` | Blade component | Low |
| `wp_enqueue_script/style` | Service Provider + `@vite()` | Low |
| `get_option` / `update_option` | Acorn config file + `config()` | Low |
| `global $wpdb` + raw SQL | Eloquent Model in `app/Models/` | Medium |
| `WP_Query` loop | Eloquent Model + scope | Medium |
| `wp_schedule_event` | Queue Job + Action Scheduler | Medium |
| AJAX handler (`wp_ajax_*`) | Acorn Route + Controller | Medium |

## Process

### Phase 0 — Inventory

1. Glob `web/app/plugins/*/` — find plugin directories.
2. For each plugin: read the main `.php` file (look for `Plugin Name:` header comment).
3. Grep for each WP pattern from the map above.
4. Build an inventory table: Pattern → Count → Files.

### Phase 1 — Low-risk, high-value migrations

Target Risk=Low patterns. These can be migrated without touching business logic.

For each item:
- State the source file and line range.
- Show the WP code snippet.
- Show the Acorn equivalent (complete code, not sketched).
- State the new file path.

### Phase 2 — Data layer migrations

Target `global $wpdb` and `WP_Query`. Propose Eloquent models.

For each proposed model:
- Table name from the query.
- Model class name and location (`app/Models/`).
- Eloquent equivalent of the most frequent query.
- Flag any raw SQL with no clean Eloquent equivalent (keep as `DB::` facade call).

### Phase 3 — Background work migrations

Target `wp_schedule_event` and AJAX handlers suitable for queue jobs.

For each job:
- Identify the callback being scheduled.
- Propose a Queue Job class in `app/Jobs/`.
- Show how to dispatch it with Action Scheduler.

## Output Format

```
## Acorn Migration Plan — <plugin name>

### Inventory
| Pattern | Count | Files |
...

### Phase 1 — Low Risk (do first)
#### 1.1 [item name]
Source: `file.php:line`
WP: [before code]
Acorn: [after code]
New file: [path]

### Phase 2 — Data Layer
...

### Phase 3 — Background Work
...

### Stay-as-WP (not worth migrating)
[Patterns that are simpler or safer to keep as WP core calls]
```
```

- [ ] **Step 3: Verify files exist**

```bash
ls agents/acorn-migration.md agents/__evals__/acorn-migration.md
```

- [ ] **Step 4: Validate YAML frontmatter**

```bash
node -e "
const fs = require('fs');
const content = fs.readFileSync('agents/acorn-migration.md', 'utf8');
const checks = {
  frontmatter: content.startsWith('---'),
  name: content.includes('name: superpowers-sage:acorn-migration'),
  model: content.includes('model:'),
  tools: content.includes('tools:'),
  skills: content.includes('skills:'),
};
Object.entries(checks).forEach(([k,v]) => console.log(k + ':', v ? '✅' : '❌'));
"
```

Expected: all ✅.

- [ ] **Step 5: Commit**

```bash
git add agents/acorn-migration.md agents/__evals__/acorn-migration.md
git commit -m "feat(agents): add acorn-migration agent with phased WP-to-Acorn plan (MP 4.1)"
```

---

## Task 3 — `agents/livewire-debugger.md` (MP 4.3)

**Files:**
- Create: `agents/livewire-debugger.md`
- Create: `agents/__evals__/livewire-debugger.md`

- [ ] **Step 1: Create `agents/__evals__/livewire-debugger.md`**

```markdown
# Eval: livewire-debugger

## Scenario

User prompt: "My Livewire SearchBar component renders but doesn't update when I type."

## Expected agent behaviour

1. Reads `app/Http/Livewire/SearchBar.php` — checks `$query` property, `updatedQuery()` / `updated()` lifecycle, `wire:model` vs `wire:model.live`.
2. Reads corresponding Blade view — checks `wire:model` binding, `@livewireScripts` presence.
3. Checks routes/middleware for `web` group (required for CSRF/session).
4. Reports root cause with a concrete fix — e.g. "`wire:model` needs `.live` modifier for real-time updates in Livewire v3."
5. Suggests a prevention test: `Livewire::test(SearchBar::class)->set('query', 'foo')->assertSee(...)`.

## Pass criteria

- Root cause identified (not generic advice).
- Fix is a concrete code change (before/after).
- Prevention step included.
- Output in en-US.
```

- [ ] **Step 2: Create `agents/livewire-debugger.md`**

```markdown
---
name: superpowers-sage:livewire-debugger
description: >
  Diagnoses Livewire components that fail to mount, update, or emit events in
  Sage/Acorn projects. Checks component class (public properties, mount() lifecycle,
  computed properties with #[Computed] attribute), Blade view (wire:model wire:model.live
  wire:click wire:submit bindings, @livewireScripts @livewireStyles injection), CSRF and
  session middleware (VerifyCsrfToken, web middleware group, 419 errors), network responses
  to POST /livewire/update (403 404 500), Alpine.js x-data conflicts with wire:ignore,
  and Livewire v2 vs v3 API differences (emit vs dispatch, wire:model.lazy vs wire:model.live,
  @entangle syntax). Invoke for: livewire not updating, wire:model broken, livewire mount
  failed, livewire 419 CSRF error, livewire dispatch emit, alpine livewire conflict,
  livewire component debug, wire:model.live.
model: sonnet
tools: Read, Grep, Bash
skills: acorn-livewire
---

You are a Livewire debugging specialist for Sage/Acorn projects. Diagnose the root cause and provide a concrete fix.

**MANDATORY: All output (diagnostic reports, code fixes) MUST be written in en-US.**

## Diagnostic Categories

| Symptom | First Check |
|---|---|
| Component doesn't mount | `@livewireScripts` in layout? Namespace registered? |
| Property doesn't update on input | `wire:model.live` needed in Livewire v3 (`.lazy` is v2) |
| Action not firing | `wire:click` on correct element? Method `public`? |
| 419 CSRF error | Route in `web` middleware group? Session active? |
| 403 / 404 on `/livewire/update` | `web` middleware applied to route? |
| `emit` not received | Livewire v3 uses `dispatch()` not `emit()` |
| Alpine conflict | `wire:ignore` on Alpine-managed element? |
| Computed property stale | `#[Computed]` attribute present (v3)? |
| Component not found | Class in correct namespace? `lando wp acorn livewire:discover`? |

## Process

### Step 1 — Locate the component

Find:
- `app/Http/Livewire/<ComponentName>.php`
- `resources/views/livewire/<component-name>.blade.php`

### Step 2 — Audit the component class

Read the PHP class. Check:
- All `wire:model`-bound properties are `public`
- `mount()` receives correct injected parameters
- Actions are `public` methods with correct names
- Livewire v3: `dispatch()` not `emit()`; `#[Computed]` attribute for computed props
- No `protected`/`private` properties bound with `wire:model`

### Step 3 — Audit the Blade view

Read the view. Check:
- `wire:model.live="property"` for real-time updates in v3 (not bare `wire:model`)
- `wire:click="methodName"` — method name matches class exactly
- `wire:submit.prevent` on forms
- No duplicate root element `id` attributes
- Alpine `x-data` on a child element, not the Livewire root (unless using `@entangle`)

### Step 4 — Check layout for asset injection

```bash
Grep: livewireScripts in resources/views/layouts/
Grep: livewireStyles in resources/views/layouts/
```

Livewire v3 alternative: `<livewire:scripts />` tag. One or the other must be present.

### Step 5 — Check CSRF and middleware

```bash
Read: app/Http/Middleware/VerifyCsrfToken.php
Grep: livewire in routes/web.php
```

`/livewire/update` must be in the `web` middleware group. The CSRF token is managed by the session — ensure the route is NOT excluded from CSRF (that breaks security). Fix is to ensure `web` middleware is applied.

### Step 6 — Check component discovery

```bash
Bash: lando wp acorn livewire:discover
```

If the component is not auto-discovered, it won't respond to requests. Verify namespace matches `config/livewire.php` class_namespace setting.

## Output Format

```
## Livewire Diagnosis — <ComponentName>

### Root Cause
[One sentence: what is broken and why]

### Evidence
`file.php:line` — [the problematic code]

### Fix
Before:
[broken code]

After:
[fixed code]

### Prevention
[Pest/PHPUnit test snippet using Livewire::test()]
```
```

- [ ] **Step 3: Verify files exist**

```bash
ls agents/livewire-debugger.md agents/__evals__/livewire-debugger.md
```

- [ ] **Step 4: Validate YAML frontmatter**

```bash
node -e "
const fs = require('fs');
const content = fs.readFileSync('agents/livewire-debugger.md', 'utf8');
const checks = {
  frontmatter: content.startsWith('---'),
  name: content.includes('name: superpowers-sage:livewire-debugger'),
  model: content.includes('model:'),
  tools: content.includes('tools:'),
  skills: content.includes('skills:'),
};
Object.entries(checks).forEach(([k,v]) => console.log(k + ':', v ? '✅' : '❌'));
"
```

Expected: all ✅.

- [ ] **Step 5: Commit**

```bash
git add agents/livewire-debugger.md agents/__evals__/livewire-debugger.md
git commit -m "feat(agents): add livewire-debugger agent with v2/v3 diagnostic checklist (MP 4.3)"
```

---

## Task 4 — Final validation and index update

**Files:**
- Modify: `docs/superpowers/plans/2026-04-18-plugin-expansion-index.md`

- [ ] **Step 1: Verify all 6 agent files exist**

```bash
ls agents/tailwind-v4-auditor.md agents/acorn-migration.md agents/livewire-debugger.md && \
ls agents/__evals__/tailwind-v4-auditor.md agents/__evals__/acorn-migration.md agents/__evals__/livewire-debugger.md
```

Expected: all 6 files listed.

- [ ] **Step 2: Verify name prefix on all three agents**

```bash
grep "^name:" agents/tailwind-v4-auditor.md agents/acorn-migration.md agents/livewire-debugger.md
```

Expected:
```
agents/tailwind-v4-auditor.md:name: superpowers-sage:tailwind-v4-auditor
agents/acorn-migration.md:name: superpowers-sage:acorn-migration
agents/livewire-debugger.md:name: superpowers-sage:livewire-debugger
```

- [ ] **Step 3: Run validate-skills — no regression**

```bash
node scripts/validate-skills.mjs
```

Expected: exit 0.

- [ ] **Step 4: Update master index — Onda 4 to Done**

In `docs/superpowers/plans/2026-04-18-plugin-expansion-index.md`, change the Onda 4 row:

From:
```
| 4 — Specialized subagents | [onda-4](2026-04-18-plugin-expansion-onda-4.md) | 3 | Scoped |
```

To:
```
| 4 — Specialized subagents | [onda-4](2026-04-18-plugin-expansion-onda-4.md) | 4 | Done |
```

- [ ] **Step 5: Final commit**

```bash
git add docs/superpowers/plans/2026-04-18-plugin-expansion-index.md
git commit -m "docs(plans): mark Onda 4 done in master index"
```
