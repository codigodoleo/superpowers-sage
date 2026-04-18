---
name: superpowers-sage:sageing
description: Meta-skill for Sage/Acorn projects; explains the gerund workflow ecosystem, Lando commands, architectural preferences, plan system, design tool integration, and when to use which skill. Read this first in any Sage project.
---

# Sageing — The Sage/Acorn Ecosystem Guide

This plugin provides Sage/Acorn-aware workflow skills for modern WordPress development with the Roots ecosystem, Lando, and design tool integration.

## HARD RULE — Language Policy

**All written artifacts MUST be in en-US.** This is mandatory and never negotiable.

| Context | Language | Examples |
|---|---|---|
| Code (variables, functions, classes) | **en-US always** | `ProposalValue`, not `PropostaValor` |
| Code comments | **en-US always** | `// Fetch highlighted projects` |
| File and directory names | **en-US always** | `proposal-value-adr.md`, not `proposta-valor-adr.md` |
| Documentation, plans, specs, ADRs | **en-US always** | "Eyebrow with lines", not "Eyebrow com linhas" |
| Design guides, component maps | **en-US always** | `HighlightProjects`, not `ProjetosDestaque` |
| Git commit messages | **en-US always** | `feat: add hero section` |
| Git branch names | **en-US always** | `feat/hero-section`, not `feat/secao-hero` |
| CHANGELOG, README | **en-US always** | |
| User-facing prompts and conversation | **User's language** | Follow the language the user writes in |

**Why:** Projects operate in collaborative, international environments. Mixed-language artifacts (half English class names, half Portuguese descriptions) are unprofessional and break searchability, consistency, and onboarding for new team members.

**Enforcement:** If you catch yourself writing a non-English term in any artifact, stop and translate it. Agents and skills that generate artifacts must produce en-US output regardless of the user's conversation language.

## Runner Selection (Lando)

All commands run inside Lando containers. Use the custom tooling defined in `.lando.yml`:

```
# Theme-level commands (run inside wp-content/themes/{theme}/)
lando theme-composer require log1x/acf-composer
lando theme-yarn add -D tailwindcss

# Acorn commands
lando acorn <command>

# WordPress CLI
lando wp <command>

# Vite dev server
lando vite

# Direct PHP/Composer at project root
lando composer <command>
lando php <command>

# Cache management
lando flush               # Clear all caches (Blade, OPcache, Acorn)
lando theme-build         # Production build (Vite)
```

**Never run `composer` or `php` on the host.** Always use `lando` wrappers to ensure correct PHP version, extensions, and paths.

## Workflow Skills (Gerunds)

Skills are **activities** — gerund naming communicates process, not command.

| Skill                      | Command                   | Purpose                                                              |
| -------------------------- | ------------------------- | -------------------------------------------------------------------- |
| **Onboarding**             | `/onboarding`             | Project analysis, design tool detection, active plan detection       |
| **Architecture Discovery** | `/architecture-discovery` | Deep architecture discovery with approval gates and spec review loop |
| **Plan Generator**         | `/plan-generator`         | Converts approved architecture into executable plan files            |
| **Architecting**           | `/architecting`           | Compatibility wrapper for architecture-discovery + plan-generator    |
| **Modeling**               | `/modeling`               | Content architecture analysis (static vs dynamic)                    |
| **Designing**              | `/designing`              | Design tool integration (Paper/Stitch/Figma/Pencil/offline assets) — routes by URL or file |
| **Design System**          | `/sage-design-system`     | Establish visual foundation: tokens → UI components → layout components → kitchensink |
| **Block Architecting**     | `/sage-block-architecting`| CSS contract for each ACF block: scoped CSS, enqueue guard, `$styles`, block README |
| **Building**               | `/building`               | Plan-driven implementation with auto-verification                    |
| **Verifying**              | `/verifying`              | Visual comparison with design reference                              |
| **Reviewing**              | `/reviewing`              | Convention audit + design alignment check                            |
| **Debugging**              | `/debugging`              | Sage-aware troubleshooting with cache knowledge                      |

### Recommended workflow for new features

```
/sage-design-system      →  (tokens, UI atoms, layout components, kitchensink validated)
/architecture-discovery  →  (generates approved architecture spec)
/plan-generator          →  (generates plan + assets)
/building      →  (implements from plan; auto-invokes /sage-block-architecting per ACF block)
/reviewing     →  (convention audit + design alignment)
```

For simple tasks, you can invoke individual skills directly.

## Architectural Preferences

| Scenario                    | Preferred Approach                                   | Avoid                                            |
| --------------------------- | ---------------------------------------------------- | ------------------------------------------------ |
| Routes                      | Acorn Routes                                         | `register_rest_route()`                          |
| Background tasks (simple)   | Action Scheduler                                     | Raw cron                                         |
| Background tasks (robust)   | Queue + Job                                          | Looping scripts                                  |
| Authentication              | JWT Auth + custom middleware                         | Cookie-only auth for APIs                        |
| Global configuration        | ACF Options Pages                                    | `wp_options` directly                            |
| Business logic              | Service class or Provider                            | Fat controllers/closures                         |
| Interactive UI              | Livewire                                             | Heavy custom JS (unless performance requires it) |
| Data in templates/views     | REST + JS                                            | Inline PHP queries                               |
| Data in routes              | Livewire                                             | REST + JS                                        |
| Forms                       | Livewire form + HTML Forms (`log1x/sage-html-forms`) | Contact Form 7 / Gravity                         |
| UI components (static)      | Blade Component                                      | Shortcodes                                       |
| UI components (interactive) | Livewire Component                                   | jQuery plugins                                   |
| Custom fields/blocks        | ACF Composer                                         | ACF GUI / `acf_add_local_field_group()`          |
| Content types               | Poet (`config/poet.php`)                             | `register_post_type()` directly                  |
| Menus                       | Navi                                                 | `wp_nav_menu()` directly                         |

## Plan System

Plans live in `docs/plans/` as directories with structured content:

```
docs/plans/YYYY-MM-DD-<topic>/
  plan.md              # Frontmatter with status, strategy, design-tool
  architecture.md      # Architecture Decision Record
  content-model.md     # Content modeling output
  assets/              # Design reference images (screenshots, exports)
    section-hero.png
    section-about.png
  components/          # Sub-plans per component
    01-hero.md
    02-about.md
  logs/                # Activity tracking (auto-populated by hooks)
    activity.log
```

**Plan frontmatter:**

```yaml
---
title: "Feature Name"
date: YYYY-MM-DD
status: in-progress | completed | abandoned
strategy: interactive | autonomous | mixed
design-tool: paper | stitch | figma | pencil | offline | none
components:
  - name: Hero
    status: pending
  - name: About
    status: completed
---
```

## Design Tool Integration

The plugin routes to a design tool based on the URL the user provides:

| Tool                  | URL pattern                  | MCP                        | Usage                                                                                                           |
| --------------------- | ---------------------------- | -------------------------- | --------------------------------------------------------------------------------------------------------------- |
| **Paper** (preferred) | `paper.design/*`             | `mcp__paper__*`            | `get_basic_info` → `get_tree_summary` → `get_node_info` → `get_screenshot` + `get_computed_styles` + `get_jsx`  |
| **Stitch** (Google)   | `stitch.withgoogle.com/*`    | `mcp__stitch__*`           | `list_screens` → `get_screen` → extract per section                                                             |
| **Figma**             | `figma.com/*`                | `mcp__figma__*`            | List files → get frames → extract layers/text                                                                   |
| **Pencil**            | `*.pen` / `design/` folder   | `mcp__pencil__*`           | `open_document` → `get_variables` / `batch_get(resolveVariables: true)` → `get_screenshot`                     |
| **Playwright MCP**    | n/a                          | `mcp__plugin_playwright_playwright__*` | Capture implementation screenshots for verification                               |
| **Chrome**            | n/a                          | `mcp__Claude_in_Chrome__*` | Alternative screenshot capture                                                                                  |

Routing is by URL, not by which MCP happens to be configured. If the user sends a `paper.design` link and the paper MCP is not installed, `/designing` stops with a setup instruction rather than silently falling back.

When using Paper as source, `/designing` persists three artifacts per section in `assets/`: `.png` (screenshot), `.styles.json` (computed styles, consumed by `/verifying` for style spot-check), and `.reference.jsx` (structural reference — never copied as code, since Sage uses Blade not React).

When no design MCP is available, skills work with local assets in `docs/plans/<plan>/assets/`.

## Playwright MCP vs Playwright Test npm

These are two completely different tools with similar names:

| | Playwright MCP | Playwright Test npm |
|---|---|---|
| **What it is** | MCP server for browser automation via Claude | npm package for E2E testing |
| **MCP namespace** | `mcp__plugin_playwright_playwright__*` | n/a |
| **Primary use** | Capture implementation screenshots for visual comparison against design | Run automated E2E test suite |
| **Installation** | `claude mcp add playwright -- npx -y @anthropic/playwright-mcp` | `npm install --save-dev @playwright/test` |
| **Target URL** | `https://{project}.lndo.site` (Lando local) | Configurable in `playwright.config.ts` |
| **Browser binary** | Managed by the MCP server | Must be installed via `npx playwright install` |
| **Replacement for** | Neither — orthogonal tools. MCP is for visual verification; npm is for regression tests | |

**Never substitute one for the other.** When `/verifying` requires a screenshot, use the Playwright MCP. When running `npm run test:e2e`, that is the Playwright Test suite.

## Reference Skills (Agent-Facing)

These skills provide deep technical reference for agents and workflow skills:

| Domain                                 | Skill                             |
| -------------------------------------- | --------------------------------- |
| Project setup, Lando, ACF, Blade, Vite | `sage-lando` (with `references/`) |
| Routes & Controllers                   | `acorn-routes`                    |
| Livewire                               | `acorn-livewire`                  |
| Eloquent ORM                           | `acorn-eloquent`                  |
| Middleware & Auth                      | `acorn-middleware`                |
| Queues & Jobs                          | `acorn-queues`                    |
| Logging & Errors                       | `acorn-logging`                   |
| CLI Commands                           | `acorn-commands`                  |
| Redis                                  | `acorn-redis`                     |
| Native Blocks                          | `wp-block-native`                 |
| Capabilities                           | `wp-capabilities`                 |
| WP-CLI                                 | `wp-cli-ops`                      |
| Hooks Lifecycle                        | `wp-hooks-lifecycle`              |
| Performance                            | `wp-performance`                  |
| PHPStan                                | `wp-phpstan`                      |
| REST API                               | `wp-rest-api`                     |
| Security                               | `wp-security`                     |

## Hooks & Automation

The plugin includes zero-token automation hooks:

| Hook            | Trigger              | Action                                                |
| --------------- | -------------------- | ----------------------------------------------------- |
| `session-start` | Session start        | Health check, design tool detection, inject sageing   |
| `post-edit`     | Write/Edit tool      | `lando flush` for PHP, `lando theme-build` for assets |
| `post-compact`  | Context compression  | Inject active plan reminder + asset count             |
| `pre-commit`    | `git commit` in Bash | Visual verification reminder                          |
| `post-subagent` | Subagent completion  | Log activity to plan directory                        |
| `post-stop`     | Session end          | Log session end to plan directory                     |

## Integration with Base Superpowers

This plugin extends [obra/superpowers](https://github.com/obra/superpowers). Workflow skills orchestrate base skills:

| Base Skill                       | Used By                                                   |
| -------------------------------- | --------------------------------------------------------- |
| `brainstorming`                  | `/architecture-discovery` (design-first discovery engine) |
| `writing-plans`                  | `/plan-generator` (plan expansion model)                  |
| `executing-plans`                | `/building` (plan execution)                              |
| `subagent-driven-development`    | `/building` (parallel component implementation)           |
| `dispatching-parallel-agents`    | `/building` (independent component parallelism)           |
| `finishing-a-development-branch` | `/reviewing` (merge/PR workflow)                          |
| `systematic-debugging`           | `/debugging` (core engine)                                |
| `verification-before-completion` | `/verifying` (completion gate)                            |

## Philosophy

- Acorn brings Laravel into WordPress — use Laravel patterns, not WordPress procedural code
- Service Providers are the backbone: register bindings, boot hooks
- Blade Components over shortcodes, always
- ACF Composer for all custom fields/blocks — never use the ACF GUI to create fields
- Livewire for interactive UI unless payload size compromises performance
- YAGNI — don't over-engineer. Start with a Service, extract to a Provider only when needed
- Plans with assets prevent design drift after context compression
- Always verify visually before committing
