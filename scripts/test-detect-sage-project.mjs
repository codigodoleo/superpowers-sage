#!/usr/bin/env node
/**
 * Test suite for scripts/detect-sage-project.mjs
 *
 * Creates temporary project fixtures and asserts the detector identifies
 * Sage themes, Lando configuration, and active project paths correctly.
 */

import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCRIPT = resolve(__dirname, 'detect-sage-project.mjs');

let passed = 0;
let failed = 0;

function assert(label, condition, details) {
  if (condition) {
    console.log(`  ✅ ${label}`);
    passed++;
  } else {
    console.log(`  ❌ ${label}`);
    if (details) console.log(`     ${details}`);
    failed++;
  }
}

function runDetector(cwd) {
  const result = spawnSync('node', [SCRIPT, '--path', cwd], {
    encoding: 'utf8',
    cwd,
  });
  const stdout = result.stdout || '';
  try {
    return {
      exit: result.status,
      data: JSON.parse(stdout.trim() || '{}'),
      stderr: result.stderr,
    };
  } catch (err) {
    return {
      exit: result.status,
      data: null,
      error: `JSON parse failed: ${err.message}\nSTDOUT: ${stdout}`,
      stderr: result.stderr,
    };
  }
}

function createProject(root, files) {
  for (const [path, content] of Object.entries(files)) {
    const full = join(root, path);
    mkdirSync(dirname(full), { recursive: true });
    writeFileSync(full, content);
  }
}

// --- Test cases ---

function testNotSageProject() {
  console.log('\nCase: not a Sage project (empty dir)');
  const tmp = mkdtempSync(join(tmpdir(), 'detect-sage-empty-'));
  try {
    const { exit, data } = runDetector(tmp);
    assert('exit code 1', exit === 1);
    assert('detected: false', data?.detected === false, JSON.stringify(data));
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

function testNotSageProjectWithComposer() {
  console.log('\nCase: project with composer.json but no roots/acorn');
  const tmp = mkdtempSync(join(tmpdir(), 'detect-sage-nonsage-'));
  try {
    createProject(tmp, {
      'composer.json': JSON.stringify({
        name: 'example/project',
        require: { 'other/package': '^1.0' },
      }),
    });
    const { exit, data } = runDetector(tmp);
    assert('exit code 1', exit === 1);
    assert('detected: false', data?.detected === false);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

function testSageThemeDetection() {
  console.log('\nCase: Sage theme with roots/acorn in require');
  const tmp = mkdtempSync(join(tmpdir(), 'detect-sage-basic-'));
  try {
    createProject(tmp, {
      'themes/mytheme/composer.json': JSON.stringify({
        name: 'roots/mytheme',
        require: { 'roots/acorn': '^4.0' },
      }),
    });
    const { exit, data } = runDetector(tmp);
    assert('exit code 0', exit === 0);
    assert('detected: true', data?.detected === true);
    assert('at least one project', (data?.projects?.length ?? 0) >= 1);
    assert(
      'theme path includes mytheme',
      data?.projects?.[0]?.path?.includes('mytheme'),
      `path was: ${data?.projects?.[0]?.path}`
    );
    assert('activeProject set', typeof data?.activeProject === 'string' && data.activeProject.length > 0);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

function testSageWithLando() {
  console.log('\nCase: Sage theme + .lando.yml at root');
  const tmp = mkdtempSync(join(tmpdir(), 'detect-sage-lando-'));
  try {
    createProject(tmp, {
      '.lando.yml': 'name: myproject\nrecipe: wordpress\nconfig:\n  webroot: web\n',
      'themes/mytheme/composer.json': JSON.stringify({
        name: 'roots/mytheme',
        require: { 'roots/acorn': '^4.0' },
      }),
    });
    const { exit, data } = runDetector(tmp);
    assert('exit code 0', exit === 0);
    assert('detected: true', data?.detected === true);
    assert('lando detected', data?.lando?.detected === true, JSON.stringify(data?.lando));
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

function testSageVersionFromLock() {
  console.log('\nCase: Sage theme with composer.lock specifying roots/acorn version');
  const tmp = mkdtempSync(join(tmpdir(), 'detect-sage-lock-'));
  try {
    createProject(tmp, {
      'themes/mytheme/composer.json': JSON.stringify({
        name: 'roots/mytheme',
        require: { 'roots/acorn': '^4.0' },
      }),
      'themes/mytheme/composer.lock': JSON.stringify({
        packages: [
          { name: 'roots/acorn', version: '4.6.5' },
        ],
      }),
    });
    const { exit, data } = runDetector(tmp);
    assert('exit code 0', exit === 0);
    assert('detected: true', data?.detected === true);
    assert(
      'acorn version extracted',
      data?.projects?.[0]?.acorn === '4.6.5',
      `acorn was: ${data?.projects?.[0]?.acorn}`
    );
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

function testMultipleThemesChoosesShortestPath() {
  console.log('\nCase: multiple Sage themes → active = shortest path');
  const tmp = mkdtempSync(join(tmpdir(), 'detect-sage-multi-'));
  try {
    createProject(tmp, {
      'themes/theme-a/composer.json': JSON.stringify({
        name: 'roots/theme-a',
        require: { 'roots/acorn': '^4.0' },
      }),
      'themes/theme-b/composer.json': JSON.stringify({
        name: 'roots/theme-b',
        require: { 'roots/acorn': '^4.0' },
      }),
    });
    const { exit, data } = runDetector(tmp);
    assert('exit code 0', exit === 0);
    assert('two projects detected', data?.projects?.length === 2);
    // The detector picks the shortest path; both are same length here, so just
    // verify it picks one deterministically.
    assert(
      'activeProject is one of the themes',
      ['themes/theme-a', 'themes/theme-b'].includes(data?.activeProject),
      `activeProject was: ${data?.activeProject}`
    );
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

// --- Run ---

console.log('Testing scripts/detect-sage-project.mjs');

testNotSageProject();
testNotSageProjectWithComposer();
testSageThemeDetection();
testSageWithLando();
testSageVersionFromLock();
testMultipleThemesChoosesShortestPath();

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);
