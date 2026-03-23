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

Scan the project to build a snapshot:

**Sage themes:**
!`find . -name composer.json -not -path "*/vendor/*" -not -path "*/node_modules/*" | xargs grep -l '"roots/acorn"' 2>/dev/null`

**Acorn version:**
!`find . -name composer.lock -not -path "*/vendor/*" 2>/dev/null | head -1 | xargs python3 -c "import json,sys; d=json.load(open(sys.argv[1])); pkgs=d.get('packages',[])+d.get('packages-dev',[]); [print(p['name'],'=',p['version']) for p in pkgs if p['name']=='roots/acorn']" 2>/dev/null || echo "(not found)"`

**Service Providers:**
!`find . -path "*/app/Providers/*.php" -not -path "*/vendor/*" 2>/dev/null | sed 's|.*/||'`

**ACF Blocks:**
!`find . -path "*/app/Blocks/*.php" -not -path "*/vendor/*" 2>/dev/null | sed 's|.*/||'`

**Routes:**
!`find . \( -name "web.php" -o -name "api.php" \) -path "*/routes/*" -not -path "*/vendor/*" 2>/dev/null`

**Livewire components:**
!`find . -path "*/app/Livewire/*.php" -not -path "*/vendor/*" 2>/dev/null | sed 's|.*/||'`

**Installed packages (theme):**
!`find . -name composer.json -not -path "*/vendor/*" | xargs grep -l '"roots/acorn"' 2>/dev/null | head -1 | xargs python3 -c "import json,sys; d=json.load(open(sys.argv[1])); [print(' -',k,v) for k,v in d.get('require',{}).items() if not k.startswith('php')]" 2>/dev/null`

**Lando config:**
!`cat .lando.yml 2>/dev/null | head -40`

### 1) Detect design tools

Use ToolSearch to check for available design MCPs:
- Search for `mcp__stitch__` — Stitch (Google) MCP
- Search for `mcp__figma__` — Figma MCP
- Search for `mcp__playwright__` — Playwright MCP for screenshots

Report which design tools are available.

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
- Stitch: {available/not available}
- Figma: {available/not available}
- Playwright: {available/not available}

### Active Plans
{list or "No active plans"}

### Lando Services
{services and URLs from proxy config}
```

### 4) Suggest next steps

Based on project state:
- New project → suggest `/architecting` to plan first feature
- Active plan → suggest `/building` to resume implementation
- Existing code → suggest `/reviewing` for health check
- Issue reported → suggest `/debugging`

## Key Principles
- **Be factual** — only report what you actually found
- **Be concise** — overview should fit on one screen
- **Be helpful** — suggest concrete next steps
