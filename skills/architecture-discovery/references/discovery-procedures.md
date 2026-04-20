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

## Phase 2 — Clarifying Questions

Gather requirements progressively (one at a time):

- User-facing behavior
- Editor experience (ACF/Gutenberg)
- Dynamic data and integrations
- Non-functional constraints (performance, security, timeline)

## Phase 3 — Identify Components and Boundaries

List components with explicit boundaries:

- Responsibility
- Inputs/outputs
- Dependencies
- Critical risks

## Phase 4 — Parallel Discovery Probes

Dispatch independent probes in parallel and merge results:

- `superpowers-sage:content-modeler` for ACF/CPT/Options/Page modeling guidance
- `superpowers-sage:design-extractor` in PANORAMIC mode for design token baseline
- `superpowers-sage:sage-reviewer` for existing conventions and architectural constraints

At convergence, synthesize all findings before moving on.

## Phase 5 — Propose Architecture Approaches

Propose 2-3 approaches. For each include:

- High-level structure
- Trade-offs
- Integration impact
- Recommendation with rationale

Ask user to choose or request refinements.

### Phase 5b — AD-2 Preset: Zero-Migration Port from Legacy Schema

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

## Phase 6 — Build Decision Graph and Execution Strategy

Produce execution strategy by dependency class:

- Independent tasks (parallel candidates)
- Shared-service tasks (sequential)
- High-risk tasks (interactive checkpoints)

## Phase 7 — Section: Overview

Present goal, chosen approach, system boundaries.

Ask: "This overview looks correct so far?"

## Phase 8 — Section: Components and Data Flow

Include:

- Component contracts
- Data flow and state ownership
- Hook/provider integration points

Ask approval before proceeding.

## Phase 9 — Section: Quality Strategy

Include:

- Error handling and fallback states
- Testing strategy (unit/feature/visual)
- Performance/security constraints

Ask approval before proceeding.

## Phase 10 — Write Architecture Spec to Disk

Write `docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md`.

Commit the spec.

## Phase 11 — Spec Review Loop

Dispatch `superpowers-sage:sage-reviewer` against the written spec.

Loop up to 3 times:

- Issues found → revise spec → re-dispatch
- Approved → continue

If loop exceeds 3 attempts, escalate to user decision.

## Phase 12 — User Approval Gate

Ask user to review the written spec path.

- If changes requested: revise and repeat step 11.
- If approved: continue to handoff.
