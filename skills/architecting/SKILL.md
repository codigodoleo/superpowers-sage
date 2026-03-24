---
name: superpowers-sage:architecting
description: Architecture decision and brainstorming for Sage projects; wraps superpowers brainstorming with Sage intelligence, consults design tools, invokes content modeling, decides execution strategy per component, generates plan directories with assets. The brain of the workflow.
user-invocable: true
argument-hint: "[feature or scope description]"
---

# Architecting — Brainstorming + Architecture Decisions

The brain of the workflow. Wraps base `brainstorming` skill with Sage intelligence: design tool integration, content modeling, and plan directory generation.

**Announce at start:** "I'm using the architecting skill to plan this feature with design reference and content modeling."

## Feature request

$ARGUMENTS

## HARD GATE

**Do NOT implement anything until the design is approved.** This skill produces plans and decisions, not code.

## Procedure

### 0) Establish feature branch

Before any design capture or analysis:

1. Run `git branch --show-current` to check current branch
2. If already on a feature branch (not main/master):
   - Confirm with user: "Currently on `{branch}`. Continue here or start a new feature branch?"
3. If on main/master:
   - Propose branch name: `feat/<topic>-YYYY-MM-DD` (e.g., `feat/onepage-blocks-2026-03-23`)
   - Ask: "I'll create branch `feat/<topic>-YYYY-MM-DD` from latest main. Confirm?"
   - On confirmation:
     ```bash
     git checkout main && git pull && git checkout -b feat/<topic>-YYYY-MM-DD
     ```
4. Record in `plan.md` frontmatter after the plan is created:
   ```yaml
   branch: feat/<topic>-YYYY-MM-DD
   ```

### 1) Invoke `/designing` to capture design reference

Before any analysis:
1. Check for active design tools (Stitch/Figma MCP)
2. If available, invoke `/designing` to extract layout and content per section
3. Save extracted data to `docs/plans/YYYY-MM-DD-<topic>/assets/`
4. If no design tools, ask user for screenshots or skip to architecture

After capturing design reference, dispatch the `design-extractor` agent in **PANORAMIC mode**:
- Provide: the plan assets directory path
- Agent produces: `assets/design-tokens.md` and `assets/overview-ref.png`
- Use `design-tokens.md` to define the `@theme` block in `app.css` before any component work begins

### 2) Explore project context

Read the project state:
- Theme structure, installed packages, existing blocks
- `config/poet.php` for existing CPTs
- Existing service providers and routes
- Active plans (check `docs/plans/`)

### 3) Ask clarifying questions (one at a time)

Understand the full scope:
- What is being built? (page, feature, block set, full site)
- What is the user-facing behavior?
- Does it need Gutenberg editor integration?
- Are there forms or interactivity?
- What content will editors manage?

### 4) Identify components

Break the feature into discrete components:
- List each section/block/page
- For each, note: name, complexity, dependencies

### 5) Invoke `/modeling` for content analysis

For each component with content:
1. Run the content classification checklist
2. Determine static vs dynamic content
3. Generate Poet config for any CPTs needed
4. Document in `content-model.md`

### 6) Decide execution strategy per component

For each component, assess complexity:

| Indicator | Strategy |
|---|---|
| Simple ACF block + Blade view, no dynamic content | Autonomous |
| Needs CPT setup, custom query, or Livewire | Interactive (user approval per step) |
| Independent of other components | Can run in parallel |
| Depends on shared CPT or service | Must run sequentially |

### 7) Generate plan directory

Create the plan structure:

```bash
mkdir -p docs/plans/YYYY-MM-DD-<topic>/{assets,components,logs}
```

Write:
- `plan.md` — frontmatter with title, date, status: in-progress, strategy, design-tool, branch, components list
- `architecture.md` — ADR with context, decision, components, data flow, justification
- `content-model.md` — output from modeling analysis
- `components/NN-name.md` — sub-plan per component (for complex projects)

The `plan.md` frontmatter template:
```yaml
title: <feature title>
date: YYYY-MM-DD
status: in-progress
strategy: <autonomous|interactive|mixed>
design-tool: <stitch|figma|none>
branch: feat/<topic>-YYYY-MM-DD
components:
  - name: <ComponentName>
    strategy: <autonomous|interactive>
```

### 8) Present design for approval

Present the architecture in sections:
1. Overview (goal + approach)
2. Components list with strategies
3. Content model summary
4. Execution order and parallelism plan

Ask after each section if it looks right.

### 9) Transition to implementation

After approval, offer:

**"Architecture complete. Two execution options:**

**1. Subagent-Driven (this session)** — I dispatch fresh subagent per task, review between tasks

**2. Direct Building** — Invoke `/building` to implement from the plan

**Which approach?"**

If Subagent-Driven: invoke `subagent-driven-development` base skill
If Direct: invoke `/building` with the plan path

## Key Principles
- **Design first** — always capture visual reference before analyzing
- **Model content** — classify every content element before implementing
- **Plan directories** — persist everything to disk (survives context compression)
- **Strategy per component** — not one-size-fits-all
- **Base superpowers** — this skill orchestrates `brainstorming` + `writing-plans`
