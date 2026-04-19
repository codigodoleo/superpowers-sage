Deep reference for architecture-discovery procedures. Loaded on demand from `skills/architecture-discovery/SKILL.md`.

# Architecture Discovery — Discovery Procedures

Step-by-step discovery procedures for each output section — what to read, what to ask, and what to record.

## Phase 0 — Branch and Scope Initialization

1. Check current branch.
2. If on `main` or `master`, propose `feat/<topic>-YYYY-MM-DD` and create it after user approval.
3. Normalize scope statement in one sentence and confirm with user.

## Phase 1 — Explore Project Context

Read relevant project context before asking deep questions:

- Existing blocks/components and providers
- `config/poet.php`, routes, and active content models
- Existing plans under `docs/plans/`

## Phase 2 — Visual Companion Offer

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

Runtime commands:

```bash
# Start visual engine
bash scripts/visual-companion/start-server.sh --project-dir "$PWD" --topic "<topic>"

# Stop visual engine
bash scripts/visual-companion/stop-server.sh --session-dir "docs/superpowers/visual-companion/YYYY-MM-DD-<topic>-<session-id>"
```

Runtime API endpoints:

```text
GET  /health  -> engine status + latest layout
POST /event   -> append decision event to events.jsonl
POST /layout  -> write next layout file (layout-vN.html)
GET  /events  -> raw JSONL events stream
```

## Phase 3 — Clarifying Questions

Gather requirements progressively (one at a time):

- User-facing behavior
- Editor experience (ACF/Gutenberg)
- Dynamic data and integrations
- Non-functional constraints (performance, security, timeline)

## Phase 4 — Identify Components and Boundaries

List components with explicit boundaries:

- Responsibility
- Inputs/outputs
- Dependencies
- Critical risks

## Phase 5 — Parallel Discovery Probes

Dispatch independent probes in parallel and merge results:

- `superpowers-sage:content-modeler` for ACF/CPT/Options/Page modeling guidance
- `superpowers-sage:design-extractor` in PANORAMIC mode for design token baseline
- `superpowers-sage:sage-reviewer` for existing conventions and architectural constraints

At convergence, synthesize all findings before moving on.

## Phase 6 — Propose Architecture Approaches

Propose 2-3 approaches. For each include:

- High-level structure
- Trade-offs
- Integration impact
- Recommendation with rationale

Ask user to choose or request refinements.

### Phase 6b — AD-2 Preset: Zero-Migration Port from Legacy Schema

When the scope involves porting ACF field groups, CPTs, or blocks from a legacy
codebase AND the existing `post_content` or `wp_postmeta` data must remain readable
without a data migration, use the **AD-2 byte-for-byte preset**.

**Emit this block in the architecture spec under "Chosen Approach":**

```markdown
### AD-2 — Byte-for-byte port from legacy schema

All ACF Builder chains in ported classes MUST match the legacy source byte-for-byte
(except namespace/import lines). Rationale:

- ACF generates `field_{group}_{name}` keys deterministically from the Builder chain
- Any deviation (reordering `->addX()` calls, renaming fields, splitting Builders)
  produces new field keys
- Existing `post_content` and `wp_postmeta` rows reference old keys; mismatched
  keys = fields rehydrate as null = data appears lost

**Enforcement:** plan-generator emits an AD-2 gate per component (blocking pre-commit
diff against the legacy source). Building runs the diff BEFORE writing each class.

**Expected legacy sources:** <list sources here, e.g. `bkp_main:app/Fields/*.php`>

**Exceptions:** <namespace changes, import aliasing — all other divergence is a
Critical violation>
```

**When to use:** scope mentions porting from legacy AND preserving data is required.

**When NOT to use:** greenfield design with no legacy schema, OR explicit data migration planned.

## Phase 7 — Build Decision Graph and Execution Strategy

Produce execution strategy by dependency class:

- Independent tasks (parallel candidates)
- Shared-service tasks (sequential)
- High-risk tasks (interactive checkpoints)

If visual session is active, prepare one comparison frame (`layout-v*.html`) for
approach selection and record the decision in `events.jsonl`.

## Phase 8 — Section: Overview

Present goal, chosen approach, system boundaries.

Ask: "This overview looks correct so far?"

If visual session is active: show the overview comparison in browser (or Figma frame
reference). Capture response as event (`section: overview`) and mirror in terminal.

## Phase 9 — Section: Components and Data Flow

Include:

- Component contracts
- Data flow and state ownership
- Hook/provider integration points

Ask approval before proceeding.

If visual session is active: publish a section-specific frame for components/data-flow.
Capture approval as event (`section: components-data-flow`).

## Phase 10 — Section: Quality Strategy

Include:

- Error handling and fallback states
- Testing strategy (unit/feature/visual)
- Performance/security constraints

Ask approval before proceeding.

If visual session is active: publish quality and testing map frame for final visual gate.
Capture approval as event (`section: quality-strategy`).

At end of step, write `approval-summary.md` consolidating all section approvals.
After final gate, stop runtime with `scripts/visual-companion/stop-server.sh`.

## Phase 11 — Write Architecture Spec to Disk

Write `docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md`.

Also include, when available:

- Visual companion artifact path
- Event summary (approach choice + section approvals)
- Explicit visual opt-out note when user declined browser mode

Commit the spec.

## Phase 12 — Spec Review Loop

Dispatch `superpowers-sage:sage-reviewer` against the written spec.

Loop up to 3 times:

- Issues found → revise spec → re-dispatch
- Approved → continue

If loop exceeds 3 attempts, escalate to user decision.

## Phase 13 — User Approval Gate

Ask user to review the written spec path.

- If changes requested: revise and repeat step 12.
- If approved: continue to handoff.
