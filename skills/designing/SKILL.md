---
name: superpowers-sage:designing
description: Design tool integration for Sage projects; detects and uses Stitch or Figma MCPs to extract layout, content, and visual references. Also works with local screenshot assets. Use when you need to consult or capture design references.
user-invocable: true
---

# Designing — Design Tool Integration

Detect and use design tools (Stitch MCP, Figma MCP, or local assets) to extract layout, content, and visual references for implementation.

## When to use
- Starting implementation of a visual design
- Need to capture design reference before building
- Comparing implementation against design
- Populating plan assets directory with screenshots

## Inputs required
- Design source: Stitch project ID, Figma file URL, or local asset path
- Optional: specific section/screen name to extract

## Procedure

### 0) Detect available design tools

Use ToolSearch to discover which MCPs are available:

1. Search for `mcp__stitch__` — if found, Stitch is available
2. Search for `mcp__figma__` — if found, Figma is available
3. Check `docs/plans/<active-plan>/assets/` for local reference images

If both Stitch and Figma are detected, ask the user which contains this project's layout.

### 1) Extract design data (per section, never full design at once)

#### Stitch workflow:
1. `mcp__stitch__list_projects` — find the project
2. `mcp__stitch__list_screens` — enumerate all screens
3. `mcp__stitch__get_screen` — extract one section at a time
4. For each section, capture: headline, body text, components, colors, layout structure

#### Figma workflow:
1. `mcp__figma__get_file` — load the file structure
2. Navigate frames to find sections
3. Extract text layers, colors, component structure per section

#### Offline workflow:
1. Read images from `docs/plans/<plan>/assets/section-*.png`
2. Claude reads images natively — describe layout, content, colors
3. If no assets exist, ask user to provide screenshots

### 2) Structure the output

For each section extracted, output:

```
### Section: {name}

**Layout:** {grid structure, column arrangement, alignment}
**Headline:** "{exact text}"
**Body:** "{exact text}"
**Components:** {cards, buttons, icons, images — with details}
**Colors:** {background, text, accent — hex values if visible}
**Typography:** {heading size, body size, weight, font family}
**Spacing:** {padding, margins, gaps — approximate}
**Icons:** {icon names/types, from which set}
```

### 3) Save to plan assets (if active plan exists)

If there's an active plan in `docs/plans/`:
- Save extracted data as structured notes in `assets/section-{name}.md`
- If screenshots are available, note their paths
- Update `plan.md` frontmatter with `design-tool: stitch|figma|offline`

## Key Principles
- **Granular extraction** — always per-section, never full design at once (prevents context overflow)
- **Exact content** — copy text verbatim, don't paraphrase headlines or body text
- **Persist to disk** — save everything to plan assets/ so it survives context compression
- **Re-read before implementing** — always re-read assets from disk, never rely on context memory
