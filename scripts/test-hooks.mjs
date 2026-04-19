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
