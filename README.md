# Superpowers Sage

Agent plugin for modern WordPress development with the **Roots ecosystem** — works with **Claude Code**, **VS Code (GitHub Copilot)**, **Cursor**, and any AI assistant that supports the agent plugin format. Workflow skills, design tool integration, visual verification, content modeling, and zero-token automation hooks for **Sage**, **Acorn**, and **Lando** projects.

## Prerequisites

| Requirement | Version |
|---|---|
| [Lando](https://lando.dev) | 3.x |
| [Sage](https://roots.io/sage/) + [Acorn](https://roots.io/acorn/) | 11+ / 4+ |
| PHP | 8.2+ |
| Node.js | 20+ |

## Installation

> **One repository, three loaders.** The same plugin installs identically regardless of your AI assistant. Pick the section for your tool below.

---

### Claude Code

```bash
claude plugin marketplace add codigodoleo/superpowers-sage
claude plugin install superpowers-sage@superpowers-sage
```

Alternatively, install directly from the repository URL:

```bash
claude plugin install --source https://github.com/codigodoleo/superpowers-sage
```

Verify the installation:

```bash
claude plugin list
```

---

### VS Code (GitHub Copilot Chat)

1. Enable the preview feature in your settings:

   ```json
   // settings.json
   "chat.plugins.enabled": true
   ```

2. Open the Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`) and run:

   ```
   Chat: Install Plugin From Source
   ```

3. Enter the repository URL:

   ```
   https://github.com/codigodoleo/superpowers-sage
   ```

**Alternative — install via Extensions view:**  
Search `@agentPlugins` in the Extensions sidebar, or add the repository as a marketplace source in your settings:

```json
// settings.json
"chat.plugins.marketplaces": [
  "codigodoleo/superpowers-sage"
]
```

Then search for and install `superpowers-sage` from the Extensions view.

---

### Cursor

1. Open **Settings → Features → AI Rules / Plugins** (or the equivalent plugin panel for your Cursor version).
2. Add the repository as a plugin source:

   ```
   https://github.com/codigodoleo/superpowers-sage
   ```

3. Cursor discovers skills and agents from the `skills/` and `agents/` directories automatically. Hooks are loaded from `hooks/cursor-hooks.json`.

---

### Local / Generic (any compatible assistant)

Clone the repository and register the plugin directory:

```bash
git clone https://github.com/codigodoleo/superpowers-sage ~/.ai-plugins/superpowers-sage
```

Then point your AI assistant to the cloned directory. For tools that support `chat.pluginLocations` (VS Code) or `--plugin-dir` (Claude Code):

```json
// VS Code settings.json
"chat.pluginLocations": {
  "/Users/you/.ai-plugins/superpowers-sage": true
}
```

```bash
# Claude Code — session-scoped
claude --plugin-dir ~/.ai-plugins/superpowers-sage
```

---

### Design Tools (optional)

These MCP integrations unlock the `/designing` and `/verifying` skills. Configure once per machine independent of which AI assistant you use:

```bash
# Stitch (Google) — extract screens and sections from designs
claude mcp add stitch -- npx -y @anthropic/stitch-mcp

# Figma — extract frames and layers from designs
claude mcp add figma -- npx -y figma-developer-mcp --figma-api-key=YOUR_KEY

# Playwright — capture implementation screenshots for visual verification
claude mcp add playwright -- npx -y @anthropic/playwright-mcp
```

For VS Code, add MCP servers in `.vscode/mcp.json` or user settings under `"mcp"`.

---

## Compatibility Matrix

| Feature | Claude Code | VS Code Copilot | Cursor | Notes |
|---|---|---|---|---|
| Workflow skills (`/building`, etc.) | ✅ | ✅ | ✅ | All tools load `skills/` |
| Custom agents | ✅ | ✅ | ✅ | All tools load `agents/` |
| Hooks (lifecycle automation) | ✅ | ✅ | ✅ | Claude/VS Code use `hooks/hooks.json`; Cursor uses `hooks/cursor-hooks.json` |
| MCP design tools | ✅ | ✅ | ✅ | Configure per tool's MCP settings |
| Marketplace install | ✅ | ✅ | — | Cursor installs direct from repository |
| Namespaced skills | `superpowers-sage:building` | `superpowers-sage:building` | `/building` | Cursor may omit namespace prefix |

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
| `/architecture-discovery` | Deep architecture discovery with hard gates, section approvals, and reviewer loop |
| `/plan-generator` | Converts approved architecture spec into executable plan files and dependency graph |
| `/architecting` | Compatibility wrapper: runs architecture-discovery then plan-generator |
| `/modeling` | Content architecture: classify static vs dynamic, recommend Poet/ACF |
| `/designing` | Design tool integration: Stitch, Figma, or local asset extraction |
| `/building` | Plan-driven implementation with auto-verification after each component |
| `/verifying` | Visual comparison: screenshots vs design reference |
| `/reviewing` | Convention audit + design alignment check |
| `/debugging` | Sage-aware troubleshooting with cache and OPcache knowledge |
| `/install-plugin` | Install WordPress plugins via Composer from local `.zip` or `wp-packages.org` |

### Recommended flow for new features

```
/architecture-discovery  →  approved architecture spec
/plan-generator          →  plan + assets + content model
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

### Hook warnings and diagnostics

If a hook does not appear to execute, run this checklist:

**1. Quick diagnostics**

```bash
bash scripts/doctor-hooks.sh
```

This verifies prerequisites (Lando, Node, hook scripts), active plans, and shows recent log entries.

**2. Enable debug logging**

```bash
export SUPERPOWERS_SAGE_HOOK_DEBUG=1
export SUPERPOWERS_SAGE_HOOK_LOG=.superpowers-sage/hooks.log
```

Then reproduce the action (edit a file, git commit, etc.) and inspect the log:

```bash
tail -20 .superpowers-sage/hooks.log
```

Look for entries with `HOOK_STATUS=skip` or `HOOK_STATUS=warn`.

**3. Common warnings**

| Warning | Cause | Action |
|---|---|---|
| `skip: lando CLI not found in PATH` | Lando not installed or not in PATH | Install Lando: `brew install lando` (macOS) or [platform-specific installer](https://lando.dev) |
| `skip: .lando.yml not found` | Project is not Lando-based | post-edit hook only runs in Lando projects |
| `skip: file_path not found in payload` | Hook couldn't extract file path from event | Normal for non-file actions; configure your editor to emit file paths on write |
| `skip: no active plan found` | No plan with `status: in-progress` exists | Create a plan with `/architecture-discovery` then `/plan-generator`, or run `/building` with an existing plan |
| `HOOK_STATUS=warn: theme-build failed` | Asset build error (Vite, Tailwind, etc.) | Run `lando theme-build` manually to see the full error |

## Command Discovery

Skills marked as `user-invocable: true` appear in the `/` command palette. They are displayed with their full technical name:

| Skill | Appears as | Use when |
|---|---|---|
| `superpowers-sage:onboarding` | `/superpowers-sage:onboarding` or `/onboarding` | New to project or need overview |
| `superpowers-sage:architecture-discovery` | `/superpowers-sage:architecture-discovery` or `/architecture-discovery` | Discovering and validating architecture |
| `superpowers-sage:plan-generator` | `/superpowers-sage:plan-generator` or `/plan-generator` | Generating executable plan from approved spec |
| `superpowers-sage:architecting` | `/superpowers-sage:architecting` or `/architecting` | Compatibility alias for the two-step planning flow |
| `superpowers-sage:building` | `/superpowers-sage:building` or `/building` | Implementing from a plan |
| `superpowers-sage:designing` | `/superpowers-sage:designing` or `/designing` | Capturing design reference |
| `superpowers-sage:verifying` | `/superpowers-sage:verifying` or `/verifying` | Comparing vs design |
| `superpowers-sage:reviewing` | `/superpowers-sage:reviewing` or `/reviewing` | Auditing code/conventions |
| `superpowers-sage:modeling` | `/superpowers-sage:modeling` or `/modeling` | Content structure decisions |
| `superpowers-sage:debugging` | `/superpowers-sage:debugging` or `/debugging` | Troubleshooting issues |
| `superpowers-sage:install-plugin` | `/superpowers-sage:install-plugin` or `/install-plugin` | Installing WP plugins via Composer |

**Note:** If you don't see the expected command, refresh the plugin cache or restart your session. The `/` palette respects your editor's auto-complete configuration.

## Plan System

`/architecture-discovery` writes an approved spec in `docs/superpowers/specs/`, and `/plan-generator` generates plan directories that persist design context across sessions:

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
