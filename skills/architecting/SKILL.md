---
name: superpowers-sage:architecting
description: Compatibility wrapper for the new two-step planning flow. Delegates to superpowers-sage:architecture-discovery first, then superpowers-sage:plan-generator after architecture approval.
user-invocable: true
argument-hint: "[feature or scope description]"
---

# Architecting (Compatibility Mode)

This skill remains available to avoid breaking existing workflows. It now orchestrates the new split flow:

1. `superpowers-sage:architecture-discovery`
2. `superpowers-sage:plan-generator`

**Announce at start:** "I'm using architecting compatibility mode and will run architecture-discovery then plan-generator."

## Input

$ARGUMENTS

## HARD GATE

Do not implement code in this skill. If implementation is requested, complete the split planning flow first.

## Procedure

### 1) Run architecture discovery

- Invoke `superpowers-sage:architecture-discovery` with the same arguments.
- Wait for explicit user approval of the written architecture spec.

### 2) Run plan generation

- Invoke `superpowers-sage:plan-generator` with the approved spec path.
- Ensure output plan includes strategy, dependencies, and per-component execution ordering.

### 3) Transition to execution

After plan generation, offer:

1. `subagent-driven-development` for parallel task execution in this session
2. `superpowers-sage:building` for direct implementation from plan files

## Verification

- Confirm both files exist before claiming completion:
  - `docs/superpowers/specs/YYYY-MM-DD-<topic>-architecture.md`
  - `docs/plans/YYYY-MM-DD-<topic>/plan.md`
- Confirm the user approved the architecture spec before invoking `superpowers-sage:plan-generator`.

## Failure modes

- If architecture approval is missing: stop and return to `superpowers-sage:architecture-discovery` review loop.
- If plan generation cannot parse the spec: ask for spec corrections and re-run `superpowers-sage:plan-generator`.
