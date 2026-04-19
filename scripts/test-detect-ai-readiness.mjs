#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync, chmodSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCRIPT = resolve(__dirname, 'detect-ai-readiness.mjs');
const IS_WIN = process.platform === 'win32';

// Minimal PATH that lets `node` + `where`/`which` run but does NOT contain lando.
// Used by the no-lando scenario to prove absence detection works.
const NODE_DIR = dirname(process.execPath);
const NO_LANDO_PATH = IS_WIN
  ? `${NODE_DIR};C:\\Windows\\System32`
  : `${NODE_DIR}:/usr/bin:/bin`;

let passed = 0;
let failed = 0;

function assert(label, condition, details) {
  if (condition) { console.log(`  ✅ ${label}`); passed++; }
  else { console.log(`  ❌ ${label}`); if (details) console.log(`     ${details}`); failed++; }
}

/**
 * Creates a mock lando executable in binDir.
 * On Windows: writes lando_shim.js (Node.js logic) + lando.cmd (wrapper).
 * On Unix:    writes a bash script named `lando` (chmod +x).
 *
 * @param {string} dir        Project temp dir (used as parent for bin/).
 * @param {string|null} wpVersion  WP version to return from `lando wp core version`.
 * @param {string[]|null} mcpServers  MCP server names to return, or null to simulate failure.
 * @returns {string} Path to the bin directory to prepend to PATH.
 */
function makeBin(dir, wpVersion, mcpServers) {
  const binDir = join(dir, 'bin');
  mkdirSync(binDir, { recursive: true });

  const mcpOk = mcpServers !== null ? 0 : 1;
  const mcpJSON = mcpServers
    ? JSON.stringify(mcpServers.map(n => ({ name: n })))
    : '[]';

  if (IS_WIN) {
    // Node.js shim — contains the lando mock logic
    const shimPath = join(binDir, 'lando_shim.js');
    const shimLines = [
      'var args = process.argv.slice(2);',
      'var sub3 = args.slice(0,3).join(" ");',
      'var sub4 = args.slice(0,4).join(" ");',
      'var WP_VERSION = ' + JSON.stringify(wpVersion ?? '6.9.1') + ';',
      'var MCP_OUTPUT = ' + JSON.stringify(mcpJSON) + ';',
      'var MCP_EXIT = ' + mcpOk + ';',
      'if (sub3 === "wp core version") { process.stdout.write(WP_VERSION + "\\n"); process.exit(0); }',
      'if (sub4 === "wp mcp-adapter list --format=json") { process.stdout.write(MCP_OUTPUT + "\\n"); process.exit(MCP_EXIT); }',
      'process.exit(0);',
    ];
    writeFileSync(shimPath, shimLines.join('\r\n'));

    // .cmd wrapper — cmd.exe finds this via PATHEXT
    const nodeExe = process.execPath;
    const cmdContent = '@echo off\r\n"' + nodeExe + '" "' + shimPath + '" %*\r\n';
    writeFileSync(join(binDir, 'lando.cmd'), cmdContent);
  } else {
    // Bash script — works on Unix/macOS
    const scriptLines = [
      '#!/usr/bin/env bash',
      `WP_VERSION="${wpVersion ?? '6.9.1'}"`,
      `MCP_OUTPUT='${mcpJSON}'`,
      `MCP_EXIT=${mcpOk}`,
      'SUBCMD="$1 $2 $3"',
      'SUBCMD4="$1 $2 $3 $4"',
      'if [[ "$SUBCMD" == "wp core version" ]]; then echo "$WP_VERSION"; exit 0; fi',
      'if [[ "$SUBCMD4" == "wp mcp-adapter list --format=json" ]]; then echo "$MCP_OUTPUT"; exit $MCP_EXIT; fi',
      'exit 0',
    ];
    const landoPath = join(binDir, 'lando');
    writeFileSync(landoPath, scriptLines.join('\n'));
    chmodSync(landoPath, 0o755);
  }

  return binDir;
}

function makeComposerLock(dir, packages) {
  const lock = { packages: packages.map(([name, version]) => ({ name, version })) };
  writeFileSync(join(dir, 'composer.lock'), JSON.stringify(lock));
}

function makeEnv(dir, keys) {
  const content = keys.map(k => `${k}=sk-test-key-abc123`).join('\n') + '\n';
  writeFileSync(join(dir, '.env'), content);
}

function run(projectDir, binDir) {
  const sep = IS_WIN ? ';' : ':';
  const env = { ...process.env, PATH: `${binDir}${sep}${process.env.PATH}` };
  const result = spawnSync('node', [SCRIPT, '--path', projectDir], {
    encoding: 'utf8',
    env,
    timeout: 30000,
  });
  try {
    return { exit: result.status, data: JSON.parse(result.stdout?.trim() || '{}'), stderr: result.stderr };
  } catch (e) {
    return { exit: result.status, data: null, error: e.message, raw: result.stdout };
  }
}

console.log('\n🔍 detect-ai-readiness — test suite\n');

// Scenario 1: fully ready
{
  console.log('Scenario 1: fully-ready');
  const dir = mkdtempSync(join(tmpdir(), 'ai-ready-'));
  const binDir = makeBin(dir, '6.9.1', ['mcp-adapter-default-server']);
  makeComposerLock(dir, [['roots/acorn-ai', '1.0.0'], ['wordpress/mcp-adapter', '0.4.0']]);
  makeEnv(dir, ['ANTHROPIC_API_KEY']);
  const { data } = run(dir, binDir);
  assert('ready: true', data?.ready === true, JSON.stringify(data?.missing));
  assert('wp_version 6.9.1', data?.wp_version === '6.9.1');
  assert('packages.acorn-ai present', data?.packages?.['acorn-ai'] === '1.0.0');
  assert('packages.mcp-adapter present', data?.packages?.['mcp-adapter'] === '0.4.0');
  assert('api_keys_present includes ANTHROPIC_API_KEY', data?.api_keys_present?.includes('ANTHROPIC_API_KEY'));
  assert('mcp_servers populated', (data?.mcp_servers?.length ?? 0) > 0);
  assert('missing is empty', (data?.missing?.length ?? 1) === 0);
  rmSync(dir, { recursive: true, force: true });
}

// Scenario 2: missing acorn-ai
{
  console.log('\nScenario 2: missing-acorn-ai');
  const dir = mkdtempSync(join(tmpdir(), 'ai-ready-'));
  const binDir = makeBin(dir, '6.9.1', ['mcp-adapter-default-server']);
  makeComposerLock(dir, [['wordpress/mcp-adapter', '0.4.0']]);
  makeEnv(dir, ['ANTHROPIC_API_KEY']);
  const { data } = run(dir, binDir);
  assert('ready: false', data?.ready === false);
  assert('missing includes acorn-ai', data?.missing?.includes('acorn-ai'));
  assert('upgrade_path mentions composer require roots/acorn-ai', data?.upgrade_path?.some(s => s.includes('roots/acorn-ai')));
  rmSync(dir, { recursive: true, force: true });
}

// Scenario 3: missing api-key
{
  console.log('\nScenario 3: missing-api-key');
  const dir = mkdtempSync(join(tmpdir(), 'ai-ready-'));
  const binDir = makeBin(dir, '6.9.1', ['mcp-adapter-default-server']);
  makeComposerLock(dir, [['roots/acorn-ai', '1.0.0'], ['wordpress/mcp-adapter', '0.4.0']]);
  writeFileSync(join(dir, '.env'), 'APP_ENV=local\n');
  const { data } = run(dir, binDir);
  assert('ready: false', data?.ready === false);
  assert('missing includes api-key', data?.missing?.includes('api-key'));
  assert('api_keys_present is empty', (data?.api_keys_present?.length ?? 1) === 0);
  rmSync(dir, { recursive: true, force: true });
}

// Scenario 4: WP too old
{
  console.log('\nScenario 4: wp-too-old');
  const dir = mkdtempSync(join(tmpdir(), 'ai-ready-'));
  const binDir = makeBin(dir, '6.8.0', ['mcp-adapter-default-server']);
  makeComposerLock(dir, [['roots/acorn-ai', '1.0.0'], ['wordpress/mcp-adapter', '0.4.0']]);
  makeEnv(dir, ['ANTHROPIC_API_KEY']);
  const { data } = run(dir, binDir);
  assert('ready: false', data?.ready === false);
  assert('missing includes wp-core<6.9', data?.missing?.includes('wp-core<6.9'));
  assert('wp_version is 6.8.0', data?.wp_version === '6.8.0');
  rmSync(dir, { recursive: true, force: true });
}

// Scenario 5: no lando in PATH
{
  console.log('\nScenario 5: no-lando');
  const dir = mkdtempSync(join(tmpdir(), 'ai-ready-'));
  makeComposerLock(dir, [['roots/acorn-ai', '1.0.0'], ['wordpress/mcp-adapter', '0.4.0']]);
  makeEnv(dir, ['ANTHROPIC_API_KEY']);
  // Use a minimal PATH that lets node + where/which run but has no lando
  const env = { ...process.env, PATH: NO_LANDO_PATH };
  const result = spawnSync('node', [SCRIPT, '--path', dir], { encoding: 'utf8', env, timeout: 30000 });
  let data;
  try { data = JSON.parse(result.stdout?.trim() || '{}'); } catch { data = null; }
  assert('exits 0', result.status === 0, result.stderr?.slice(0, 200));
  assert('ready: false', data?.ready === false);
  assert('missing includes lando-not-found', data?.missing?.includes('lando-not-found'));
  rmSync(dir, { recursive: true, force: true });
}

console.log(`\nResults: ${passed} passed, ${failed} failed\n`);
if (failed > 0) process.exit(1);
