# Plugin Expansion — Onda 5 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate the official Roots/WordPress AI stack (Acorn AI + WP MCP Adapter) into the plugin so Claude queries real project state via MCP before generating code.

**Architecture:** A readiness probe (5.1) feeds a guided install skill (5.2) and a `.mcp.json` generator (5.3). An Abilities authoring skill (5.4) teaches creating custom MCP endpoints. A shared query-first reference (5.5) wires the pattern into four existing skills.

**Tech Stack:** Node.js (`.mjs`), bash, Composer (via Lando), `.mcp.json` schema, WP 6.9 Abilities API, `roots/acorn-ai`, `wordpress/mcp-adapter` (stdio transport).

**Source spec:** `docs/superpowers/specs/2026-04-18-plugin-expansion-design.md`

---

## File map

| File | Action |
|---|---|
| `scripts/detect-ai-readiness.mjs` | Create — readiness probe |
| `scripts/test-detect-ai-readiness.mjs` | Create — test suite |
| `templates/project-mcp.json.tpl` | Create — MCP config template |
| `scripts/generate-project-mcp.mjs` | Create — merge generator |
| `skills/ai-setup/SKILL.md` | Create — guided install skill |
| `skills/ai-setup/references/install-steps.md` | Create |
| `skills/ai-setup/references/rollback.md` | Create |
| `scripts/install-ai-stack.sh` | Create — lando installer |
| `skills/abilities-authoring/SKILL.md` | Create — Abilities skill |
| `skills/abilities-authoring/references/registration.md` | Create |
| `skills/abilities-authoring/references/schema.md` | Create |
| `skills/abilities-authoring/references/mcp-exposure.md` | Create |
| `skills/abilities-authoring/references/patterns.md` | Create |
| `scripts/create-ability.sh` | Create |
| `scripts/list-abilities.sh` | Create |
| `assets/ability-query-content.php.tpl` | Create |
| `assets/ability-crud.php.tpl` | Create |
| `assets/ability-search.php.tpl` | Create |
| `skills/sageing/references/mcp-query-patterns.md` | Modify — expand placeholder |
| `skills/acorn-livewire/SKILL.md` | Modify — add query-first section |
| `skills/acorn-routes/SKILL.md` | Modify — add query-first section |
| `skills/modeling/SKILL.md` | Modify — add query-first section |
| `skills/building/SKILL.md` | Modify — add query-first section |
| `hooks/user-prompt-activate.sh` | Modify — add ai-setup + abilities keywords |
| `docs/superpowers/plans/2026-04-18-plugin-expansion-index.md` | Modify — mark Wave 5 Done |

---

### Task 1: `scripts/detect-ai-readiness.mjs` (MP 5.1)

**Files:**
- Create: `scripts/detect-ai-readiness.mjs`

The probe takes `--path <user-project-root>` (defaults to `cwd`). It checks five things: WP version via `lando wp core version`, package presence in `composer.lock`/`composer.json`, API keys in `.env`, and running MCP servers via `lando wp mcp-adapter list`. Outputs JSON to stdout, exits 0 always.

- [ ] **Step 1: Create `scripts/detect-ai-readiness.mjs`**

```javascript
#!/usr/bin/env node

import { readFileSync, existsSync } from 'fs';
import { join, resolve } from 'path';
import { spawnSync } from 'child_process';

const args = process.argv.slice(2);
const pathFlag = args.indexOf('--path');
const projectRoot = resolve(
  pathFlag !== -1 && args[pathFlag + 1] ? args[pathFlag + 1] : process.cwd()
);

function readJSON(filePath) {
  try { return JSON.parse(readFileSync(filePath, 'utf8')); } catch { return null; }
}

function checkPackage(root, packageName) {
  const lock = readJSON(join(root, 'composer.lock'));
  if (lock?.packages) {
    const pkg = lock.packages.find(p => p.name === packageName);
    if (pkg) return pkg.version;
  }
  const composer = readJSON(join(root, 'composer.json'));
  return composer?.require?.[packageName]
    ?? composer?.['require-dev']?.[packageName]
    ?? null;
}

function checkApiKeys(root) {
  const envPath = join(root, '.env');
  if (!existsSync(envPath)) return [];
  const content = readFileSync(envPath, 'utf8');
  return ['ANTHROPIC_API_KEY', 'OPENAI_API_KEY', 'GEMINI_API_KEY'].filter(key => {
    const match = content.match(new RegExp(`^${key}=(.+)$`, 'm'));
    const val = match?.[1]?.trim() ?? '';
    return val && val !== '""' && val !== "''";
  });
}

function runLando(landoArgs, cwd) {
  const result = spawnSync('lando', landoArgs, {
    cwd,
    encoding: 'utf8',
    timeout: 15000,
  });
  if (result.error) return { ok: false, stdout: '', error: result.error.message };
  return { ok: result.status === 0, stdout: result.stdout?.trim() ?? '' };
}

function versionAtLeast(versionStr, major, minor) {
  const parts = (versionStr ?? '').split('.').map(Number);
  if (parts[0] !== major) return parts[0] > major;
  return (parts[1] ?? 0) >= minor;
}

function checkMcpServers(root) {
  const result = runLando(['wp', 'mcp-adapter', 'list', '--format=json'], root);
  if (!result.ok) return null;
  try {
    const data = JSON.parse(result.stdout);
    return Array.isArray(data) ? data.map(s => s.name ?? String(s)) : [];
  } catch {
    return result.stdout.split('\n').map(s => s.trim()).filter(Boolean);
  }
}

// --- main ---
const missing = [];
const upgradePath = [];

// 1. WP version
const wpResult = runLando(['wp', 'core', 'version'], projectRoot);
const landoAvailable = !wpResult.error?.includes('ENOENT');
const wpVersion = wpResult.ok ? wpResult.stdout : null;

if (!landoAvailable) {
  missing.push('lando-not-found');
  upgradePath.push('Install Lando: https://lando.dev/install');
} else if (!wpVersion || !versionAtLeast(wpVersion, 6, 9)) {
  missing.push('wp-core<6.9');
  upgradePath.push('lando composer update roots/wordpress --with-all-dependencies');
}

// 2. Packages
const acornAiVersion = checkPackage(projectRoot, 'roots/acorn-ai');
const mcpAdapterVersion = checkPackage(projectRoot, 'wordpress/mcp-adapter');

if (!acornAiVersion) {
  missing.push('acorn-ai');
  upgradePath.push('lando composer require roots/acorn-ai');
  upgradePath.push('lando wp acorn vendor:publish --tag=acorn-ai');
}
if (!mcpAdapterVersion) {
  missing.push('mcp-adapter');
  upgradePath.push('lando composer require wordpress/mcp-adapter');
}

// 3. API keys
const apiKeysPresent = checkApiKeys(projectRoot);
if (apiKeysPresent.length === 0) {
  missing.push('api-key');
  upgradePath.push('Add ANTHROPIC_API_KEY=<key> to your project .env');
}

// 4. MCP servers
const mcpServers = landoAvailable ? checkMcpServers(projectRoot) : null;
if (mcpServers === null && landoAvailable) {
  missing.push('mcp-server-not-running');
  upgradePath.push('lando wp mcp-adapter serve --server=mcp-adapter-default-server');
}

const packages = {};
if (acornAiVersion) packages['acorn-ai'] = acornAiVersion;
if (mcpAdapterVersion) packages['mcp-adapter'] = mcpAdapterVersion;

const result = {
  ready: missing.length === 0,
  wp_version: wpVersion,
  packages,
  api_keys_present: apiKeysPresent,
  mcp_servers: mcpServers ?? [],
  missing,
  upgrade_path: upgradePath,
};

process.stdout.write(JSON.stringify(result, null, 2) + '\n');
```

- [ ] **Step 2: Verify it runs without error on this plugin repo (not a Sage project — expect `ready: false`)**

```bash
node scripts/detect-ai-readiness.mjs --path .
```

Expected: valid JSON with `"ready": false` and `"missing"` containing `"lando-not-found"` or `"wp-core<6.9"`.

- [ ] **Step 3: Commit**

```bash
git add scripts/detect-ai-readiness.mjs
git commit -m "feat(scripts): add detect-ai-readiness probe (MP 5.1)"
```

---

### Task 2: Test suite for `detect-ai-readiness.mjs`

**Files:**
- Create: `scripts/test-detect-ai-readiness.mjs`

Five scenarios. Each creates a tmpdir with a mock `lando` shell script in `tmpdir/bin/` (chmod +x) and a project fixture (composer.json, .env). Tests use `spawnSync` with `PATH` prepended to `tmpdir/bin/`.

- [ ] **Step 1: Write the failing test stubs (run → all FAIL)**

Create `scripts/test-detect-ai-readiness.mjs`:

```javascript
#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync, chmodSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCRIPT = resolve(__dirname, 'detect-ai-readiness.mjs');

let passed = 0;
let failed = 0;

function assert(label, condition, details) {
  if (condition) { console.log(`  ✅ ${label}`); passed++; }
  else { console.log(`  ❌ ${label}`); if (details) console.log(`     ${details}`); failed++; }
}

function makeLando(dir, wpVersion, mcpServers) {
  const binDir = join(dir, 'bin');
  mkdirSync(binDir, { recursive: true });
  const mcpOutput = JSON.stringify((mcpServers ?? []).map(n => ({ name: n })));
  const script = `#!/bin/bash
SUBCMD="$1 $2 $3"
if [[ "$SUBCMD" == "wp core version" ]]; then
  echo "${wpVersion}"
  exit 0
fi
if [[ "$1 $2 $3 $4" == "wp mcp-adapter list --format=json" ]]; then
  echo '${mcpOutput}'
  exit ${mcpServers === null ? 1 : 0}
fi
exit 0
`;
  const landoPath = join(binDir, 'lando');
  writeFileSync(landoPath, script.replace('${wpVersion}', wpVersion ?? '6.9.1')
    .replace('${mcpOutput}', mcpServers ? mcpOutput : '[]')
    .replace('${mcpServers === null ? 1 : 0}', mcpServers === null ? '1' : '0'));
  chmodSync(landoPath, 0o755);
  return binDir;
}

function makeComposerLock(dir, packages) {
  const lock = { packages: packages.map(([name, version]) => ({ name, version })) };
  writeFileSync(join(dir, 'composer.lock'), JSON.stringify(lock));
}

function makeEnv(dir, keys) {
  const content = keys.map(k => `${k}=sk-test-key`).join('\n') + '\n';
  writeFileSync(join(dir, '.env'), content);
}

function run(projectDir, binDir) {
  const env = { ...process.env, PATH: `${binDir}:${process.env.PATH}` };
  const result = spawnSync('node', [SCRIPT, '--path', projectDir], { encoding: 'utf8', env });
  try {
    return { exit: result.status, data: JSON.parse(result.stdout.trim() || '{}'), stderr: result.stderr };
  } catch (e) {
    return { exit: result.status, data: null, error: e.message, raw: result.stdout };
  }
}

// --- scenarios ---

console.log('\n🔍 detect-ai-readiness test suite\n');

// Scenario 1: fully ready
{
  console.log('Scenario 1: fully-ready');
  const dir = mkdtempSync(join(tmpdir(), 'ai-ready-'));
  const binDir = makeLando(dir, '6.9.1', ['mcp-adapter-default-server']);
  makeComposerLock(dir, [['roots/acorn-ai', '1.0.0'], ['wordpress/mcp-adapter', '0.4.0']]);
  makeEnv(dir, ['ANTHROPIC_API_KEY']);
  const { data } = run(dir, binDir);
  assert('ready: true', data?.ready === true, JSON.stringify(data));
  assert('wp_version 6.9.1', data?.wp_version === '6.9.1');
  assert('packages.acorn-ai present', data?.packages?.['acorn-ai'] === '1.0.0');
  assert('packages.mcp-adapter present', data?.packages?.['mcp-adapter'] === '0.4.0');
  assert('api_keys_present includes ANTHROPIC_API_KEY', data?.api_keys_present?.includes('ANTHROPIC_API_KEY'));
  assert('mcp_servers populated', data?.mcp_servers?.length > 0);
  assert('missing is empty', data?.missing?.length === 0);
  rmSync(dir, { recursive: true, force: true });
}

// Scenario 2: missing acorn-ai
{
  console.log('\nScenario 2: missing-acorn-ai');
  const dir = mkdtempSync(join(tmpdir(), 'ai-ready-'));
  const binDir = makeLando(dir, '6.9.1', ['mcp-adapter-default-server']);
  makeComposerLock(dir, [['wordpress/mcp-adapter', '0.4.0']]);
  makeEnv(dir, ['ANTHROPIC_API_KEY']);
  const { data } = run(dir, binDir);
  assert('ready: false', data?.ready === false);
  assert('missing includes acorn-ai', data?.missing?.includes('acorn-ai'));
  assert('upgrade_path mentions composer require', data?.upgrade_path?.some(s => s.includes('roots/acorn-ai')));
  rmSync(dir, { recursive: true, force: true });
}

// Scenario 3: missing api-key
{
  console.log('\nScenario 3: missing-api-key');
  const dir = mkdtempSync(join(tmpdir(), 'ai-ready-'));
  const binDir = makeLando(dir, '6.9.1', ['mcp-adapter-default-server']);
  makeComposerLock(dir, [['roots/acorn-ai', '1.0.0'], ['wordpress/mcp-adapter', '0.4.0']]);
  writeFileSync(join(dir, '.env'), 'APP_ENV=local\n');
  const { data } = run(dir, binDir);
  assert('ready: false', data?.ready === false);
  assert('missing includes api-key', data?.missing?.includes('api-key'));
  assert('api_keys_present is empty', data?.api_keys_present?.length === 0);
  rmSync(dir, { recursive: true, force: true });
}

// Scenario 4: WP too old
{
  console.log('\nScenario 4: wp-too-old');
  const dir = mkdtempSync(join(tmpdir(), 'ai-ready-'));
  const binDir = makeLando(dir, '6.8.0', ['mcp-adapter-default-server']);
  makeComposerLock(dir, [['roots/acorn-ai', '1.0.0'], ['wordpress/mcp-adapter', '0.4.0']]);
  makeEnv(dir, ['ANTHROPIC_API_KEY']);
  const { data } = run(dir, binDir);
  assert('ready: false', data?.ready === false);
  assert('missing includes wp-core<6.9', data?.missing?.includes('wp-core<6.9'));
  assert('wp_version is 6.8.0', data?.wp_version === '6.8.0');
  rmSync(dir, { recursive: true, force: true });
}

// Scenario 5: no lando
{
  console.log('\nScenario 5: no-lando');
  const dir = mkdtempSync(join(tmpdir(), 'ai-ready-'));
  const emptyBin = mkdtempSync(join(tmpdir(), 'empty-bin-'));
  makeComposerLock(dir, [['roots/acorn-ai', '1.0.0'], ['wordpress/mcp-adapter', '0.4.0']]);
  makeEnv(dir, ['ANTHROPIC_API_KEY']);
  const env = { ...process.env, PATH: emptyBin };
  const result = spawnSync('node', [SCRIPT, '--path', dir], { encoding: 'utf8', env });
  let data;
  try { data = JSON.parse(result.stdout.trim() || '{}'); } catch { data = null; }
  assert('exits 0 (never throws)', result.status === 0, result.stderr);
  assert('ready: false', data?.ready === false);
  assert('missing includes lando-not-found', data?.missing?.includes('lando-not-found'));
  rmSync(dir, { recursive: true, force: true });
  rmSync(emptyBin, { recursive: true, force: true });
}

console.log(`\nResults: ${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
```

- [ ] **Step 2: Run tests — expect failures (script not fully handling all edge cases yet)**

```bash
node scripts/test-detect-ai-readiness.mjs
```

Expected: some assertions fail (lando mock shell scripts may need platform adjustment).

- [ ] **Step 3: Fix any issues in `detect-ai-readiness.mjs` until all 5 scenarios pass**

Run after each fix:
```bash
node scripts/test-detect-ai-readiness.mjs
```

Expected: `5 scenarios, N passed, 0 failed`

- [ ] **Step 4: Commit**

```bash
git add scripts/test-detect-ai-readiness.mjs
git commit -m "test(scripts): add test suite for detect-ai-readiness (5 scenarios)"
```

---

### Task 3: `.mcp.json` template + generator (MP 5.3)

**Files:**
- Create: `templates/project-mcp.json.tpl`
- Create: `scripts/generate-project-mcp.mjs`

The generator takes `--path <user-project-root>`, reads existing `.mcp.json` if present, merges the `mcpServers.wordpress` entry non-destructively, and writes back.

- [ ] **Step 1: Create `templates/` directory and template**

```bash
mkdir -p templates
```

Create `templates/project-mcp.json.tpl`:

```json
{
  "mcpServers": {
    "wordpress": {
      "command": "lando",
      "args": [
        "wp",
        "mcp-adapter",
        "serve",
        "--server=mcp-adapter-default-server",
        "--user=admin"
      ]
    }
  }
}
```

- [ ] **Step 2: Create `scripts/generate-project-mcp.mjs`**

```javascript
#!/usr/bin/env node

import { readFileSync, writeFileSync, existsSync } from 'fs';
import { join, resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const TPL_PATH = resolve(__dirname, '../templates/project-mcp.json.tpl');

const args = process.argv.slice(2);
const pathFlag = args.indexOf('--path');
const projectRoot = resolve(
  pathFlag !== -1 && args[pathFlag + 1] ? args[pathFlag + 1] : process.cwd()
);
const dryRun = args.includes('--dry-run');

const template = JSON.parse(readFileSync(TPL_PATH, 'utf8'));
const outputPath = join(projectRoot, '.mcp.json');

let existing = {};
if (existsSync(outputPath)) {
  try { existing = JSON.parse(readFileSync(outputPath, 'utf8')); } catch { /* start fresh */ }
}

const merged = {
  ...existing,
  mcpServers: {
    ...existing.mcpServers,
    ...template.mcpServers,
  },
};

const output = JSON.stringify(merged, null, 2) + '\n';

if (dryRun) {
  process.stdout.write(output);
} else {
  writeFileSync(outputPath, output);
  process.stderr.write(`Wrote ${outputPath}\n`);
}
```

- [ ] **Step 3: Test — dry-run on empty dir**

```bash
node scripts/generate-project-mcp.mjs --path /tmp --dry-run
```

Expected: JSON with `mcpServers.wordpress` entry.

- [ ] **Step 4: Test — dry-run on dir with existing `.mcp.json`**

```bash
echo '{"mcpServers":{"other":{"command":"npx","args":["other-server"]}}}' > /tmp/test-mcp.json
node scripts/generate-project-mcp.mjs --path /tmp --dry-run
```

Expected: JSON with both `mcpServers.wordpress` AND `mcpServers.other` preserved.

- [ ] **Step 5: Commit**

```bash
git add templates/project-mcp.json.tpl scripts/generate-project-mcp.mjs
git commit -m "feat(scripts,templates): add .mcp.json template + merge generator (MP 5.3)"
```

---

### Task 4: `skills/ai-setup/` — guided install skill (MP 5.2)

**Files:**
- Create: `skills/ai-setup/SKILL.md`
- Create: `skills/ai-setup/references/install-steps.md`
- Create: `skills/ai-setup/references/rollback.md`
- Create: `scripts/install-ai-stack.sh`
- Modify: `hooks/user-prompt-activate.sh` (add ai-setup keywords)

The skill reads the detect-ai-readiness output, branches by gap, and guides the user through each fix step by step.

- [ ] **Step 1: Create `scripts/install-ai-stack.sh`**

```bash
#!/usr/bin/env bash
# Installs roots/acorn-ai + wordpress/mcp-adapter in the current Lando project.
# Usage: bash scripts/install-ai-stack.sh [--project-path /path/to/project]
set -e

PROJECT_PATH="${1:-$(pwd)}"
if [[ "$1" == "--project-path" ]]; then
  PROJECT_PATH="$2"
fi

cd "$PROJECT_PATH"

echo "==> Installing roots/acorn-ai + wordpress/mcp-adapter..."
lando composer require roots/acorn-ai wordpress/mcp-adapter

echo "==> Publishing Acorn AI config..."
lando wp acorn vendor:publish --tag=acorn-ai

echo "==> Done. Next: add ANTHROPIC_API_KEY (or OPENAI_API_KEY) to your .env"
echo "    Then run: node <plugin-path>/scripts/generate-project-mcp.mjs --path ."
```

- [ ] **Step 2: Create `skills/ai-setup/SKILL.md`**

```markdown
---
name: superpowers-sage:ai-setup
description: >
  Guided installation of the Roots AI stack (roots/acorn-ai + wordpress/mcp-adapter) in a
  Sage/Bedrock project via Lando. Runs detect-ai-readiness probe, identifies gaps, installs
  missing packages, publishes Acorn AI config, writes API key to .env, generates .mcp.json,
  validates MCP handshake via discover-abilities. Invoke for: ai-setup, install acorn ai,
  mcp adapter, install mcp, setup mcp, ai stack, discover-abilities not working,
  wordpress mcp, acorn-ai setup.
---

# /ai-setup — Guided AI Stack Installation

This skill installs and validates the Roots AI stack in your Sage/Bedrock project.

## What it installs

| Package | Purpose |
|---|---|
| `roots/acorn-ai` | Laravel AI SDK bridge for Acorn |
| `wordpress/mcp-adapter` | Exposes WP site via Model Context Protocol (stdio) |

**Prerequisite:** WordPress ≥ 6.9, Lando running.

## Step 1 — Run readiness probe

```bash
node <plugin-scripts-path>/detect-ai-readiness.mjs --path .
```

Read the `missing` array. Proceed through only the steps that apply.

## Step 2 — Install packages (if `missing` includes `acorn-ai` or `mcp-adapter`)

Show the user the commands and ask for confirmation before running:

```bash
lando composer require roots/acorn-ai wordpress/mcp-adapter
lando wp acorn vendor:publish --tag=acorn-ai
```

See [`references/install-steps.md`](references/install-steps.md) for full install details.

## Step 3 — Add API key (if `missing` includes `api-key`)

Ask the user which provider they want to use:
- Anthropic → `ANTHROPIC_API_KEY`
- OpenAI → `OPENAI_API_KEY`

**Do not write the key yourself.** Show the exact line to add to `.env`:

```
ANTHROPIC_API_KEY=<paste-your-key-here>
```

**Warn:** `.env` must be in `.gitignore`. Confirm with `grep .env .gitignore` before proceeding.

## Step 4 — Generate `.mcp.json`

```bash
node <plugin-scripts-path>/generate-project-mcp.mjs --path .
```

This merges the `mcpServers.wordpress` entry non-destructively.

## Step 5 — Validate handshake

```bash
lando wp mcp-adapter list
```

Expected: at least one server listed (e.g. `mcp-adapter-default-server`).

Then use MCP to validate:

```
discover-abilities
```

Expected: a list of available WordPress Abilities.

## If something fails

See [`references/rollback.md`](references/rollback.md) for per-step rollback commands.

## Verification

Run:
```bash
node <plugin-scripts-path>/detect-ai-readiness.mjs --path .
```

Expected: `"ready": true` with all fields populated.
```

- [ ] **Step 3: Create `skills/ai-setup/references/install-steps.md`**

```markdown
# Install Steps — Detailed Reference

Deep reference for `/ai-setup`. Loaded on demand.

## Package installation

```bash
lando composer require roots/acorn-ai wordpress/mcp-adapter
```

This adds both packages to `composer.json` and `composer.lock`, installs them, and runs their post-install scripts.

**If you get a version conflict:**
- `roots/acorn-ai` requires Acorn ≥ 4.x. Run `lando composer require roots/acorn` to update first.
- `wordpress/mcp-adapter` requires WP ≥ 6.9. If WP is older, upgrade via `lando composer update roots/wordpress`.

## Config publish

```bash
lando wp acorn vendor:publish --tag=acorn-ai
```

Creates `config/ai.php` in the theme. If the file already exists, the command will ask before overwriting.

## What `config/ai.php` contains

```php
return [
    'default' => env('AI_PROVIDER', 'anthropic'),
    'providers' => [
        'anthropic' => [
            'api_key' => env('ANTHROPIC_API_KEY'),
        ],
    ],
];
```

Edit this file to add additional providers or change defaults.

## MCP Adapter registration

`wordpress/mcp-adapter` registers a WP CLI command: `wp mcp-adapter`. After installing:

```bash
lando wp mcp-adapter list            # list registered servers
lando wp mcp-adapter serve           # start stdio server (called by Claude Code via .mcp.json)
```

The adapter auto-discovers registered Abilities when it starts. No manual registration needed.
```

- [ ] **Step 4: Create `skills/ai-setup/references/rollback.md`**

```markdown
# Rollback Guide — /ai-setup

If any step fails, here is how to reverse it.

## Rollback: package installation

```bash
lando composer remove roots/acorn-ai wordpress/mcp-adapter
```

This removes both packages and their entries from `composer.json`.

## Rollback: published config

```bash
rm config/ai.php
```

No side effects — it is a static config file.

## Rollback: API key

Remove the key line from `.env`. No packages read it until a request is made.

## Rollback: `.mcp.json`

The generator adds only the `mcpServers.wordpress` key. To remove:

```bash
# Remove just the wordpress server entry (jq required)
jq 'del(.mcpServers.wordpress)' .mcp.json > .mcp.json.tmp && mv .mcp.json.tmp .mcp.json
# Or edit manually — delete the "wordpress": { ... } block
```

If `.mcp.json` did not exist before, you can delete it entirely.
```

- [ ] **Step 5: Add ai-setup keywords to `hooks/user-prompt-activate.sh`**

Read the current KEYWORD_MAP in `hooks/user-prompt-activate.sh`. Append entries for `ai-setup` and `acorn ai`:

```bash
declare -A KEYWORD_MAP
# ... existing entries ...
KEYWORD_MAP["ai-setup"]="ai-setup"
KEYWORD_MAP["acorn ai"]="ai-setup"
KEYWORD_MAP["mcp adapter"]="ai-setup"
KEYWORD_MAP["discover-abilities"]="ai-setup"
KEYWORD_MAP["install mcp"]="ai-setup"
```

- [ ] **Step 6: Verify validate-skills passes for the new skill**

```bash
node scripts/validate-skills.mjs 2>&1 | grep -E "ai-setup|errors"
```

Expected: `✓ skills/ai-setup/SKILL.md`, 0 errors.

- [ ] **Step 7: Commit**

```bash
git add skills/ai-setup/ scripts/install-ai-stack.sh hooks/user-prompt-activate.sh
git commit -m "feat(skills,scripts): add ai-setup skill + install scripts (MP 5.2)"
```

---

### Task 5: `skills/abilities-authoring/` — Abilities skill (MP 5.4)

**Files:**
- Create: `skills/abilities-authoring/SKILL.md`
- Create: `skills/abilities-authoring/references/registration.md`
- Create: `skills/abilities-authoring/references/schema.md`
- Create: `skills/abilities-authoring/references/mcp-exposure.md`
- Create: `skills/abilities-authoring/references/patterns.md`
- Create: `scripts/create-ability.sh`
- Create: `scripts/list-abilities.sh`
- Create: `assets/ability-query-content.php.tpl`
- Create: `assets/ability-crud.php.tpl`
- Create: `assets/ability-search.php.tpl`
- Modify: `hooks/user-prompt-activate.sh` (add abilities keywords)

WordPress 6.9 Abilities are PHP classes that expose custom MCP endpoints. The MCP Adapter auto-discovers them.

- [ ] **Step 1: Create `scripts/create-ability.sh`**

```bash
#!/usr/bin/env bash
# Wrapper for lando wp acorn make:ability
# Usage: bash scripts/create-ability.sh <AbilityName> [--project-path /path/to/project]
set -e

ABILITY_NAME="${1:?Usage: create-ability.sh <AbilityName>}"
PROJECT_PATH="$(pwd)"

if [[ "$2" == "--project-path" ]]; then
  PROJECT_PATH="$3"
fi

cd "$PROJECT_PATH"
lando wp acorn make:ability "$ABILITY_NAME"
echo "Created app/Abilities/${ABILITY_NAME}.php"
echo "Register it in app/Providers/AbilitiesServiceProvider.php"
```

- [ ] **Step 2: Create `scripts/list-abilities.sh`**

```bash
#!/usr/bin/env bash
# Lists registered Abilities via the WP MCP Adapter
# Usage: bash scripts/list-abilities.sh [--project-path /path/to/project]
set -e

PROJECT_PATH="$(pwd)"
if [[ "$1" == "--project-path" ]]; then
  PROJECT_PATH="$2"
fi

cd "$PROJECT_PATH"
echo "==> Registered MCP servers:"
lando wp mcp-adapter list
echo ""
echo "==> Discovering abilities via MCP (requires Claude Code with .mcp.json configured):"
echo "    Use 'discover-abilities' MCP tool in your Claude Code session."
```

- [ ] **Step 3: Create `assets/ability-query-content.php.tpl`**

```php
<?php

namespace App\Abilities;

use Roots\AcornAi\Abilities\Ability;

class {{ABILITY_NAME}}Ability extends Ability
{
    public string $name = '{{snake_name}}';
    public string $description = 'Query {{post_type}} posts with optional filters.';

    public array $schema = [
        'type' => 'object',
        'properties' => [
            'status' => [
                'type' => 'string',
                'enum' => ['publish', 'draft', 'private'],
                'description' => 'Post status filter.',
            ],
            'limit' => [
                'type' => 'integer',
                'minimum' => 1,
                'maximum' => 100,
                'description' => 'Maximum number of posts to return.',
            ],
        ],
    ];

    public function execute(array $args): array
    {
        $query = new \WP_Query([
            'post_type'      => '{{post_type}}',
            'post_status'    => $args['status'] ?? 'publish',
            'posts_per_page' => $args['limit'] ?? 20,
        ]);

        return array_map(fn ($post) => [
            'id'    => $post->ID,
            'title' => $post->post_title,
            'slug'  => $post->post_name,
            'date'  => $post->post_date,
        ], $query->posts);
    }
}
```

- [ ] **Step 4: Create `assets/ability-crud.php.tpl`**

```php
<?php

namespace App\Abilities;

use Roots\AcornAi\Abilities\Ability;

class {{ABILITY_NAME}}Ability extends Ability
{
    public string $name = '{{snake_name}}';
    public string $description = 'Create, read, update, or delete a {{post_type}} post.';

    public array $schema = [
        'type' => 'object',
        'required' => ['action'],
        'properties' => [
            'action' => [
                'type' => 'string',
                'enum' => ['create', 'read', 'update', 'delete'],
            ],
            'id' => ['type' => 'integer'],
            'title' => ['type' => 'string'],
            'content' => ['type' => 'string'],
            'status' => ['type' => 'string'],
        ],
    ];

    public function execute(array $args): array
    {
        return match ($args['action']) {
            'create' => $this->createPost($args),
            'read'   => $this->readPost($args['id']),
            'update' => $this->updatePost($args),
            'delete' => $this->deletePost($args['id']),
        };
    }

    private function createPost(array $args): array
    {
        $id = wp_insert_post([
            'post_type'    => '{{post_type}}',
            'post_title'   => $args['title'] ?? '',
            'post_content' => $args['content'] ?? '',
            'post_status'  => $args['status'] ?? 'draft',
        ]);
        return ['id' => $id, 'action' => 'created'];
    }

    private function readPost(int $id): array
    {
        $post = get_post($id);
        if (! $post) return ['error' => 'not found'];
        return ['id' => $post->ID, 'title' => $post->post_title, 'status' => $post->post_status];
    }

    private function updatePost(array $args): array
    {
        wp_update_post(['ID' => $args['id'], 'post_title' => $args['title'] ?? null]);
        return ['id' => $args['id'], 'action' => 'updated'];
    }

    private function deletePost(int $id): array
    {
        wp_delete_post($id, true);
        return ['id' => $id, 'action' => 'deleted'];
    }
}
```

- [ ] **Step 5: Create `assets/ability-search.php.tpl`**

```php
<?php

namespace App\Abilities;

use Roots\AcornAi\Abilities\Ability;

class {{ABILITY_NAME}}Ability extends Ability
{
    public string $name = '{{snake_name}}';
    public string $description = 'Full-text search across {{post_type}} posts.';

    public array $schema = [
        'type' => 'object',
        'required' => ['query'],
        'properties' => [
            'query' => ['type' => 'string', 'description' => 'Search term.'],
            'limit' => ['type' => 'integer', 'minimum' => 1, 'maximum' => 50],
        ],
    ];

    public function execute(array $args): array
    {
        $query = new \WP_Query([
            'post_type'      => '{{post_type}}',
            's'              => $args['query'],
            'posts_per_page' => $args['limit'] ?? 10,
        ]);

        return array_map(fn ($post) => [
            'id'      => $post->ID,
            'title'   => $post->post_title,
            'excerpt' => wp_trim_words($post->post_content, 20),
        ], $query->posts);
    }
}
```

- [ ] **Step 6: Create `skills/abilities-authoring/SKILL.md`**

```markdown
---
name: superpowers-sage:abilities-authoring
description: >
  Creates custom WordPress Abilities for the WP MCP Adapter (WP 6.9+). An Ability is a PHP
  class extending Roots\AcornAi\Abilities\Ability that exposes a JSON schema and execute()
  method — auto-discovered by the MCP Adapter and callable via Claude's execute-ability tool.
  Covers: lando wp acorn make:ability, AbilitiesServiceProvider registration, JSON schema
  definition, meta.mcp.public flag, discover-abilities validation. Invoke for: abilities,
  make ability, custom mcp endpoint, discover-abilities, execute-ability, acorn ability,
  abilities-authoring, mcp endpoint, wp ability.
---

# abilities-authoring — WordPress MCP Abilities

An Ability exposes a callable endpoint via the WordPress MCP Adapter. Claude can call it via `execute-ability` after `discover-abilities` lists it.

## Anatomy of an Ability

```php
class ListProjectsAbility extends Ability
{
    public string $name = 'projects/list';
    public string $description = 'Return all published Project CPT posts.';
    public array $schema = [ /* JSON Schema for input */ ];

    public function execute(array $args): array
    {
        // returns array — serialized as JSON by the adapter
    }
}
```

## Creating an Ability

```bash
lando wp acorn make:ability <Name>
# Example: lando wp acorn make:ability ListProjects
# Creates: app/Abilities/ListProjectsAbility.php
```

See templates in `assets/ability-*.php.tpl` for query, CRUD, and search patterns.

## Registration

In `app/Providers/AbilitiesServiceProvider.php`:

```php
use App\Abilities\ListProjectsAbility;

public function boot(): void
{
    $this->app->make(AbilityRegistry::class)->register([
        new ListProjectsAbility(),
    ]);
}
```

See [`references/registration.md`](references/registration.md) for full ServiceProvider setup.

## JSON Schema

The `$schema` array follows JSON Schema Draft-07. See [`references/schema.md`](references/schema.md).

## MCP exposure

For an Ability to appear in `discover-abilities`, the MCP Adapter must be running:

```bash
lando wp mcp-adapter list    # verify server is registered
```

See [`references/mcp-exposure.md`](references/mcp-exposure.md) for how the adapter discovers Abilities.

## Validation

After registration, restart Lando and call `discover-abilities` in Claude Code. The ability should appear in the list.

## Verification

```bash
bash scripts/list-abilities.sh
```

Then in Claude Code session: call `discover-abilities` — your Ability should appear.
```

- [ ] **Step 7: Create the four references**

`skills/abilities-authoring/references/registration.md`:

```markdown
# Registration Reference

## AbilitiesServiceProvider setup

If the provider does not exist, create it:

```bash
lando wp acorn make:provider AbilitiesServiceProvider
```

Add to `config/app.php` providers array:
```php
App\Providers\AbilitiesServiceProvider::class,
```

## Registering multiple abilities

```php
public function boot(): void
{
    $registry = $this->app->make(\Roots\AcornAi\Abilities\AbilityRegistry::class);
    $registry->register([
        new \App\Abilities\ListProjectsAbility(),
        new \App\Abilities\SearchProjectsAbility(),
        new \App\Abilities\ManageProjectAbility(),
    ]);
}
```

## Naming convention

Ability names use `noun/verb` format: `projects/list`, `posts/search`, `acf/field-groups`.
The MCP Adapter exposes them as `execute-ability` targets.
```

`skills/abilities-authoring/references/schema.md`:

```markdown
# JSON Schema Reference

The `$schema` property follows JSON Schema Draft-07.

## Common patterns

```php
public array $schema = [
    'type' => 'object',
    'required' => ['id'],
    'properties' => [
        'id'     => ['type' => 'integer', 'description' => 'Post ID.'],
        'status' => ['type' => 'string', 'enum' => ['publish', 'draft']],
        'limit'  => ['type' => 'integer', 'minimum' => 1, 'maximum' => 100],
        'query'  => ['type' => 'string'],
    ],
];
```

## Validation

The MCP Adapter validates input against the schema before calling `execute()`.
Invalid input returns an error without reaching your code.

## Return value

`execute()` must return an array. It is JSON-serialized by the adapter.
Return flat arrays for simple results, nested arrays for collections.
```

`skills/abilities-authoring/references/mcp-exposure.md`:

```markdown
# MCP Exposure Reference

## How the adapter discovers Abilities

`wordpress/mcp-adapter` calls `discover-abilities` which queries the `AbilityRegistry`.
Abilities registered via `AbilityRegistry::register()` are automatically exposed — no manual
routing or registration with the MCP Adapter is needed.

## Viewing registered Abilities

```bash
lando wp mcp-adapter list         # lists MCP servers
```

In a Claude Code session with `.mcp.json` configured:
```
discover-abilities                # lists all Abilities
execute-ability projects/list     # calls a specific Ability
```

## `.mcp.json` requirement

The adapter runs via stdio — Claude Code calls `lando wp mcp-adapter serve` as a subprocess.
Your project `.mcp.json` must have the `mcpServers.wordpress` entry. Generate it with:

```bash
node <plugin-path>/scripts/generate-project-mcp.mjs --path .
```

## Restarting after registration changes

After adding or removing Abilities, Lando does not need to restart.
However, Claude Code's MCP connection caches `discover-abilities` — restart Claude Code
(or reopen the project) to see newly registered Abilities.
```

`skills/abilities-authoring/references/patterns.md`:

```markdown
# Ability Patterns

## Query pattern (read-only list)

Use template `assets/ability-query-content.php.tpl`.
Replace `{{ABILITY_NAME}}` with PascalCase, `{{snake_name}}` with `noun/verb`, `{{post_type}}` with CPT slug.

Good for: listing CPT posts, filtering by status/meta, pagination.

## CRUD pattern (full lifecycle)

Use template `assets/ability-crud.php.tpl`.
Exposes create/read/update/delete in one Ability via `action` parameter.

Good for: draft management, content editing, status changes.

## Search pattern (full-text)

Use template `assets/ability-search.php.tpl`.
Uses WP_Query `s` parameter for full-text search.

Good for: content discovery, Claude finding posts to reference.

## ACF field groups pattern

```php
public function execute(array $args): array
{
    $groups = acf_get_field_groups(['post_type' => $args['post_type'] ?? null]);
    return array_map(fn ($g) => [
        'key'    => $g['key'],
        'title'  => $g['title'],
        'fields' => array_map(fn ($f) => ['name' => $f['name'], 'type' => $f['type']],
                              acf_get_fields($g['key']) ?: []),
    ], $groups);
}
```

## Livewire components pattern

```php
public function execute(array $args): array
{
    $dir = get_template_directory() . '/app/Livewire/';
    $files = glob($dir . '*.php') ?: [];
    return array_map(fn ($f) => [
        'class' => 'App\\Livewire\\' . basename($f, '.php'),
        'tag'   => Str::kebab(basename($f, '.php')),
    ], $files);
}
```
```

- [ ] **Step 8: Add abilities keywords to `hooks/user-prompt-activate.sh`**

Append to KEYWORD_MAP:

```bash
KEYWORD_MAP["abilities"]="abilities-authoring"
KEYWORD_MAP["make:ability"]="abilities-authoring"
KEYWORD_MAP["abilities-authoring"]="abilities-authoring"
KEYWORD_MAP["execute-ability"]="abilities-authoring"
KEYWORD_MAP["acorn ability"]="abilities-authoring"
```

- [ ] **Step 9: Run validate-skills**

```bash
node scripts/validate-skills.mjs 2>&1 | grep -E "abilities|errors|passed"
```

Expected: `✓ skills/abilities-authoring/SKILL.md`, 0 errors.

- [ ] **Step 10: Commit**

```bash
git add skills/abilities-authoring/ scripts/create-ability.sh scripts/list-abilities.sh assets/ability-*.php.tpl hooks/user-prompt-activate.sh
git commit -m "feat(skills,scripts,assets): add abilities-authoring skill + Ability templates (MP 5.4)"
```

---

### Task 6: Query-first reference expansion + skill edits (MP 5.5)

**Files:**
- Modify: `skills/sageing/references/mcp-query-patterns.md`
- Modify: `skills/acorn-livewire/SKILL.md`
- Modify: `skills/acorn-routes/SKILL.md`
- Modify: `skills/modeling/SKILL.md`
- Modify: `skills/building/SKILL.md`

The `mcp-query-patterns.md` placeholder is replaced with full content. Four skills get a short "Query First" section at their end, linking to the reference.

- [ ] **Step 1: Replace `skills/sageing/references/mcp-query-patterns.md` with full content**

```markdown
# MCP Query Patterns

When the AI stack is ready (`detect-ai-readiness` reports `ready: true`), query the live
WordPress environment before generating any code that involves post types, custom fields,
routes, or Livewire components.

## The query-first rule

Before writing code that **references** any of the following, run the corresponding query:

| Thing to reference | Query to run | Tool |
|---|---|---|
| Custom post types | `execute-ability posts/list-types` | MCP |
| ACF field groups | `execute-ability acf/field-groups` | MCP |
| Acorn routes | `execute-ability routes/list` | MCP |
| Livewire components | `execute-ability livewire/components` | MCP |
| Menu locations | `execute-ability menus/locations` | MCP |

## Step-by-step pattern

1. Call `discover-abilities` to see what is available in this project.
2. Call `execute-ability <name>` with the relevant ability.
3. Use the real data (slugs, field names, class names) — not invented names.
4. If the ability does not exist, suggest the user create it with `/abilities-authoring`.
5. If `ready: false`, ask the user for the information instead of guessing.

## Example: building a Livewire component that references a CPT

**Bad (generates code with invented slug):**
```
I'll create a Livewire component that queries `project` posts...
```

**Good (queries first):**
```
1. discover-abilities
   → sees "posts/list-types", "livewire/components"
2. execute-ability posts/list-types
   → returns [{"slug":"projeto","label":"Projetos"}]
3. execute-ability livewire/components
   → returns existing components to avoid duplication
4. Now generates code using slug "projeto" (real value)
```

## Fallback when stack is not installed

If `detect-ai-readiness.mjs --path .` returns `ready: false`:
- Ask the user: "What custom post types does this project use?"
- Suggest running `/ai-setup` to install the stack.
- Do not guess or invent slugs, field names, or component names.
```

- [ ] **Step 2: Append MCP query-first section to `skills/acorn-livewire/SKILL.md`**

Append before the final `---` references line (or at the very end if no `---`):

```markdown

## Query First — MCP Integration

Before creating or referencing a Livewire component, query the live environment:

```
discover-abilities               # check what's available
execute-ability livewire/components   # list existing components
```

Use real class names from the query. Do not invent component names.
If the stack is not installed, run `/ai-setup` first.
See [`sageing/references/mcp-query-patterns.md`](../sageing/references/mcp-query-patterns.md) for the full pattern.
```

- [ ] **Step 3: Append to `skills/acorn-routes/SKILL.md`**

```markdown

## Query First — MCP Integration

Before adding routes that reference controllers or post types, query:

```
execute-ability routes/list      # list registered Acorn routes
```

Use real route slugs and controller names from the query.
See [`sageing/references/mcp-query-patterns.md`](../sageing/references/mcp-query-patterns.md).
```

- [ ] **Step 4: Append to `skills/modeling/SKILL.md`**

```markdown

## Query First — MCP Integration

Before proposing CPTs or ACF field groups, query what already exists:

```
execute-ability posts/list-types     # avoid duplicating CPTs
execute-ability acf/field-groups     # see existing field structure
```

See [`sageing/references/mcp-query-patterns.md`](../sageing/references/mcp-query-patterns.md).
```

- [ ] **Step 5: Append to `skills/building/SKILL.md`**

```markdown

## Query First — MCP Integration

Before generating code that references CPTs, fields, routes, or Livewire components:

```
discover-abilities                   # what can be queried?
execute-ability posts/list-types     # real CPT slugs
execute-ability acf/field-groups     # real field names
```

Never invent slugs or field names — always query first when the stack is available.
See [`sageing/references/mcp-query-patterns.md`](../sageing/references/mcp-query-patterns.md).
```

- [ ] **Step 6: Verify line counts stay under 500**

```bash
wc -l skills/acorn-livewire/SKILL.md skills/acorn-routes/SKILL.md skills/modeling/SKILL.md skills/building/SKILL.md
```

Expected: all under 500.

- [ ] **Step 7: Run validate-skills**

```bash
node scripts/validate-skills.mjs 2>&1 | tail -5
```

Expected: 0 errors.

- [ ] **Step 8: Commit**

```bash
git add skills/sageing/references/mcp-query-patterns.md \
        skills/acorn-livewire/SKILL.md \
        skills/acorn-routes/SKILL.md \
        skills/modeling/SKILL.md \
        skills/building/SKILL.md
git commit -m "feat(skills): add query-first MCP pattern to 4 skills + expand mcp-query-patterns reference (MP 5.5)"
```

---

### Task 7: Validation + index update

**Files:**
- Modify: `docs/superpowers/plans/2026-04-18-plugin-expansion-index.md`

- [ ] **Step 1: Run full test suite**

```bash
node scripts/test-detect-ai-readiness.mjs
node scripts/validate-skills.mjs
```

Expected: 0 failures, 0 errors.

- [ ] **Step 2: Verify all new files exist**

```bash
ls scripts/detect-ai-readiness.mjs \
   scripts/generate-project-mcp.mjs \
   scripts/install-ai-stack.sh \
   scripts/create-ability.sh \
   scripts/list-abilities.sh \
   templates/project-mcp.json.tpl \
   skills/ai-setup/SKILL.md \
   skills/abilities-authoring/SKILL.md \
   assets/ability-query-content.php.tpl \
   assets/ability-crud.php.tpl \
   assets/ability-search.php.tpl
```

- [ ] **Step 3: Verify 4 skills have Query-First sections**

```bash
grep -l "Query First" skills/acorn-livewire/SKILL.md skills/acorn-routes/SKILL.md skills/modeling/SKILL.md skills/building/SKILL.md
```

Expected: all 4 files listed.

- [ ] **Step 4: Update master index — mark Wave 5 Done**

In `docs/superpowers/plans/2026-04-18-plugin-expansion-index.md`, update Wave 5 row:

```
| 5 — AI-native integration | [onda-5](2026-04-18-plugin-expansion-onda-5.md) | 5 | Done |
```

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/plans/2026-04-18-plugin-expansion-index.md
git commit -m "docs(plans): mark Onda 5 done in master index"
```
