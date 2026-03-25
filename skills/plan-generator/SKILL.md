---
name: superpowers-sage:plan-generator
description: Generates executable implementation plans from approved architecture specs with dependency graphs, per-component subplans, execution strategy, and Sage-specific skill routing.
user-invocable: true
argument-hint: "[approved architecture spec path or feature topic]"
---

# Plan Generator

Generate implementation plans from approved architecture specs.

**Announce at start:** "I'm using plan-generator to transform the approved architecture into an executable implementation plan."

## Input

$ARGUMENTS

## HARD GATES

- Do not generate a plan without an approved architecture spec.
- Do not implement code in this skill.
- Do not mark the plan complete if dependencies are ambiguous.

## Procedure

### 1) Resolve and validate spec input

Accept one of:

- Direct spec path from arguments
- Most recent approved file in `docs/superpowers/specs/`

Reject if spec approval is missing.

### 2) Parse architecture into implementation units

Extract:

- Components and responsibilities
- Data model decisions
- Integration points
- Quality constraints
- Visual approval artifacts (if present): session path, event summary, section-level approvals

Translate each into concrete implementation units.

### 3) Build dependency graph

Classify every unit:

- `parallel`: independent work
- `sequential`: depends on prior unit output
- `gated`: requires user/reviewer checkpoint

Document graph in the plan.

### 4) Assign execution strategy and skill routing

For each unit, define:

- Strategy: autonomous, interactive, or mixed
- Suggested skill(s): `superpowers-sage:building`, `superpowers-sage:modeling`, `superpowers-sage:designing`, `superpowers-sage:verifying`, and reference skills (`acorn-*`, `wp-*`) as needed
- Acceptance criteria
- Visual checkpoint requirement (must verify against approved visual section before marking done)

### 5) Generate plan directory and files

Create:

- `docs/plans/YYYY-MM-DD-<topic>/plan.md`
- `docs/plans/YYYY-MM-DD-<topic>/architecture.md` (reference pointer to approved spec)
- `docs/plans/YYYY-MM-DD-<topic>/content-model.md` (if model decisions exist)
- `docs/plans/YYYY-MM-DD-<topic>/components/NN-<name>/plan.md` for each component
- `docs/plans/YYYY-MM-DD-<topic>/components/NN-<name>/design-guide.md` for each component
- `docs/plans/YYYY-MM-DD-<topic>/components/NN-<name>/visual-checks.md` for each component
- `docs/plans/YYYY-MM-DD-<topic>/assets/` references (tokens, screenshots, links)

When visual artifacts exist, also create:

- `docs/plans/YYYY-MM-DD-<topic>/assets/visual-approval.md` with extracted decision summary from `approval-summary.md` and `events.jsonl`

Use these operational templates.

#### `plan.md`

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
    visual_checkpoint: <required|optional>
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
- [ ] Visual checkpoints completed where required
- [ ] Final reviewer checkpoint completed
```

#### `components/NN-<name>/plan.md`

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
- [ ] Visual checkpoint executed (if required)

## Owner Skill Routing

- Primary: <superpowers-sage:building|...>
- Supporting: <acorn-_|wp-_>
```

#### `components/NN-<name>/design-guide.md`

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

#### `components/NN-<name>/visual-checks.md`

```markdown
# <Component Name> Visual Checks

## Source of Truth

- Visual approval summary: ../../assets/visual-approval.md
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

#### `assets/visual-approval.md`

```markdown
# Visual Approval Summary

## Session

- Session path: <docs/superpowers/visual-companion/...>
- Source files: approval-summary.md, events.jsonl

## Decisions

- Approach decision: <A/B/...>
- Overview gate: <approved/rejected>
- Components/data-flow gate: <approved/rejected>
- Quality strategy gate: <approved/rejected>

## Constraints for Implementation

- <constraint>
- <constraint>

## Notes

- If browser mode was declined, record explicit terminal opt-out here.
```

### 6) Validate plan consistency

Check:

- Every component appears exactly once
- Every dependency has a source node
- No component is both parallel and sequential in the same stage
- Strategy aligns with risk/complexity
- Every interactive component has a visual checkpoint owner (`superpowers-sage:verifying` or `superpowers-sage:visual-verifier`)

### 7) Final handoff for execution

Present concise execution summary:

- Planned phases and order
- Parallel batches
- Interactive checkpoints
- Visual checkpoints and corresponding artifacts
- Suggested next command

Then offer:
`superpowers-sage:building`

Use this handoff format:

```markdown
Execution plan ready at: docs/plans/YYYY-MM-DD-<topic>/

Next recommended path:

1. Run superpowers-sage:building against the generated plan directory
2. Execute parallel batch A components first
3. Run visual checkpoints before moving to dependent batch
4. Run final review and verification before completion
```

## Plan Frontmatter Template

Use the exact frontmatter defined in the `plan.md` operational template above.

## Verification

Before completion, confirm all items:

- Approved source spec exists and is referenced in `source-spec`
- Plan directory exists with required files
- Dependency graph has no unresolved nodes
- Each component has acceptance criteria in its sub-plan
- If visual artifacts exist in source spec, `assets/visual-approval.md` and per-component `visual-checks.md` are generated

## Failure modes

- Spec missing or unapproved: block and request architecture approval.
- Dependency cycle detected: surface cycle and propose reordering.
- Incomplete component definitions: return to architecture spec for clarification.
- Too many cross-component dependencies: split into phased plan and mark phase gates.
- Missing visual artifacts despite visual-required components: mark visual checks as blocked and request refreshed architecture approval package.
