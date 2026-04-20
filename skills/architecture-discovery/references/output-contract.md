Deep reference for architecture-discovery output contract. Loaded on demand from `skills/architecture-discovery/SKILL.md`.

# Architecture Discovery — Output Contract

The structured output format for an architecture discovery session — sections, required fields, and the contract downstream skills consume.

## Required Output Artifacts

This skill must leave:

- Approved architecture spec on disk
- Review feedback resolved or explicitly waived
- Clear handoff payload for `superpowers-sage:plan-generator`

## Verification Checklist

Before completion, confirm all items:

- Spec file exists at `docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md`
- Spec has user approval recorded in conversation
- At least one reviewer loop executed (or explicit user waiver)
- Handoff payload is complete and unambiguous

## Architecture Spec Template

Write to `docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md`:

```markdown
# <Feature Title> Architecture Spec

## Overview

- Scope: <one sentence>
- Chosen approach: <approach>

## Requirements

- <requirement>
- <requirement>

## Architecture Decisions

- Chosen option: <A/B/...>
- Rejected alternatives: <short rationale>

## Components and Boundaries

- <component>: responsibility, inputs, outputs

## Data Flow

- <request/response/event flow summary>

## Risk Register

- Risk: <risk>
- Mitigation: <mitigation>

## Validation Strategy

- Functional validation: <summary>
- Visual validation: <summary>
- Testing strategy: <summary>

## Suggested Implementation Sequencing

1. <phase>
2. <phase>
```

## Handoff Payload Format

Prepare explicit handoff for `superpowers-sage:plan-generator`:

```markdown
Handoff Payload: architecture-discovery -> plan-generator

- spec_path: docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md
- strategy: <autonomous|interactive|mixed>
- parallelism_constraints:
  - <constraint>
  - <constraint>
- design_refs:
  - <design-tokens path or URL>
  - <overview reference path>
```

## Transition Message Format

```markdown
Architecture discovery complete.

Ready to generate executable plan from:

- Spec: docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md

Invoking superpowers-sage:plan-generator with validated handoff payload.
```
