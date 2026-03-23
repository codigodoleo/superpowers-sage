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

If no plan exists, suggest running `/architecting` first.

### 1) Set up prerequisites

Based on content model:
1. If CPTs needed → configure `config/poet.php`
2. If new packages needed → `lando theme-composer require <package>`
3. If Options Pages needed → create ACF Options class
4. Run `lando flush` after PHP changes

### 2) Implement components (per sub-plan)

For each component in order:

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

#### d) Implement
1. PHP Block class (ACF Composer) with `fields()` and `with()`
2. Blade view with Tailwind CSS
3. Any supporting services or providers

#### e) Verify
Invoke `/verifying` for this component:
- Compare implementation screenshot with design reference
- Report MATCH / DRIFT / MISSING

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
3. Suggest `/reviewing` for convention audit
4. Suggest `finishing-a-development-branch` for merge/PR

## Key Principles
- **Always re-read assets from disk** — context compression will lose design reference
- **Verify after each component** — catch drift early, not at the end
- **Consult reference skills** — don't guess patterns, read the reference
- **Respect the strategy** — autonomous for simple, interactive for complex
- **Hooks handle cache** — post-edit hook auto-runs `lando flush` and `lando theme-build`
