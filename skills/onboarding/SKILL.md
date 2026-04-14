---
name: superpowers-sage:onboarding
description: Analyze a Sage/Acorn project and present an onboarding overview; detect installed packages, configured services, theme structure, design tools, active plans, and guide the developer on what to explore or work on
user-invocable: true
context: fork
---

# Onboarding — Project Analysis & Overview

Analyze a Sage/Acorn project's current state and present a clear overview with next steps.

## When to use

- Developer is new to the project or returning after a break
- First interaction with a Sage/Acorn project in a session
- Developer wants to understand what's configured and what's missing

## Procedure

### 0) Run project inventory

Scan the project using native tools (Glob, Grep, Read — no bash pipes needed):

**Sage themes:** Use `Grep` with pattern `"roots/acorn"` on glob `**/composer.json` (excluding vendor/node_modules).

**Acorn version:** Use `Glob` to find `**/composer.lock` (excluding vendor), then `Read` it and extract the `roots/acorn` version from the `packages` array.

**Service Providers:** Use `Glob` with pattern `**/app/Providers/*.php` (excluding vendor). Extract filenames from paths.

**ACF Blocks:** Use `Glob` with pattern `**/app/Blocks/*.php` (excluding vendor). Extract filenames from paths.

**Routes:** Use `Glob` with patterns `**/routes/web.php` and `**/routes/api.php` (excluding vendor).

**Livewire components:** Use `Glob` with pattern `**/app/Livewire/*.php` (excluding vendor). Extract filenames from paths.

**Installed packages (theme):** Use `Glob` to find the theme's `composer.json` (the one containing `"roots/acorn"`), then `Read` it and extract the `require` block.

**Lando config:** Use `Read` on `.lando.yml` (top-level only).

### 1) Detect design tools

Use ToolSearch to check for available design MCPs:

- Search for `mcp__paper__` — Paper.design MCP (preferred when the user works from paper.design)
- Search for `mcp__stitch__` — Stitch (Google) MCP
- Search for `mcp__figma__` — Figma MCP
- Search for `mcp__playwright__` — Playwright MCP for screenshots

Report which design tools are available.

### 1b) HARD GATE — Playwright MCP

After detecting design tools, before suggesting next steps:

Use ToolSearch to search for `mcp__plugin_playwright_playwright__browser_take_screenshot`.

If NOT found, output this message and **stop completely**. Do not suggest any next steps.
Do not proceed to step 2.

```
⛔ STOP — Playwright MCP is required

Visual verification is mandatory in this workflow.
/building and /verifying cannot proceed without Playwright.

Install:
  claude mcp add playwright -- npx -y @anthropic/playwright-mcp

After installing, restart this session and run /onboarding again.
```

### 2) Check for active plans

Look for `docs/plans/*/plan.md` files with `status: in-progress`. If found, report the active plan path and component status.

### 3) Present structured overview

```
## Project: {theme-name}

### Stack
- Acorn: {version} | PHP: {version} | Node: {version}
- Tailwind: {v3 or v4} | Database: {mysql/mariadb}

### Installed Packages
{list from composer.json — highlight: acf-composer, livewire, poet, navi}

### What's Configured
- Service Providers: {count} ({names})
- ACF Blocks: {count} ({names})
- Routes: {web.php? api.php?}
- Livewire: {installed or not}

### Design Tools
- Paper: {available/not available}  (preferred when designs live on paper.design)
- Stitch: {available/not available}
- Figma: {available/not available}
- Playwright: {available/not available}

### Active Plans
{list or "No active plans"}

### Branch Status
- Current branch: {output of `git branch --show-current`}
- {If on main/master}: ⚠️ Start a feature branch before implementing: `git checkout -b feat/<topic>-YYYY-MM-DD`
- {If on feature branch}: ✅ Working on `{branch}` — aligned with workflow

### Lando Services
{services and URLs from proxy config}
```

### 4) Suggest next steps

Based on project state:

- New project → suggest `/architecture-discovery` then `/plan-generator` to prepare first feature plan
- Active plan → suggest `/building` to resume implementation
- Existing code → suggest `/reviewing` for health check
- Issue reported → suggest `/debugging`
- Playwright confirmed ✅ — visual verification is available

## Key Principles

- **Be factual** — only report what you actually found
- **Be concise** — overview should fit on one screen
- **Be helpful** — suggest concrete next steps
