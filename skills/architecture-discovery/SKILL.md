---
name: superpowers-sage:architecture-discovery
description: Deep architecture discovery workflow for Sage projects with hard gates, section-by-section approvals, parallel discovery probes, and spec review loops before any implementation plan is generated.
user-invocable: true
argument-hint: "[feature or scope description]"
---

# Architecture Discovery

Design-first architecture workflow for WordPress + Sage + Acorn + Lando projects.

**Announce at start:** "I'm using architecture-discovery to produce an approved architecture spec before any implementation plan."

## Input

$ARGUMENTS

## HARD GATES

- Never write implementation code in this skill.
- Never invoke `superpowers-sage:building` before architecture approval and plan generation.
- Never skip section-by-section approval.
- Never claim visual alignment without an explicit visual approval artifact or an explicit user opt-out.

## Visual Companion Artifacts

When the user accepts visual companion, maintain a session directory:

- `docs/superpowers/visual-companion/YYYY-MM-DD-<topic>-<session-id>/`
  - `session.json` (status, mode, tool availability, spec path linkage)
  - `layout-v1.html`, `layout-v2.html`, ... (approval screens)
  - `events.jsonl` (one JSON event per line)
  - `approval-summary.md` (human-readable decisions)

Event format (JSONL):

```json
{"type":"choice","section":"approach","choice":"A","source":"browser","timestamp":"2026-03-24T21:10:00Z"}
{"type":"choice","section":"components","choice":"approved","source":"terminal","timestamp":"2026-03-24T21:16:00Z"}
```

Runtime commands:

```bash
# Start visual engine
bash scripts/visual-companion/start-server.sh --project-dir "$PWD" --topic "<topic>"

# Stop visual engine
bash scripts/visual-companion/stop-server.sh --session-dir "docs/superpowers/visual-companion/YYYY-MM-DD-<topic>-<session-id>"

# Optional smoke test for local setup
bash scripts/visual-companion/smoke-test.sh
```

Runtime API endpoints:

```text
GET  /health  -> engine status + latest layout
POST /event   -> append decision event to events.jsonl
POST /layout  -> write next layout file (layout-vN.html)
GET  /events  -> raw JSONL events stream
```

Use these operational templates when visual mode is active.

#### `session.json`

```json
{
  "status": "active",
  "topic": "<topic>",
  "session_id": "<session-id>",
  "mode": "visual",
  "created_at": "YYYY-MM-DDTHH:MM:SSZ",
  "spec_path": "docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md",
  "tools": {
    "figma": false,
    "playwright": false
  }
}
```

#### `approval-summary.md`

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

## Procedure

### 0) Branch and scope initialization

1. Check current branch.
2. If on `main` or `master`, propose `feat/<topic>-YYYY-MM-DD` and create it after user approval.
3. Normalize scope statement in one sentence and confirm with user.

### 1) Explore project context

Read relevant project context before asking deep questions:

- Existing blocks/components and providers
- `config/poet.php`, routes, and active content models
- Existing plans under `docs/plans/`

### 2) Offer visual companion when useful

If visual clarification is likely useful (layout-heavy or option comparison):

- Offer browser-based visual companion in a standalone message.
- Continue only after explicit accept/decline.

If accepted:

- Initialize the session artifact directory under `docs/superpowers/visual-companion/`.
- Write `session.json` with `status: active`.
- Record the consent event in `events.jsonl`.
- Start runtime with `scripts/visual-companion/start-server.sh` and store returned URL.

If declined:

- Record explicit opt-out in `events.jsonl` and continue in terminal-only mode.

### 3) Clarifying questions (one at a time)

Gather requirements progressively:

- User-facing behavior
- Editor experience (ACF/Gutenberg)
- Dynamic data and integrations
- Non-functional constraints (performance, security, timeline)

### 4) Identify components and boundaries

List components with explicit boundaries:

- Responsibility
- Inputs/outputs
- Dependencies
- Critical risks

### 5) Run parallel discovery probes

Dispatch independent probes in parallel and merge results:

- `superpowers-sage:content-modeler` for ACF/CPT/Options/Page modeling guidance
- `superpowers-sage:design-extractor` in PANORAMIC mode for design token baseline
- `superpowers-sage:sage-reviewer` for existing conventions and architectural constraints

At convergence, synthesize all findings before moving on.

### 6) Propose 2-3 architecture approaches

For each approach include:

- High-level structure
- Trade-offs
- Integration impact
- Recommendation with rationale

Ask user to choose or request refinements.

### 7) Build decision graph and execution strategy

Produce execution strategy by dependency class:

- Independent tasks (parallel candidates)
- Shared-service tasks (sequential)
- High-risk tasks (interactive checkpoints)

If visual session is active, prepare one comparison frame (`layout-v*.html`) for approach selection and record the decision in `events.jsonl`.

### 8) Present architecture section: Overview

Present goal, chosen approach, system boundaries.

Ask: "This overview looks correct so far?"

If visual session is active:

- Show the overview comparison in browser (or Figma frame reference).
- Capture response as event (`section: overview`) and mirror the decision in terminal.

### 9) Present architecture section: Components and data flow

Include:

- Component contracts
- Data flow and state ownership
- Hook/provider integration points

Ask approval before proceeding.

If visual session is active:

- Publish a section-specific frame (`layout-v*.html`) for components/data-flow.
- Capture approval as event (`section: components-data-flow`).

### 10) Present architecture section: Quality strategy

Include:

- Error handling and fallback states
- Testing strategy (unit/feature/visual)
- Performance/security constraints

Ask approval before proceeding.

If visual session is active:

- Publish quality and testing map frame (`layout-v*.html`) for final visual gate.
- Capture approval as event (`section: quality-strategy`).

At end of step, write `approval-summary.md` consolidating all section approvals.

After final gate, stop runtime with `scripts/visual-companion/stop-server.sh`.

### 11) Write architecture spec to disk

Write:

- `docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md`

Include:

- Requirements
- Chosen approach + rejected alternatives
- Component boundaries
- Data flow
- Risk register
- Validation strategy
- Suggested implementation sequencing

Also include, when available:

- Visual companion artifact path
- Event summary (approach choice + section approvals)
- Explicit visual opt-out note when user declined browser mode

Commit the spec.

Use this operational template:

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

### 12) Spec review loop

Dispatch `superpowers-sage:sage-reviewer` against the written spec.

Loop up to 3 times:

- Issues found -> revise spec -> re-dispatch
- Approved -> continue

If loop exceeds 3 attempts, escalate to user decision.

### 13) User approval gate

Ask user to review the written spec path.

- If changes requested: revise and repeat step 12.
- If approved: continue.

### 14) Handoff contract for planning

Prepare explicit handoff payload for `superpowers-sage:plan-generator`:

- Spec path
- Chosen strategy (autonomous/interactive/mixed)
- Parallelism constraints
- Design references and extracted tokens
- Visual companion session path (if used)
- Visual event summary (`approval-summary.md`)

Use this handoff payload format:

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

### 15) Transition to plan generation

Invoke `superpowers-sage:plan-generator` with the handoff payload.

Use this transition message format:

```markdown
Architecture discovery complete.

Ready to generate executable plan from:

- Spec: docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md
- Visual evidence: <path or opt-out>

Invoking superpowers-sage:plan-generator with validated handoff payload.
```

## Output Contract

This skill must leave:

- Approved architecture spec on disk
- Review feedback resolved or explicitly waived
- Clear handoff payload for `superpowers-sage:plan-generator`
- Visual approval artifacts or explicit visual opt-out record

## Verification

Before completion, confirm all items:

- Spec file exists at `docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md`
- Spec has user approval recorded in conversation
- At least one reviewer loop executed (or explicit user waiver)
- Handoff payload is complete and unambiguous
- If visual was enabled: `events.jsonl` and `approval-summary.md` exist and are referenced in spec
- If visual was disabled: explicit opt-out is recorded in the spec

## Failure modes

- No design reference available: proceed text-first, mark visual assumptions explicitly.
- Scope too broad: decompose into sub-projects and complete first sub-scope only.
- Repeated reviewer failures: escalate after 3 attempts.
- Missing content model signal: re-run `superpowers-sage:content-modeler` before finalizing spec.
- Visual companion session unavailable or broken: fall back to terminal approvals, record fallback reason in spec, and continue.
- Conflicting visual vs terminal approvals: stop and ask user for authoritative decision before proceeding.
