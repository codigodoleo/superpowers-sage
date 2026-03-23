---
name: superpowers-sage:verifying
description: Visual comparison of implemented sections against design reference; captures screenshots via Chrome/Playwright MCP, compares with plan assets or design tool screens, reports match/drift/missing. Standalone or integrated in /building flow.
user-invocable: true
argument-hint: "[section name or plan path]"
---

# Verifying — Visual Comparison with Design Reference

Compare implemented sections against design reference using visual analysis.

## Inputs

$ARGUMENTS

## Procedure

### 0) Determine reference source

Priority order:
1. **Plan assets**: `docs/plans/<active-plan>/assets/section-*.png` — read with Read tool (Claude reads images natively)
2. **Design MCP**: Stitch `get_screen` or Figma `get_frame` — fetch current design
3. **Textual description**: `docs/plans/<active-plan>/assets/section-*.md` — structured text description
4. **Last resort**: ask user to provide screenshot or describe expected appearance

### 1) Capture implementation

Try in order:
1. **Playwright MCP**: `mcp__playwright__screenshot` — headless browser capture
2. **Chrome MCP**: `mcp__Claude_in_Chrome__computer` action=screenshot — if Chrome MCP available
3. **Fallback**: ask user to provide screenshot of the implemented section

### 2) Compare visually

Read both reference and implementation images. Compare on these axes:

| Axis | Check |
|---|---|
| **Layout** | Grid structure, column count, alignment, flex direction |
| **Content** | Headlines match? Body text match? All items present? |
| **Colors** | Background, text, accent colors match? |
| **Typography** | Font size, weight, family approximately correct? |
| **Spacing** | Padding, margins, gaps reasonable? |
| **Icons** | Correct icon set? Right icon names? |
| **Images** | Placeholder or actual? Right aspect ratio? |
| **Responsive** | Does the layout adapt appropriately? |

### 3) Report findings

Output a structured report:

```markdown
## Verification: {Section Name}

**Status:** MATCH | DRIFT | MISSING

### Comparison
| Axis | Status | Notes |
|---|---|---|
| Layout | {pass/drift} | {details} |
| Content | {pass/drift} | {details} |
| Colors | {pass/drift} | {details} |
| Typography | {pass/drift} | {details} |
| Spacing | {pass/drift} | {details} |

### Issues Found
- {specific issue with fix suggestion}

### Recommendation
{proceed / fix before continuing}
```

### 4) Act on findings

- **MATCH**: Mark component as verified, proceed
- **DRIFT**: List specific fixes needed, implement if in `/building` flow
- **MISSING**: Elements from design not implemented — flag for implementation

## Key Principles
- **Read images from disk** — always use Read tool for plan assets
- **Be specific** — "the grid should be 3 columns, got 2" not "layout is wrong"
- **Compare content verbatim** — headlines and body text must match exactly
- **Use base skill**: `verification-before-completion` for completion gate
