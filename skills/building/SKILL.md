---
name: superpowers-sage:building
description: Scaffold and implement Sage components following a plan; reads sub-plans and design assets, consults reference skills, implements PHP blocks + Blade views + CSS, invokes /verifying after each component. Knows how to delegate independent components to parallel subagents.
user-invocable: true
argument-hint: "[plan path or component description]"
---

# Building — Plan-Driven Implementation

Implement Sage components by reading from plan directories, consulting design assets, and verifying after each component.

**Announce at start:** "I'm using the building skill to implement from the plan."

## Inputs

$ARGUMENTS

If a plan path is provided, read the plan. Otherwise, check for active plan in `docs/plans/`.

## Procedure

### 0) Load the plan

1. Read `plan.md` frontmatter for strategy, components, design-tool
2. Read `architecture.md` for architectural decisions
3. Read `content-model.md` for data modeling decisions
4. List `components/` for sub-plans
5. List `assets/` for design reference images

If no plan exists, suggest running `/architecture-discovery` then `/plan-generator` first.

### 1) Set up prerequisites

Based on content model:

1. If CPTs needed → configure `config/poet.php`
2. If new packages needed → `lando theme-composer require <package>`
3. If Options Pages needed → create ACF Options class
4. Run `lando flush` after PHP changes

### 2) Implement components (per sub-plan)

**Design system gate (runs once, before the component loop):**

Check that the visual foundation exists:

- `resources/css/design-tokens.css` — must exist and contain real tokens (not placeholder)
- Route `/kitchensink` — must be accessible and visually validated (Playwright screenshot taken)

If either is missing or unvalidated → **invoke `/sage-design-system` and pause** until the kitchensink screenshot confirms all tokens and UI atoms render correctly. Do NOT implement any block without a validated design system.

For each component in order:

#### 0) Dispatch design-extractor in SURGICAL mode

Before reading any cached assets, dispatch the `design-extractor` agent fresh for this component:

- Mode: SURGICAL
- Target: this specific component section only
- Output: `assets/section-<name>-spec.md` and `assets/section-<name>-ref.png`

This is always fresh — do NOT skip to use cached assets from context memory.
The surgical extraction provides exact px values, SVG code, and Verification Inputs
that the `visual-verifier` agent requires.

**Fallback (no design-extractor agent available — Cursor IDE / single-agent mode):**

If the subagent system is unavailable:

1. Re-read `assets/section-<name>-spec.md` and `assets/section-<name>-ref.png` from disk
2. Pull live design reference via the active MCP tool:
   - Figma: `get_design_context` + `get_metadata` (node geometry)
   - Paper: `get_computed_styles` + `get_node_info`
   - Pencil: `batch_get(resolveVariables: true)` + `batch_get(readDepth: 4)`
   - Stitch: `get_screen`
3. Record `design-extractor: deferred` in the `plan.md` frontmatter
4. Use the values extracted from step 2 as the source of truth

#### a) Re-read design reference (ALWAYS)

- Read `assets/section-{name}.png` or `assets/section-{name}.md` from disk
- **NEVER rely on context memory** — always re-read from disk before each component
- If asset missing, invoke `/designing` to capture it

#### b) Check content model

- Read `content-model.md` for this component's classification
- If not classified, invoke `/modeling` for this component

#### c) Consult reference skills

Auto-discover which reference skills are relevant:

- ACF block → read `@sage-lando` references/acf-composer.md
- Blade view → read `@sage-lando` references/blade-templates.md
- Livewire → read `@acorn-livewire`
- Routes → read `@acorn-routes`
- Tailwind/CSS → read `@sage-lando` references/frontend-stack.md

#### d) Create worktree and implement

Before writing any code, create an isolated worktree for this component:

```bash
# Read branch from plan.md frontmatter
FEATURE_BRANCH=$(grep '^branch:' docs/plans/<active-plan>/plan.md | awk '{print $2}')
COMPONENT_BRANCH="${FEATURE_BRANCH}-<component-name>"

git worktree add .worktrees/<component-name> -b $COMPONENT_BRANCH $FEATURE_BRANCH
```

Example: if feature branch is `feat/onepage-blocks-2026-03-23` and component is `hero`:

```bash
git worktree add .worktrees/hero -b feat/onepage-blocks-2026-03-23-hero feat/onepage-blocks-2026-03-23
```

**Implement inside the worktree.** The worktree mirrors the full repo root.
Theme files are at `.worktrees/<component>/content/themes/<theme>/`.
Example: `.worktrees/hero/content/themes/leolabs/resources/views/blocks/hero.blade.php`

**ZERO ARBITRARY TAILWIND VALUES.**
Every colour, font, spacing value must be a token declared in `@theme`.

```blade
{{-- ✅ Correct — use token names --}}
<section class="bg-bg text-text py-24">

{{-- ❌ Forbidden — arbitrary values are a Critical issue --}}
<section class="bg-[#131313] text-[#e5e2e1] py-[96px]">
```

**For ACF blocks:** After creating the PHP controller + Blade view, invoke `/sage-block-architecting` for this block before building. The block CSS contract (scoped `.b-{slug}` CSS, enqueue guard, `$styles`, block README) is that skill's responsibility — do not implement CSS or the enqueue pattern manually.

#### e) Build and verify

After implementing:

1. `lando flush` — clears Acorn/Blade/OPcache (required after PHP changes)
2. `lando theme-build` — compiles Tailwind + JS
   - If exit non-zero: **stop, report build failure. Do NOT proceed to verification.**
3. Dispatch `visual-verifier` agent with inputs from `assets/section-<name>-spec.md`:
   - `url`: read from spec `Verification Inputs` block
   - `selector`: read from spec `Verification Inputs` block
   - `spec`: `docs/plans/<plan>/assets/section-<name>-spec.md`
   - `ref`: `docs/plans/<plan>/assets/section-<name>-ref.png`
4. On `MATCH`:
   ```bash
   git checkout <feature-branch>
   git merge <component-branch>
   git worktree remove .worktrees/<component-name>
   git branch -d <component-branch>
   ```
5. On `DRIFT` or `FAIL_ARBITRARY_VALUES`: fix in worktree → re-run `lando theme-build` → re-dispatch `visual-verifier` → merge on MATCH
6. After merge: `git push` to sync the feature branch with the remote

#### f) Strategy gate

- **Interactive strategy**: pause for user approval before next component
- **Autonomous strategy**: proceed to next component if verification passed
- **Mixed strategy**: pause only for complex components

### 3) Parallel delegation

When components are independent (no shared CPTs or services):

- Use `dispatching-parallel-agents` or `subagent-driven-development` base skills
- Each subagent gets: sub-plan path, asset path, content model excerpt
- Review subagent output between batches

### 4) Completion

After all components:

1. Run `lando flush` to clear all caches
2. Run `lando theme-build` for production build
3. **Commit gate:** `git add -A && git commit -m "feat(blocks): <feature-name> — all components verified" && git push` — required before declaring the build phase complete
4. Suggest `/reviewing` for convention audit
5. Suggest `finishing-a-development-branch` for merge/PR

## Key Principles

- **Always re-read assets from disk** — context compression will lose design reference
- **Verify after each component** — catch drift early, not at the end
- **Consult reference skills** — don't guess patterns, read the reference
- **Respect the strategy** — autonomous for simple, interactive for complex
- **Hooks handle cache** — post-edit hook auto-runs `lando flush` and `lando theme-build`
- **Worktree per component** — every component is implemented in an isolated branch+worktree, merged to the feature branch only after visual verification passes
- **Zero arbitrary Tailwind values** — all colours, fonts, and spacing must be `@theme` tokens; arbitrary `[#hex]` classes are a Critical issue caught by visual-verifier
