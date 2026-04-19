Deep reference for architecture-discovery output contract. Loaded on demand from `skills/architecture-discovery/SKILL.md`.

# Architecture Discovery — Output Contract

The structured output format for an architecture discovery session — sections, required fields, and the contract downstream skills consume.

## Required Output Artifacts

This skill must leave:

- Approved architecture spec on disk
- Review feedback resolved or explicitly waived
- Clear handoff payload for `superpowers-sage:plan-generator`
- Visual approval artifacts or explicit visual opt-out record

## Verification Checklist

Before completion, confirm all items:

- Spec file exists at `docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md`
- Spec has user approval recorded in conversation
- At least one reviewer loop executed (or explicit user waiver)
- Handoff payload is complete and unambiguous
- If visual was enabled: `events.jsonl` and `approval-summary.md` exist and are referenced in spec
- If visual was disabled: explicit opt-out is recorded in the spec

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

## Visual Evidence

- Session path: <docs/superpowers/visual-companion/... or N/A>
- Approval summary: <path or N/A>
- Opt-out note: <if applicable>
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
- visual_session_path: <docs/superpowers/visual-companion/... or none>
- visual_approval_summary: <approval-summary.md path or explicit opt-out>
```

## Transition Message Format

```markdown
Architecture discovery complete.

Ready to generate executable plan from:

- Spec: docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md
- Visual evidence: <path or opt-out>

Invoking superpowers-sage:plan-generator with validated handoff payload.
```

## Visual Companion Session Directory

When visual mode is active, maintain:

- `docs/superpowers/visual-companion/YYYY-MM-DD-<topic>-<session-id>/`
  - `session.json` (status, mode, tool availability, spec path linkage)
  - `layout-v1.html`, `layout-v2.html`, ... (approval screens)
  - `events.jsonl` (one JSON event per line)
  - `approval-summary.md` (human-readable decisions)

### `session.json` template

```json
{
  "status": "active",
  "topic": "<topic>",
  "session_id": "<session-id>",
  "mode": "visual",
  "created_at": "YYYY-MM-DDTHH:MM:SSZ",
  "spec_path": "docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md",
  "tools": {
    "paper": false,
    "figma": false,
    "playwright": false
  }
}
```

### `approval-summary.md` template

```markdown
# Architecture Visual Approval Summary

## Session

- Session path: <docs/superpowers/visual-companion/...>
- Source files: events.jsonl

## Decisions

- Approach decision: <A/B/...>
- Overview gate: <approved/rejected>
- Components/data-flow gate: <approved/rejected>
- Quality strategy gate: <approved/rejected>

## Notes

- <assumptions, constraints, user feedback>
```

### Event format (JSONL)

```json
{"type":"choice","section":"approach","choice":"A","source":"browser","timestamp":"2026-03-24T21:10:00Z"}
{"type":"choice","section":"components","choice":"approved","source":"terminal","timestamp":"2026-03-24T21:16:00Z"}
```
