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

### 0) Playwright gate

Before any verification work, ToolSearch for `mcp__plugin_playwright_playwright__browser_take_screenshot`.

If NOT found:
```
⛔ Cannot verify without Playwright MCP.

Install: claude mcp add playwright -- npx -y @anthropic/playwright-mcp
Restart session after installing. Stop.
```

Do NOT proceed to reference source detection.

### 1) Determine reference source

Priority order:
1. **Spec file**: `docs/plans/<active-plan>/assets/section-*-spec.md` — read "Verification Inputs" block to get url, selector, and ref path
2. **Plan assets**: `docs/plans/<active-plan>/assets/section-*.png` — reference image for comparison
3. **Design MCP**: Stitch `get_screen` or Figma `get_design_context`
4. **Last resort**: ask user to provide screenshot or describe expected appearance

### 2) Capture implementation

1. Read `Verification Inputs` block from the spec file — extract `url`, `selector`, `ref`
2. Navigate Playwright to `url`: `mcp__plugin_playwright_playwright__browser_navigate`
3. Take screenshot scoped to `selector`:
   `mcp__plugin_playwright_playwright__browser_take_screenshot`
4. If `selector` fails (element not found), take full-page screenshot and note the difference

### 3) Compare visually

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

### 4) Report findings

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

### 5) Act on findings

- **MATCH**: Mark component as verified, proceed
- **DRIFT**: List specific fixes needed, implement if in `/building` flow
- **MISSING**: Elements from design not implemented — flag for implementation

## Key Principles
- **Read images from disk** — always use Read tool for plan assets
- **Be specific** — "the grid should be 3 columns, got 2" not "layout is wrong"
- **Compare content verbatim** — headlines and body text must match exactly
- **Use base skill**: `verification-before-completion` for completion gate
