Deep reference for plan-generator plan format. Loaded on demand from `skills/plan-generator/SKILL.md`.

# Plan Generator — Plan File Format

Complete plan file format specification — frontmatter fields, phase/batch structure, task anatomy, and the contract downstream executing skills consume.

## Plan Directory Structure

```
docs/plans/YYYY-MM-DD-<topic>/
  plan.md                              # Root plan with frontmatter + phases
  architecture.md                      # Reference pointer to approved spec
  content-model.md                     # If model decisions exist
  components/
    NN-<name>/
      plan.md                          # Per-component sub-plan
      design-guide.md                  # Design tokens + layout contract
      visual-checks.md                 # Visual verification checklist
  assets/
    section-<name>.png                 # Design reference screenshots
    section-<name>-spec.md             # Structured section spec
```

## `plan.md` — Frontmatter Template

```markdown
---
title: <feature title>
date: YYYY-MM-DD
status: in-progress
strategy: <autonomous|interactive|mixed>
source-spec: docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md
branch: feat/<topic>-YYYY-MM-DD
components:
  - name: <ComponentName>
    strategy: <autonomous|interactive>
    depends_on: [<ComponentName>]
---

# <Feature Title> Execution Plan

## Scope

- <one sentence scope>

## Phases

1. <phase name>
2. <phase name>

## Parallel Batches

- Batch A: <components>
- Batch B: <components>

## Global Done Criteria

- [ ] All component done criteria reached
- [ ] Final reviewer checkpoint completed
```

## `components/NN-<name>/plan.md` — Task Anatomy

```markdown
# <Component Name> Plan

## Goal

- <component outcome>

## Inputs

- Source spec section: <section>
- Design references: <file paths>

## Tasks

1. <task>
2. <task>
3. <task>

## Dependencies

- Depends on: <component ids or none>
- Blocks: <component ids or none>

## Acceptance Criteria

- [ ] Functional behavior matches architecture spec
- [ ] Data model integration validated
- [ ] Tests for component behavior pass

## Owner Skill Routing

- Primary: <superpowers-sage:building|...>
- Supporting: <acorn-*|wp-*>
```

## `components/NN-<name>/design-guide.md` — Layout Contract

```markdown
# <Component Name> Design Guide

## Tokens

- Colors: <token list>
- Typography: <token list>
- Spacing: <token list>

## Layout Contract

- Desktop: <summary>
- Tablet: <summary>
- Mobile: <summary>

## Interaction Contract

- Hover/focus/active states
- Empty/loading/error states

## Anti-Drift Notes

- Avoid arbitrary values outside approved token set
```

## `components/NN-<name>/visual-checks.md`

```markdown
# <Component Name> Visual Checks

## Source of Truth

- Source spec: ../../architecture.md

## Required Checks

- [ ] Structure match (major blocks and hierarchy)
- [ ] Spacing match (layout rhythm)
- [ ] Typography match (size/weight/line-height)
- [ ] Color/token match
- [ ] Responsive behavior match

## Execution

- Suggested verifier: superpowers-sage:visual-verifier
- Evidence path: ../../logs/<component-name>-visual-check.md

## Result

- Status: <match|drift|blocked>
- Notes: <short summary>
```

## Dependency Graph Classification

Classify every implementation unit:

- `parallel`: independent work — no shared output dependencies
- `sequential`: depends on prior unit output
- `gated`: requires user/reviewer checkpoint before proceeding

## Execution Handoff Format

```markdown
Execution plan ready at: docs/plans/YYYY-MM-DD-<topic>/

Next recommended path:

1. Run superpowers-sage:building against the generated plan directory
2. Execute parallel batch A components first
3. Run final review and verification before completion
```
