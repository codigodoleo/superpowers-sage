# Plugin Expansion — Onda 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deterministic capabilities: fixture-based hook test harness, skill-activation UserPromptSubmit hook, PHPCS quality-gate Stop hook, protected-path PreToolUse hook, and three slash command files.

**Architecture:** All hook behaviors are bash scripts sourcing `hooks/lib.sh`, reading stdin JSON, and writing structured JSON to stdout. Tests use `scripts/test-hooks.mjs` — a Node.js fixture harness spawning hook scripts against fixture directories under `scripts/__fixtures__/hooks/<hook-name>/<case>/`. Slash commands are Markdown files in `commands/` resolved natively by Claude Code. All new hooks register in `hooks/hooks.json` and sync to `hooks/cursor-hooks.json` via `scripts/sync-cursor-hooks.mjs`.

**Tech Stack:** Bash 3+, Node.js ESM, existing `hooks/lib.sh` utilities, existing `scripts/sync-cursor-hooks.mjs`.

**Execution order:** Task 1 (MP 3.5, harness) first. Task 2 (MP 3.1) is independent. Tasks 3–5 (MPs 3.2–3.4) depend on Task 1 fixture pattern. Task 6 (MP 3.6) last.

---

## Task 1 — Fixture-based hook test harness (MP 3.5)

**Files:**
- Create: `scripts/test-hooks.mjs`
- Create: `scripts/__fixtures__/hooks/post-stop/no-plans-dir/stdin.json`
- Create: `scripts/__fixtures__/hooks/post-stop/no-plans-dir/expected-exit`
- Create: `scripts/__fixtures__/hooks/post-stop/no-plans-dir/expected-stdout-absent`
- Create: `scripts/__fixtures__/hooks/post-stop/no-plans-dir/env.json`

**Fixture layout contract:**
```
scripts/__fixtures__/hooks/<hook-name>/<case>/
  stdin.json             (required) piped to hook stdin
  expected-exit          (required) "0" or "2" — expected exit code
  expected-stdout        (optional) each line = substring that MUST appear in stdout
  expected-stdout-absent (optional) each line = substring that MUST NOT appear in stdout
  env.json               (optional) object of env vars; supports special keys:
                           PATH_PREPEND — relative path prepended to PATH
                           PATH        — fully overrides PATH
```

- [ ] **Step 1: Create the bootstrap fixture**

`scripts/__fixtures__/hooks/post-stop/no-plans-dir/stdin.json`:
```json
{}
```

`scripts/__fixtures__/hooks/post-stop/no-plans-dir/expected-exit`:
```
0
```

`scripts/__fixtures__/hooks/post-stop/no-plans-dir/expected-stdout-absent`:
```
block
```

`scripts/__fixtures__/hooks/post-stop/no-plans-dir/env.json`:
```json
{
  "SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"
}
```

- [ ] **Step 2: Run the harness (will fail — doesn't exist yet)**

```bash
node scripts/test-hooks.mjs
```

Expected: `node: cannot open file scripts/test-hooks.mjs` or similar error — confirms test is missing.

- [ ] **Step 3: Implement `scripts/test-hooks.mjs`**

```javascript
#!/usr/bin/env node
/**
 * Fixture-based test harness for hooks/*.sh scripts.
 * Fixture layout: scripts/__fixtures__/hooks/<hook-name>/<case>/
 */

import { spawnSync } from 'node:child_process';
import { readdirSync, readFileSync, existsSync, statSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');
const FIXTURES_DIR = join(ROOT, 'scripts', '__fixtures__', 'hooks');
const HOOKS_DIR = join(ROOT, 'hooks');

let passed = 0;
let failed = 0;

function assert(label, condition, detail) {
  if (condition) {
    console.log(`  ✅ ${label}`);
    passed++;
  } else {
    console.log(`  ❌ ${label}`);
    if (detail) console.log(`     ${detail}`);
    failed++;
  }
}

function runFixture(hookName, caseName) {
  const caseDir = join(FIXTURES_DIR, hookName, caseName);
  const hookScript = join(HOOKS_DIR, `${hookName}.sh`);

  if (!existsSync(hookScript)) {
    console.log(`  ⚠️  hook not found: hooks/${hookName}.sh — skipping "${caseName}"`);
    return;
  }

  const stdinRaw = readFileSync(join(caseDir, 'stdin.json'), 'utf8');
  const expectedExit = parseInt(readFileSync(join(caseDir, 'expected-exit'), 'utf8').trim(), 10);

  const expectedOut = existsSync(join(caseDir, 'expected-stdout'))
    ? readFileSync(join(caseDir, 'expected-stdout'), 'utf8').split('\n').filter(Boolean)
    : [];

  const absentOut = existsSync(join(caseDir, 'expected-stdout-absent'))
    ? readFileSync(join(caseDir, 'expected-stdout-absent'), 'utf8').split('\n').filter(Boolean)
    : [];

  const envOverrides = existsSync(join(caseDir, 'env.json'))
    ? JSON.parse(readFileSync(join(caseDir, 'env.json'), 'utf8'))
    : {};

  const env = { ...process.env };
  for (const [k, v] of Object.entries(envOverrides)) {
    if (k === 'PATH_PREPEND') {
      const prepend = resolve(ROOT, v);
      env.PATH = `${prepend}:${env.PATH || ''}`;
    } else if (k === 'PATH') {
      env.PATH = v;
    } else {
      env[k] = v;
    }
  }

  const result = spawnSync('bash', [hookScript], {
    input: stdinRaw,
    encoding: 'utf8',
    cwd: ROOT,
    env,
  });

  const stdout = (result.stdout || '') + (result.stderr || '');
  const actualExit = result.status ?? 1;

  assert(
    `${hookName}/${caseName} — exit ${expectedExit}`,
    actualExit === expectedExit,
    `got exit ${actualExit}\nstdout: ${stdout.slice(0, 300)}`
  );

  for (const sub of expectedOut) {
    assert(
      `${hookName}/${caseName} — stdout contains "${sub}"`,
      stdout.includes(sub),
      `stdout was: ${stdout.slice(0, 300)}`
    );
  }

  for (const sub of absentOut) {
    assert(
      `${hookName}/${caseName} — stdout absent "${sub}"`,
      !stdout.includes(sub),
      `stdout was: ${stdout.slice(0, 300)}`
    );
  }
}

if (!existsSync(FIXTURES_DIR)) {
  console.log('No fixtures directory found. 0 tests run.');
  process.exit(0);
}

for (const hookName of readdirSync(FIXTURES_DIR).sort()) {
  const hookDir = join(FIXTURES_DIR, hookName);
  if (!statSync(hookDir).isDirectory()) continue;
  console.log(`\n📂 ${hookName}`);
  for (const caseName of readdirSync(hookDir).sort()) {
    const caseDir = join(hookDir, caseName);
    if (!statSync(caseDir).isDirectory()) continue;
    runFixture(hookName, caseName);
  }
}

console.log(`\n${passed + failed} test${passed + failed !== 1 ? 's' : ''}: ${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
```

- [ ] **Step 4: Run the harness — verify bootstrap fixture passes**

```bash
node scripts/test-hooks.mjs
```

Expected output:
```
📂 post-stop
  ✅ post-stop/no-plans-dir — exit 0
  ✅ post-stop/no-plans-dir — stdout absent "block"

2 tests: 2 passed, 0 failed
```

- [ ] **Step 5: Commit**

```bash
git add scripts/test-hooks.mjs scripts/__fixtures__/hooks/post-stop/
git commit -m "feat(hooks): add fixture-based test harness (MP 3.5)"
```

---

## Task 2 — Slash commands (MP 3.1)

**Files:**
- Create: `commands/sage-status.md`
- Create: `commands/acf-register.md`
- Create: `commands/livewire-new.md`

- [ ] **Step 1: Create `commands/` directory**

```bash
mkdir -p commands
```

- [ ] **Step 2: Create `commands/sage-status.md`**

```markdown
# /sage-status

Reports Lando health, stack versions, active plan, and design tools for the current Sage project.

## What it runs

1. `lando info` — container status for each service.
2. Key stack versions: WordPress, PHP, Acorn, Node.
3. Active plan detection: first `docs/plans/*/plan.md` file with `status: in-progress`.
4. Design tools: `node scripts/detect-design-tools.mjs` from the plugin root.

## Output format (≤ 20 lines total)

```
### Lando Status
<output of `lando info --format=table` trimmed to service + status>

### Stack Versions
WordPress: <lando wp core version>
PHP:       <lando php -r "echo PHP_VERSION;">
Acorn:     <lando theme-composer show roots/acorn | grep versions>
Node:      <lando node --version>

### Active Plan
<plan directory name or "No active plan found">

### Design Tools
<node scripts/detect-design-tools.mjs — single-line summary>
```

## Instructions

Run each command with `lando <cmd>`. If a command fails, show "unavailable" for that entry. Present all four sections within 20 output lines total.
```

- [ ] **Step 3: Create `commands/acf-register.md`**

```markdown
# /acf-register

Scaffolds a new ACF field group as a PHP class via Acorn's ACF scaffolding command.

## Usage

```
/acf-register
```

You will be prompted for the field group name.

## What it does

1. Asks: "Field group name? (e.g. HeroFields, PageSettings)"
2. Runs: `lando acorn acf:field <FieldGroupName>`
3. Reports the file created (typically `app/Fields/<FieldGroupName>.php`).
4. Offers to open the file for editing.

## Requirements

- Acorn installed (`lando acorn` available).
- ACF Pro active in the project.
- Run from the theme root (`web/app/themes/<theme-name>/`).

## Notes

- This uses Acorn scaffolding, NOT the ACF GUI. Field groups are code-managed.
- After scaffolding, register the group inside the class's `register()` method.
- See the `acorn-eloquent` skill for field group best practices.
```

- [ ] **Step 4: Create `commands/livewire-new.md`**

```markdown
# /livewire-new

Scaffolds a new Livewire component via the project's create-component script.

## Usage

```
/livewire-new
```

You will be prompted for the component name.

## What it does

1. Asks: "Component name? (e.g. SearchBar, UserProfile)"
2. Runs: `bash skills/acorn-livewire/scripts/create-component.sh <ComponentName>`
3. Reports the files created (PHP class + Blade view).

## Requirements

- Livewire installed in the project.
- Run from the project root where `skills/acorn-livewire/scripts/` is accessible.

## Notes

- Component class goes in `app/Http/Livewire/` by default.
- Blade view goes in `resources/views/livewire/` by default.
- See the `acorn-livewire` skill for wiring events, properties, and Alpine.js integration.
```

- [ ] **Step 5: Commit**

```bash
git add commands/
git commit -m "feat(commands): add sage-status, acf-register, livewire-new slash commands (MP 3.1)"
```

---

## Task 3 — UserPromptSubmit skill-activation hook (MP 3.2)

**Files:**
- Create: `hooks/user-prompt-activate.sh`
- Create: `scripts/__fixtures__/hooks/user-prompt-activate/` (8 fixture cases)
- Modify: `hooks/hooks.json` (add UserPromptSubmit entry)
- Run: `node scripts/sync-cursor-hooks.mjs` (updates cursor-hooks.json)

**Hook contract:**
- Reads `{"prompt": "..."}` from stdin.
- If exactly one skill keyword matches the lowercased prompt → stdout: `{"additionalContext":"Skill hint: <name> skill is relevant."}`, exit 0.
- Zero matches or multiple matches → no stdout, exit 0.
- Malformed JSON or empty prompt → no stdout, exit 0.

**Fixture cases:**

| Case | Prompt in stdin | Expected exit | Stdout contains | Stdout absent |
|---|---|---|---|---|
| `livewire-match` | "create a livewire counter component" | 0 | `acorn-livewire` | — |
| `eloquent-match` | "add eloquent model for posts" | 0 | `acorn-eloquent` | — |
| `block-match` | "scaffold a new gutenberg block" | 0 | `block-scaffolding` | — |
| `lando-match` | "how do i restart lando services" | 0 | `sage-lando` | — |
| `no-match` | "what time is it in Tokyo" | 0 | — | `additionalContext` |
| `multi-match` | "livewire block component scaffold" | 0 | — | `additionalContext` |
| `empty-prompt` | "" (empty string in JSON) | 0 | — | `additionalContext` |
| `malformed-json` | (raw `{"broken":` — invalid JSON) | 0 | — | `additionalContext` |

- [ ] **Step 1: Create all fixture directories and files**

```bash
mkdir -p scripts/__fixtures__/hooks/user-prompt-activate/{livewire-match,eloquent-match,block-match,lando-match,no-match,multi-match,empty-prompt,malformed-json}
```

`scripts/__fixtures__/hooks/user-prompt-activate/livewire-match/stdin.json`:
```json
{"prompt": "create a livewire counter component"}
```

`scripts/__fixtures__/hooks/user-prompt-activate/livewire-match/expected-exit`:
```
0
```

`scripts/__fixtures__/hooks/user-prompt-activate/livewire-match/expected-stdout`:
```
acorn-livewire
```

`scripts/__fixtures__/hooks/user-prompt-activate/livewire-match/env.json`:
```json
{"SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"}
```

`scripts/__fixtures__/hooks/user-prompt-activate/eloquent-match/stdin.json`:
```json
{"prompt": "add eloquent model for posts"}
```

`scripts/__fixtures__/hooks/user-prompt-activate/eloquent-match/expected-exit`:
```
0
```

`scripts/__fixtures__/hooks/user-prompt-activate/eloquent-match/expected-stdout`:
```
acorn-eloquent
```

`scripts/__fixtures__/hooks/user-prompt-activate/eloquent-match/env.json`:
```json
{"SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"}
```

`scripts/__fixtures__/hooks/user-prompt-activate/block-match/stdin.json`:
```json
{"prompt": "scaffold a new gutenberg block"}
```

`scripts/__fixtures__/hooks/user-prompt-activate/block-match/expected-exit`:
```
0
```

`scripts/__fixtures__/hooks/user-prompt-activate/block-match/expected-stdout`:
```
block-scaffolding
```

`scripts/__fixtures__/hooks/user-prompt-activate/block-match/env.json`:
```json
{"SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"}
```

`scripts/__fixtures__/hooks/user-prompt-activate/lando-match/stdin.json`:
```json
{"prompt": "how do i restart lando services"}
```

`scripts/__fixtures__/hooks/user-prompt-activate/lando-match/expected-exit`:
```
0
```

`scripts/__fixtures__/hooks/user-prompt-activate/lando-match/expected-stdout`:
```
sage-lando
```

`scripts/__fixtures__/hooks/user-prompt-activate/lando-match/env.json`:
```json
{"SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"}
```

`scripts/__fixtures__/hooks/user-prompt-activate/no-match/stdin.json`:
```json
{"prompt": "what time is it in Tokyo"}
```

`scripts/__fixtures__/hooks/user-prompt-activate/no-match/expected-exit`:
```
0
```

`scripts/__fixtures__/hooks/user-prompt-activate/no-match/expected-stdout-absent`:
```
additionalContext
```

`scripts/__fixtures__/hooks/user-prompt-activate/no-match/env.json`:
```json
{"SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"}
```

`scripts/__fixtures__/hooks/user-prompt-activate/multi-match/stdin.json`:
```json
{"prompt": "livewire block component scaffold"}
```

`scripts/__fixtures__/hooks/user-prompt-activate/multi-match/expected-exit`:
```
0
```

`scripts/__fixtures__/hooks/user-prompt-activate/multi-match/expected-stdout-absent`:
```
additionalContext
```

`scripts/__fixtures__/hooks/user-prompt-activate/multi-match/env.json`:
```json
{"SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"}
```

`scripts/__fixtures__/hooks/user-prompt-activate/empty-prompt/stdin.json`:
```json
{"prompt": ""}
```

`scripts/__fixtures__/hooks/user-prompt-activate/empty-prompt/expected-exit`:
```
0
```

`scripts/__fixtures__/hooks/user-prompt-activate/empty-prompt/expected-stdout-absent`:
```
additionalContext
```

`scripts/__fixtures__/hooks/user-prompt-activate/empty-prompt/env.json`:
```json
{"SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"}
```

`scripts/__fixtures__/hooks/user-prompt-activate/malformed-json/stdin.json` (intentionally invalid JSON):
```
{"broken":
```

`scripts/__fixtures__/hooks/user-prompt-activate/malformed-json/expected-exit`:
```
0
```

`scripts/__fixtures__/hooks/user-prompt-activate/malformed-json/expected-stdout-absent`:
```
additionalContext
```

`scripts/__fixtures__/hooks/user-prompt-activate/malformed-json/env.json`:
```json
{"SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"}
```

- [ ] **Step 2: Run harness — verify hook skipped (not created yet)**

```bash
node scripts/test-hooks.mjs 2>&1 | grep -A1 "user-prompt-activate"
```

Expected: lines showing `⚠️  hook not found: hooks/user-prompt-activate.sh — skipping ...` for each case.

- [ ] **Step 3: Create `hooks/user-prompt-activate.sh`**

```bash
#!/usr/bin/env bash
# UserPromptSubmit hook: inject skill context when prompt matches exactly one skill keyword.
# Output: {"additionalContext":"..."} for a unique match. Silent on no-match or multi-match.

set -uo pipefail

HOOK_NAME="user-prompt-activate"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

INPUT="$(cat)"

# Extract prompt field — graceful on malformed JSON
PROMPT="$(echo "$INPUT" | grep -o '"prompt":[[:space:]]*"[^"]*"' | head -1 \
  | sed 's/"prompt":[[:space:]]*"//' | sed 's/"$//')" || PROMPT=""

[ -z "$PROMPT" ] && exit 0

PROMPT_LOWER="$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')"

# Format: "keyword1|keyword2:skill-name"
KEYWORD_MAP=(
  "livewire|livewire component|livewire-new:acorn-livewire"
  "eloquent|model class|database schema|migration:acorn-eloquent"
  "gutenberg block|register block|block.json|block scaffold:block-scaffolding"
  "lando|lando start|lando stop|lando restart:sage-lando"
  "queue|dispatch job|action scheduler|horizon:acorn-queues"
  "middleware|http kernel|acorn middleware:acorn-middleware"
  "redis|cache tags|cache driver:acorn-redis"
  "log channel|monolog|logging config:acorn-logging"
  "acorn route|routes/web|register route:acorn-routes"
  "phpcs|php codesniffer|phpstan:wp-phpstan"
  "rest api|wp_rest|rest endpoint:wp-rest-api"
  "design token|@theme block|tailwind token:sage-design-system"
  "block refactor|block evolution|block migration:block-refactoring"
)

MATCHED_SKILL=""
MATCH_COUNT=0

for entry in "${KEYWORD_MAP[@]}"; do
  keywords="${entry%%:*}"
  skill="${entry##*:}"
  IFS='|' read -ra kw_list <<< "$keywords"
  for kw in "${kw_list[@]}"; do
    if echo "$PROMPT_LOWER" | grep -qF "$kw" 2>/dev/null; then
      if [ "$MATCHED_SKILL" != "$skill" ]; then
        MATCHED_SKILL="$skill"
        MATCH_COUNT=$((MATCH_COUNT + 1))
      fi
      break
    fi
  done
done

if [ "$MATCH_COUNT" -ne 1 ]; then
  hook_info "Skill activation: $MATCH_COUNT match(es) — no injection"
  exit 0
fi

hook_info "Skill activation: injecting $MATCHED_SKILL"
printf '{"additionalContext":"Skill hint: %s skill is relevant. Invoke it if not already active."}\n' "$MATCHED_SKILL"
exit 0
```

- [ ] **Step 4: Make executable and run the harness**

```bash
chmod +x hooks/user-prompt-activate.sh
node scripts/test-hooks.mjs
```

Expected: all 10 existing tests pass (2 post-stop + 8 user-prompt-activate). Output ends with:
```
10 tests: 10 passed, 0 failed
```

- [ ] **Step 5: Register in `hooks/hooks.json`**

Add `UserPromptSubmit` as the first key in the `hooks` object (before `SessionStart`):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/user-prompt-activate.sh\""
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh\""
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/post-edit.sh\""
          }
        ]
      }
    ],
    "PostCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/post-compact.sh\""
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/pre-commit.sh\""
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/post-subagent.sh\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/post-stop.sh\""
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 6: Sync to cursor-hooks.json**

```bash
node scripts/sync-cursor-hooks.mjs
```

Expected output: `Synced hooks.json → cursor-hooks.json` (or similar success message). Verify `cursor-hooks.json` now contains a `UserPromptSubmit` entry.

- [ ] **Step 7: Commit**

```bash
git add hooks/user-prompt-activate.sh hooks/hooks.json hooks/cursor-hooks.json \
  scripts/__fixtures__/hooks/user-prompt-activate/
git commit -m "feat(hooks): add UserPromptSubmit skill-activation hook (MP 3.2)"
```

---

## Task 4 — Stop quality gate (MP 3.3)

**Files:**
- Modify: `hooks/post-stop.sh` (add PHPCS gate; fix directory-vs-file bug)
- Create: `scripts/__fixtures__/hooks/post-stop/quality-gate-off/`
- Create: `scripts/__fixtures__/hooks/post-stop/phpcs-strict-errors/`
- Create: `scripts/__fixtures__/hooks/post-stop/phpcs-strict-clean/`
- Create: `scripts/__fixtures__/hooks/post-stop/phpcs-warn-errors/`
- Create: `scripts/__fixtures__/hooks/post-stop/quality-gate-no-lando/`

**Hook behaviour:**
- `SUPERPOWERS_SAGE_QUALITY_GATE=off` — skip PHPCS entirely.
- `SUPERPOWERS_SAGE_QUALITY_GATE=warn` (default) — run PHPCS; log warning on errors; exit 0.
- `SUPERPOWERS_SAGE_QUALITY_GATE=strict` — run PHPCS; output `{"decision":"block","reason":"..."}` + exit 2 on errors.
- If `lando` not in PATH — skip PHPCS gate regardless of setting.
- Existing session-logging behaviour is preserved (bug fix: `docs/plans` is a directory, not a file — use `[ ! -d ]`).

**Fixture cases:**

| Case | Quality gate | Lando mock | Expected exit | Stdout contains | Stdout absent |
|---|---|---|---|---|---|
| `quality-gate-off` | off | none | 0 | — | block |
| `phpcs-strict-errors` | strict | exits 1 | 2 | block | — |
| `phpcs-strict-clean` | strict | exits 0 | 0 | — | block |
| `phpcs-warn-errors` | warn | exits 1 | 0 | — | block |
| `quality-gate-no-lando` | strict | no lando in PATH | 0 | — | block |

- [ ] **Step 1: Create fixture files and mock lando scripts**

Create directories:
```bash
mkdir -p \
  scripts/__fixtures__/hooks/post-stop/quality-gate-off \
  scripts/__fixtures__/hooks/post-stop/phpcs-strict-errors/bin \
  scripts/__fixtures__/hooks/post-stop/phpcs-strict-clean/bin \
  scripts/__fixtures__/hooks/post-stop/phpcs-warn-errors/bin \
  scripts/__fixtures__/hooks/post-stop/quality-gate-no-lando
```

`scripts/__fixtures__/hooks/post-stop/quality-gate-off/stdin.json`:
```json
{}
```

`scripts/__fixtures__/hooks/post-stop/quality-gate-off/expected-exit`:
```
0
```

`scripts/__fixtures__/hooks/post-stop/quality-gate-off/expected-stdout-absent`:
```
block
```

`scripts/__fixtures__/hooks/post-stop/quality-gate-off/env.json`:
```json
{
  "SUPERPOWERS_SAGE_QUALITY_GATE": "off",
  "SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"
}
```

---

`scripts/__fixtures__/hooks/post-stop/phpcs-strict-errors/stdin.json`:
```json
{}
```

`scripts/__fixtures__/hooks/post-stop/phpcs-strict-errors/expected-exit`:
```
2
```

`scripts/__fixtures__/hooks/post-stop/phpcs-strict-errors/expected-stdout`:
```
block
```

`scripts/__fixtures__/hooks/post-stop/phpcs-strict-errors/env.json`:
```json
{
  "SUPERPOWERS_SAGE_QUALITY_GATE": "strict",
  "SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null",
  "PATH_PREPEND": "scripts/__fixtures__/hooks/post-stop/phpcs-strict-errors/bin"
}
```

`scripts/__fixtures__/hooks/post-stop/phpcs-strict-errors/bin/lando` (mock — PHPCS errors):
```bash
#!/usr/bin/env bash
echo "FOUND 3 ERRORS affecting 1 file"
exit 1
```

---

`scripts/__fixtures__/hooks/post-stop/phpcs-strict-clean/stdin.json`:
```json
{}
```

`scripts/__fixtures__/hooks/post-stop/phpcs-strict-clean/expected-exit`:
```
0
```

`scripts/__fixtures__/hooks/post-stop/phpcs-strict-clean/expected-stdout-absent`:
```
block
```

`scripts/__fixtures__/hooks/post-stop/phpcs-strict-clean/env.json`:
```json
{
  "SUPERPOWERS_SAGE_QUALITY_GATE": "strict",
  "SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null",
  "PATH_PREPEND": "scripts/__fixtures__/hooks/post-stop/phpcs-strict-clean/bin"
}
```

`scripts/__fixtures__/hooks/post-stop/phpcs-strict-clean/bin/lando` (mock — PHPCS passes):
```bash
#!/usr/bin/env bash
exit 0
```

---

`scripts/__fixtures__/hooks/post-stop/phpcs-warn-errors/stdin.json`:
```json
{}
```

`scripts/__fixtures__/hooks/post-stop/phpcs-warn-errors/expected-exit`:
```
0
```

`scripts/__fixtures__/hooks/post-stop/phpcs-warn-errors/expected-stdout-absent`:
```
block
```

`scripts/__fixtures__/hooks/post-stop/phpcs-warn-errors/env.json`:
```json
{
  "SUPERPOWERS_SAGE_QUALITY_GATE": "warn",
  "SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null",
  "PATH_PREPEND": "scripts/__fixtures__/hooks/post-stop/phpcs-warn-errors/bin"
}
```

`scripts/__fixtures__/hooks/post-stop/phpcs-warn-errors/bin/lando` (mock — PHPCS errors):
```bash
#!/usr/bin/env bash
echo "FOUND 1 ERROR affecting 1 file"
exit 1
```

---

`scripts/__fixtures__/hooks/post-stop/quality-gate-no-lando/stdin.json`:
```json
{}
```

`scripts/__fixtures__/hooks/post-stop/quality-gate-no-lando/expected-exit`:
```
0
```

`scripts/__fixtures__/hooks/post-stop/quality-gate-no-lando/expected-stdout-absent`:
```
block
```

`scripts/__fixtures__/hooks/post-stop/quality-gate-no-lando/env.json`:
```json
{
  "SUPERPOWERS_SAGE_QUALITY_GATE": "strict",
  "SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null",
  "PATH": "/usr/bin:/bin"
}
```

- [ ] **Step 2: Make mock lando scripts executable**

```bash
chmod +x \
  scripts/__fixtures__/hooks/post-stop/phpcs-strict-errors/bin/lando \
  scripts/__fixtures__/hooks/post-stop/phpcs-strict-clean/bin/lando \
  scripts/__fixtures__/hooks/post-stop/phpcs-warn-errors/bin/lando
```

- [ ] **Step 3: Run harness — confirm new cases fail (hook not updated yet)**

```bash
node scripts/test-hooks.mjs 2>&1 | grep -E "(post-stop|tests:)"
```

Expected: the 3 quality-gate fixtures that expect block/strict behaviour fail; `no-plans-dir` still passes.

- [ ] **Step 4: Rewrite `hooks/post-stop.sh`**

```bash
#!/usr/bin/env bash
# Stop hook: optional PHPCS quality gate + session end logging.
# SUPERPOWERS_SAGE_QUALITY_GATE=strict|warn|off (default: warn)

set -uo pipefail

HOOK_NAME="post-stop"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

QUALITY_GATE="${SUPERPOWERS_SAGE_QUALITY_GATE:-warn}"

# --- PHPCS Quality Gate ---
if [ "$QUALITY_GATE" != "off" ] && command -v lando >/dev/null 2>&1; then
  PHPCS_OUTPUT=""
  PHPCS_EXIT=0
  PHPCS_OUTPUT=$(lando phpcs 2>&1) || PHPCS_EXIT=$?

  if [ "$PHPCS_EXIT" -ne 0 ]; then
    if [ "$QUALITY_GATE" = "strict" ]; then
      hook_error "PHPCS gate: errors found (strict mode — blocking)"
      SAFE_OUTPUT="$(echo "$PHPCS_OUTPUT" | head -10 | tr '"' "'" | tr '\n' ' ')"
      printf '{"decision":"block","reason":"PHPCS errors found. Fix before completing: %s"}\n' "$SAFE_OUTPUT"
      exit 2
    else
      hook_warn "PHPCS gate: errors found (warn mode — not blocking)"
    fi
  else
    hook_info "PHPCS gate: clean"
  fi
fi

# --- Session end logging ---
PLANS_DIR="./docs/plans"
if [ ! -d "$PLANS_DIR" ]; then
  hook_warn "No plans directory; skipping session logging"
  exit 0
fi

for dir in $(ls -1d "${PLANS_DIR}"/*/ 2>/dev/null | sort -r); do
  plan_file="${dir}plan.md"
  [ -f "$plan_file" ] || continue

  if grep -q "status: in-progress" "$plan_file" 2>/dev/null; then
    LOG_DIR="${dir}logs"
    mkdir -p "$LOG_DIR" 2>/dev/null || {
      hook_error "Could not create log directory at $LOG_DIR"
      exit 0
    }

    TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "$(date)")
    echo "[$TIMESTAMP] Session ended" >> "${LOG_DIR}/activity.log"
    hook_info "Session end logged to ${LOG_DIR}/activity.log"
    exit 0
  fi
done

hook_warn "No active plan (status: in-progress) found; session not logged"
exit 0
```

- [ ] **Step 5: Run harness — all post-stop cases pass**

```bash
node scripts/test-hooks.mjs
```

Expected: all post-stop cases pass. Total at this point: 16 tests (2 + 5 new post-stop + 8 user-prompt-activate + 1 original no-plans-dir), 0 failed.

- [ ] **Step 6: Commit**

```bash
git add hooks/post-stop.sh scripts/__fixtures__/hooks/post-stop/
git commit -m "feat(hooks): add PHPCS quality gate to Stop hook (MP 3.3)"
```

---

## Task 5 — PreToolUse protected-path hook (MP 3.4)

**Files:**
- Create: `hooks/pre-write-protected.sh`
- Create: `scripts/__fixtures__/hooks/pre-write-protected/` (8 fixture cases)
- Modify: `hooks/hooks.json` (add second PreToolUse entry for Write|Edit)
- Run: `node scripts/sync-cursor-hooks.mjs`

**Hook contract:**
- Reads stdin JSON: `{"tool_name":"Write","tool_input":{"file_path":"..."}}`
- Blocked patterns: `.env`, `.env.*` (except `.env.example`), `wp-config.php`, `bedrock/config/environments/*.php`, `trellis/group_vars/*/vault.yml`
- On match: stdout `{"decision":"block","reason":"Protected file: <path>. Use ansible-vault edit or Bedrock .env pattern instead."}`, exit 2.
- No match: exit 0, no stdout.

**Fixture cases:**

| Case | file_path | Expected exit | Stdout contains | Stdout absent |
|---|---|---|---|---|
| `env-block` | `.env` | 2 | block | — |
| `env-dotted-block` | `.env.production` | 2 | block | — |
| `env-example-allow` | `.env.example` | 0 | — | block |
| `wpconfig-block` | `wp-config.php` | 2 | block | — |
| `bedrock-env-block` | `bedrock/config/environments/production.php` | 2 | block | — |
| `trellis-vault-block` | `trellis/group_vars/production/vault.yml` | 2 | block | — |
| `regular-php-allow` | `app/Models/Post.php` | 0 | — | block |
| `edit-tool-env-block` | `.env` (tool_name=Edit) | 2 | block | — |

- [ ] **Step 1: Create fixture directories and files**

```bash
mkdir -p scripts/__fixtures__/hooks/pre-write-protected/{env-block,env-dotted-block,env-example-allow,wpconfig-block,bedrock-env-block,trellis-vault-block,regular-php-allow,edit-tool-env-block}
```

`scripts/__fixtures__/hooks/pre-write-protected/env-block/stdin.json`:
```json
{"tool_name": "Write", "tool_input": {"file_path": "/project/.env"}}
```

`scripts/__fixtures__/hooks/pre-write-protected/env-block/expected-exit`:
```
2
```

`scripts/__fixtures__/hooks/pre-write-protected/env-block/expected-stdout`:
```
block
```

`scripts/__fixtures__/hooks/pre-write-protected/env-block/env.json`:
```json
{"SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"}
```

---

`scripts/__fixtures__/hooks/pre-write-protected/env-dotted-block/stdin.json`:
```json
{"tool_name": "Write", "tool_input": {"file_path": "/project/.env.production"}}
```

`scripts/__fixtures__/hooks/pre-write-protected/env-dotted-block/expected-exit`:
```
2
```

`scripts/__fixtures__/hooks/pre-write-protected/env-dotted-block/expected-stdout`:
```
block
```

`scripts/__fixtures__/hooks/pre-write-protected/env-dotted-block/env.json`:
```json
{"SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"}
```

---

`scripts/__fixtures__/hooks/pre-write-protected/env-example-allow/stdin.json`:
```json
{"tool_name": "Write", "tool_input": {"file_path": "/project/.env.example"}}
```

`scripts/__fixtures__/hooks/pre-write-protected/env-example-allow/expected-exit`:
```
0
```

`scripts/__fixtures__/hooks/pre-write-protected/env-example-allow/expected-stdout-absent`:
```
block
```

`scripts/__fixtures__/hooks/pre-write-protected/env-example-allow/env.json`:
```json
{"SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"}
```

---

`scripts/__fixtures__/hooks/pre-write-protected/wpconfig-block/stdin.json`:
```json
{"tool_name": "Write", "tool_input": {"file_path": "/project/web/wp/wp-config.php"}}
```

`scripts/__fixtures__/hooks/pre-write-protected/wpconfig-block/expected-exit`:
```
2
```

`scripts/__fixtures__/hooks/pre-write-protected/wpconfig-block/expected-stdout`:
```
block
```

`scripts/__fixtures__/hooks/pre-write-protected/wpconfig-block/env.json`:
```json
{"SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"}
```

---

`scripts/__fixtures__/hooks/pre-write-protected/bedrock-env-block/stdin.json`:
```json
{"tool_name": "Write", "tool_input": {"file_path": "/project/bedrock/config/environments/production.php"}}
```

`scripts/__fixtures__/hooks/pre-write-protected/bedrock-env-block/expected-exit`:
```
2
```

`scripts/__fixtures__/hooks/pre-write-protected/bedrock-env-block/expected-stdout`:
```
block
```

`scripts/__fixtures__/hooks/pre-write-protected/bedrock-env-block/env.json`:
```json
{"SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"}
```

---

`scripts/__fixtures__/hooks/pre-write-protected/trellis-vault-block/stdin.json`:
```json
{"tool_name": "Write", "tool_input": {"file_path": "/project/trellis/group_vars/production/vault.yml"}}
```

`scripts/__fixtures__/hooks/pre-write-protected/trellis-vault-block/expected-exit`:
```
2
```

`scripts/__fixtures__/hooks/pre-write-protected/trellis-vault-block/expected-stdout`:
```
block
```

`scripts/__fixtures__/hooks/pre-write-protected/trellis-vault-block/env.json`:
```json
{"SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"}
```

---

`scripts/__fixtures__/hooks/pre-write-protected/regular-php-allow/stdin.json`:
```json
{"tool_name": "Write", "tool_input": {"file_path": "/project/app/Models/Post.php"}}
```

`scripts/__fixtures__/hooks/pre-write-protected/regular-php-allow/expected-exit`:
```
0
```

`scripts/__fixtures__/hooks/pre-write-protected/regular-php-allow/expected-stdout-absent`:
```
block
```

`scripts/__fixtures__/hooks/pre-write-protected/regular-php-allow/env.json`:
```json
{"SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"}
```

---

`scripts/__fixtures__/hooks/pre-write-protected/edit-tool-env-block/stdin.json`:
```json
{"tool_name": "Edit", "tool_input": {"file_path": "/project/.env"}}
```

`scripts/__fixtures__/hooks/pre-write-protected/edit-tool-env-block/expected-exit`:
```
2
```

`scripts/__fixtures__/hooks/pre-write-protected/edit-tool-env-block/expected-stdout`:
```
block
```

`scripts/__fixtures__/hooks/pre-write-protected/edit-tool-env-block/env.json`:
```json
{"SUPERPOWERS_SAGE_HOOK_LOG": "/dev/null"}
```

- [ ] **Step 2: Run harness — confirm new cases fail (hook missing)**

```bash
node scripts/test-hooks.mjs 2>&1 | grep -E "(pre-write-protected|tests:)"
```

Expected: 8 `⚠️  hook not found` lines. Total test count unchanged.

- [ ] **Step 3: Create `hooks/pre-write-protected.sh`**

```bash
#!/usr/bin/env bash
# PreToolUse hook: block writes/edits to protected Bedrock/Trellis files.
# Output: {"decision":"block","reason":"..."} + exit 2 for protected paths.

set -uo pipefail

HOOK_NAME="pre-write-protected"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

INPUT="$(cat)"

# Extract file_path from nested tool_input object
FILE_PATH="$(echo "$INPUT" | grep -o '"file_path":[[:space:]]*"[^"]*"' | head -1 \
  | sed 's/"file_path":[[:space:]]*"//' | sed 's/"$//')"

[ -z "$FILE_PATH" ] && exit 0

BASENAME="$(basename "$FILE_PATH")"

is_protected() {
  local path="$1"
  local base="$2"

  # .env.example is explicitly allowed
  [ "$base" = ".env.example" ] && return 1

  # .env (exact) or .env.* (dotenv variants)
  [[ "$base" = ".env" || "$base" = .env.* ]] && return 0

  # wp-config.php
  [ "$base" = "wp-config.php" ] && return 0

  # bedrock/config/environments/*.php
  echo "$path" | grep -qE 'bedrock/config/environments/[^/]+\.php$' && return 0

  # trellis/group_vars/*/vault.yml
  echo "$path" | grep -qE 'trellis/group_vars/[^/]+/vault\.yml$' && return 0

  return 1
}

if is_protected "$FILE_PATH" "$BASENAME"; then
  REASON="Protected file: ${FILE_PATH}. Use ansible-vault edit or the Bedrock .env pattern instead."
  printf '{"decision":"block","reason":"%s"}\n' "$REASON"
  hook_info "Blocked write to protected file: $FILE_PATH"
  exit 2
fi

exit 0
```

- [ ] **Step 4: Make executable and run the harness**

```bash
chmod +x hooks/pre-write-protected.sh
node scripts/test-hooks.mjs
```

Expected: all 8 pre-write-protected cases pass. Running total: all tests pass.

- [ ] **Step 5: Add PreToolUse Write|Edit entry to `hooks/hooks.json`**

Add a second entry in the `PreToolUse` array (after the existing Bash entry):

```json
"PreToolUse": [
  {
    "matcher": "Bash",
    "hooks": [
      {
        "type": "command",
        "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/pre-commit.sh\""
      }
    ]
  },
  {
    "matcher": "Write|Edit",
    "hooks": [
      {
        "type": "command",
        "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/pre-write-protected.sh\""
      }
    ]
  }
]
```

- [ ] **Step 6: Sync to cursor-hooks.json**

```bash
node scripts/sync-cursor-hooks.mjs
```

Verify `cursor-hooks.json` now includes the Write|Edit PreToolUse entry.

- [ ] **Step 7: Commit**

```bash
git add hooks/pre-write-protected.sh hooks/hooks.json hooks/cursor-hooks.json \
  scripts/__fixtures__/hooks/pre-write-protected/
git commit -m "feat(hooks): add PreToolUse protected-path blocking hook (MP 3.4)"
```

---

## Task 6 — Final validation and index update (MP 3.6)

**Files:**
- Modify: `docs/superpowers/plans/2026-04-18-plugin-expansion-index.md` (Onda 3 status → Done)

- [ ] **Step 1: Run full test suite**

```bash
node scripts/test-hooks.mjs && \
node scripts/test-validate-skills.mjs && \
node scripts/test-detect-sage-project.mjs && \
node scripts/test-detect-design-tools.mjs
```

Expected: all suites exit 0. Note the total hook test count for the update.

- [ ] **Step 2: Verify hooks.json has all three new entries**

```bash
node -e "
const h = JSON.parse(require('fs').readFileSync('hooks/hooks.json','utf8')).hooks;
const checks = [
  ['UserPromptSubmit', !!h.UserPromptSubmit],
  ['PreToolUse Write|Edit', h.PreToolUse?.some(e => e.matcher === 'Write|Edit')],
  ['Stop', !!h.Stop],
];
checks.forEach(([k,v]) => console.log((v?'✅':'❌') + ' ' + k));
"
```

Expected: all three lines show ✅.

- [ ] **Step 3: Verify commands directory**

```bash
ls commands/
```

Expected: `acf-register.md  livewire-new.md  sage-status.md`

- [ ] **Step 4: Update master index — Onda 3 status to Done**

In `docs/superpowers/plans/2026-04-18-plugin-expansion-index.md`, change the Onda 3 row from:

```
| 3 — New deterministic capabilities | [onda-3](2026-04-18-plugin-expansion-onda-3.md) | 4 | Ready (full TDD) |
```

to:

```
| 3 — New deterministic capabilities | [onda-3](2026-04-18-plugin-expansion-onda-3.md) | 6 | Done |
```

(Microplan count is 6, not 4, because we added MP 3.5 harness and MP 3.6 validation.)

- [ ] **Step 5: Final commit**

```bash
git add docs/superpowers/plans/2026-04-18-plugin-expansion-index.md
git commit -m "docs(plans): mark Onda 3 done in master index (MP 3.6)"
```
