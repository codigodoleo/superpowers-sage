---
name: superpowers-sage:architecture-discovery
description: >
  Architecture discovery for Sage/Acorn projects — map existing codebase,
  discover post types, routes, ACF field groups, Livewire components,
  Service Providers, identify architectural gaps, architecture decision records,
  ADR, component boundary map, data flow diagram, risk register,
  implementation sequencing, discovery session, understanding unknown codebases,
  use before architecting or building new features, output contract,
  discover-abilities
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

## Procedure (summary)

Full step-by-step procedures for each phase are in `references/discovery-procedures.md`.

1. **Branch & scope** — ensure feature branch exists, normalize scope in one sentence.
2. **Explore context** — read `config/poet.php`, existing blocks, providers, active plans.
3. **Visual companion** — offer browser-based visual approval mode; record accept/decline.
4. **Clarifying questions** — gather requirements one at a time (UX, editor, integrations, constraints).
5. **Identify components** — list with responsibility, inputs/outputs, dependencies, risks.
6. **Parallel probes** — dispatch `content-modeler`, `design-extractor` (PANORAMIC), `sage-reviewer` in parallel; synthesize.
7. **Propose approaches** — 2-3 options with trade-offs; ask user to choose. Apply AD-2 preset if porting legacy schemas.
8. **Decision graph** — classify tasks as parallel/sequential/gated.
9. **Section: Overview** — present + ask approval. Capture visual event if session active.
10. **Section: Components & data flow** — present + ask approval.
11. **Section: Quality strategy** — present + ask approval. Write `approval-summary.md`.
12. **Write spec** — `docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md`. Commit.
13. **Spec review loop** — dispatch `sage-reviewer` up to 3 times; escalate on persistent failure.
14. **User approval gate** — revise until approved.
15. **Handoff** — prepare handoff payload; invoke `superpowers-sage:plan-generator`.

> For detailed procedure steps, visual companion commands, and the AD-2 preset block,
> read `skills/architecture-discovery/references/discovery-procedures.md`.

## Output Contract

Full output artifact specifications are in `references/output-contract.md`.

Required outputs:

- Approved architecture spec at `docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md`
- Review feedback resolved or explicitly waived
- Complete handoff payload for `superpowers-sage:plan-generator`
- Visual approval artifacts or explicit visual opt-out record

> For spec template, handoff payload format, and visual companion artifact schemas,
> read `skills/architecture-discovery/references/output-contract.md`.

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
