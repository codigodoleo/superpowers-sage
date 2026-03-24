# Superpowers Sage

Comprehensive [Claude Code](https://claude.com/claude-code) plugin for modern WordPress development with the **Roots ecosystem**. Workflow skills, design tool integration, visual verification, content modeling, and zero-token automation hooks for **Sage**, **Acorn**, and **Lando** projects.

## Installation

```bash
claude plugin marketplace add codigodoleo/superpowers-sage
claude plugin install codigodoleo/superpowers-sage
```

### Prerequisites

| Requirement | Version |
|---|---|
| [obra/superpowers](https://github.com/obra/superpowers) | latest |
| [Lando](https://lando.dev) | 3.x |
| [Sage](https://roots.io/sage/) + [Acorn](https://roots.io/acorn/) | 11+ / 4+ |
| PHP | 8.2+ |
| Node.js | 20+ |

### Design Tools (optional)

```bash
# Stitch (Google) — extract screens and sections from designs
claude mcp add stitch -- npx -y @anthropic/stitch-mcp

# Figma — extract frames and layers from designs
claude mcp add figma -- npx -y figma-developer-mcp --figma-api-key=YOUR_KEY

# Playwright — capture implementation screenshots for visual verification
claude mcp add playwright -- npx -y @anthropic/playwright-mcp
```

## Getting Started

After installing, open your Sage project and run:

```
/onboarding
```

This analyzes your project, detects installed packages, design tools, and active plans, then suggests next steps.

## Workflow Skills

Skills are **activities** — gerund naming communicates what's happening, not what to type.

| Command | What it does |
|---|---|
| `/onboarding` | Project analysis: stack, packages, design tools, active plans |
| `/architecting` | Brainstorming + architecture decisions + design capture + content modeling |
| `/modeling` | Content architecture: classify static vs dynamic, recommend Poet/ACF |
| `/designing` | Design tool integration: Stitch, Figma, or local asset extraction |
| `/building` | Plan-driven implementation with auto-verification after each component |
| `/verifying` | Visual comparison: screenshots vs design reference |
| `/reviewing` | Convention audit + design alignment check |
| `/debugging` | Sage-aware troubleshooting with cache and OPcache knowledge |
| `/install-plugin` | Install WordPress plugins via Composer from local `.zip` or `wp-packages.org` |

### Recommended flow for new features

```
/architecting  →  plan + assets + content model
/building      →  implement from plan, verify each component
/reviewing     →  convention audit + design alignment
```

For simple tasks, invoke any skill directly.

## Reference Skills

18 deep technical references, used internally by workflow skills and agents:

- **Sage/Lando** — project setup, ACF Composer, Blade templates, Vite + Tailwind, service providers, routing, testing, troubleshooting, WordPress Composer packages
- **Acorn** — routes, livewire, eloquent, middleware, queues, logging, commands, redis
- **WordPress** — native blocks, capabilities, WP-CLI, hooks lifecycle, performance, PHPStan, REST API, security

## Agents

| Agent | Purpose |
|---|---|
| `sage-architect` | Analyze requirements and produce Architecture Decision Records |
| `sage-reviewer` | Audit code against Sage/Acorn conventions |
| `sage-debugger` | Systematic diagnostics for Sage/Acorn/Lando issues |
| `content-modeler` | Classify content as static, dynamic CPT, Options Page, or relational |
| `visual-verifier` | Compare implementation screenshots against design reference |

## Hooks

Zero-token automation that runs without consuming LLM context:

| Hook | Trigger | What it does |
|---|---|---|
| **session-start** | Every session | Health check, detect design tools, inject ecosystem guide |
| **post-edit** | After Write/Edit | `lando flush` for PHP files, `lando theme-build` for assets |
| **post-compact** | Context compression | Re-inject active plan path and asset count |
| **pre-commit** | Before `git commit` | Remind to verify visually against design reference |
| **post-subagent** | Subagent completes | Log activity to plan directory |
| **post-stop** | Session ends | Log session end to plan directory |

## Plan System

The `/architecting` skill generates plan directories that persist design context across sessions:

```
docs/plans/YYYY-MM-DD-<topic>/
  plan.md              # Status, strategy, design tool, component list
  architecture.md      # Architecture Decision Record
  content-model.md     # Static vs dynamic classification per component
  assets/              # Design reference images (screenshots, exports)
  components/          # Sub-plans per component
  logs/                # Activity tracking (auto-populated by hooks)
```

Plans survive context compression because hooks re-inject the active plan path, and `/building` always re-reads assets from disk before each component.

## Architectural Preferences

The plugin enforces opinionated patterns for the Roots ecosystem:

| Scenario | Use | Avoid |
|---|---|---|
| Routes | Acorn Routes | `register_rest_route()` |
| Background tasks | Action Scheduler / Queue + Job | Raw cron, looping scripts |
| Global config | ACF Options Pages | `wp_options` directly |
| Business logic | Service class or Provider | Fat controllers |
| Interactive UI | Livewire | Heavy custom JS |
| Static UI | Blade Component | Shortcodes |
| Fields & Blocks | ACF Composer | ACF GUI |
| Content types | Poet (`config/poet.php`) | `register_post_type()` |
| Forms | Livewire + HTML Forms | CF7, Gravity |

## License

MIT
