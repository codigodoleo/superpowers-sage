#!/usr/bin/env node
/**
 * Test suite for scripts/validate-skills.mjs
 *
 * Invokes the real validator in a controlled fixture directory and asserts
 * its diagnosis on known-good and known-bad skill files.
 */

import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync, mkdirSync, readFileSync, cpSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCRIPT = resolve(__dirname, 'validate-skills.mjs');

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

// The validator walks ROOT/../skills relative to its own location.
// To test, we replicate the expected structure in a tmp dir and run the
// script via `node -e` with a rewritten ROOT.
//
// Simpler: run the validator directly on the real repo and assert the
// expected exit/summary for known-good state (the happy path test), and
// use a second test that creates a broken skill file and re-runs.

function runValidator(workingDir) {
  // The validator resolves ROOT relative to its own file location, so if we
  // want it to validate fixture skills we must invoke the tmp copy of the
  // script, not the original.
  const scriptInWorkingDir = join(workingDir, 'scripts', 'validate-skills.mjs');
  const script = existsOrFallback(scriptInWorkingDir, SCRIPT);
  const result = spawnSync('node', [script], {
    encoding: 'utf8',
    cwd: workingDir,
  });
  return {
    exit: result.status,
    stdout: result.stdout || '',
    stderr: result.stderr || '',
  };
}

function existsOrFallback(a, b) {
  try {
    readFileSync(a);
    return a;
  } catch {
    return b;
  }
}

function testHappyPath() {
  console.log('\nCase: real repo (happy path — 0 errors expected)');
  const root = resolve(__dirname, '..');
  const { exit, stdout } = runValidator(root);
  const summary = stdout.match(/Summary: (\d+) passed, (\d+) warnings, (\d+) errors/);
  assert('summary line present', summary !== null, stdout.slice(-200));
  if (summary) {
    const [, passedCount, , errorCount] = summary;
    assert(
      `0 errors (got ${errorCount})`,
      errorCount === '0'
    );
    assert(
      `at least 20 skills passed validation (got ${passedCount})`,
      parseInt(passedCount, 10) >= 20
    );
  }
  assert('exit code 0', exit === 0);
}

function testCRLFFrontmatterParses() {
  console.log('\nCase: frontmatter with CRLF line endings is parsed correctly');
  // Create a mirror of the real repo in tmp, then convert one skill to CRLF
  const tmp = mkdtempSync(join(tmpdir(), 'validate-skills-crlf-'));
  try {
    // Only mirror the structure the script walks: scripts/ and skills/
    const src = resolve(__dirname, '..');
    cpSync(join(src, 'scripts'), join(tmp, 'scripts'), { recursive: true });
    cpSync(join(src, 'skills'), join(tmp, 'skills'), { recursive: true });
    mkdirSync(join(tmp, 'agents'), { recursive: true });

    // Convert one skill file to CRLF
    const target = join(tmp, 'skills', 'sageing', 'SKILL.md');
    const lf = readFileSync(target, 'utf8');
    const crlf = lf.replace(/\r?\n/g, '\r\n');
    writeFileSync(target, crlf);

    const { stdout } = runValidator(tmp);
    assert(
      'CRLF file not reported as missing frontmatter',
      !stdout.includes('skills/sageing/SKILL.md — missing YAML frontmatter'),
      stdout.slice(-300)
    );
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

function testMissingFrontmatterCaught() {
  console.log('\nCase: skill with no frontmatter is flagged as error');
  const tmp = mkdtempSync(join(tmpdir(), 'validate-skills-broken-'));
  try {
    const src = resolve(__dirname, '..');
    cpSync(join(src, 'scripts'), join(tmp, 'scripts'), { recursive: true });
    // Create a minimal skills/ with one broken file
    mkdirSync(join(tmp, 'skills', 'broken-skill'), { recursive: true });
    writeFileSync(
      join(tmp, 'skills', 'broken-skill', 'SKILL.md'),
      '# Broken skill\n\nNo frontmatter here.\n'
    );
    mkdirSync(join(tmp, 'agents'), { recursive: true });

    const { stdout, exit } = runValidator(tmp);
    assert(
      'error reported for broken skill',
      stdout.includes('broken-skill/SKILL.md — missing YAML frontmatter'),
      stdout.slice(-300)
    );
    assert('exit code non-zero on error', exit !== 0);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

function testOver500LineWarning() {
  console.log('\nCase: skill file with >500 lines triggers soft warning (exit 0)');
  const tmp = mkdtempSync(join(tmpdir(), 'validate-skills-fat-'));
  try {
    const src = resolve(__dirname, '..');
    cpSync(join(src, 'scripts'), join(tmp, 'scripts'), { recursive: true });
    // Copy plugin manifests so the validator doesn't error on missing files
    for (const [dir, file] of [['.claude-plugin', 'plugin.json'], ['.cursor-plugin', 'plugin.json'], ['', 'plugin.json']]) {
      if (dir) {
        mkdirSync(join(tmp, dir), { recursive: true });
        cpSync(join(src, dir, file), join(tmp, dir, file));
      } else {
        cpSync(join(src, file), join(tmp, file));
      }
    }
    mkdirSync(join(tmp, 'skills', 'fat-skill'), { recursive: true });
    mkdirSync(join(tmp, 'agents'), { recursive: true });

    // Build a valid SKILL.md with exactly 501 lines total.
    // The validator uses content.split(/\r?\n/).length.
    // Strategy: start with the required header lines, then append padding lines
    // until the total reaches 501.
    const headerLines = [
      '---',
      'name: sage:fat-skill',
      'description: A deliberately fat skill for testing the 500-line soft warning.',
      '---',
      '',
      '## Verification',
      '',
      'Run the validator and check for the warning message.',
      '',
      '## Failure modes',
      '',
      'The validator exits 1 instead of 0.',
    ];
    const targetLines = 501;
    const paddingCount = targetLines - headerLines.length;
    const allLines = [
      ...headerLines,
      ...Array.from({ length: paddingCount }, (_, i) => `<!-- padding line ${i + 1} -->`),
    ];
    const content = allLines.join('\n');
    // Verify line count is exactly 501
    const actualLines = content.split(/\r?\n/).length;

    writeFileSync(
      join(tmp, 'skills', 'fat-skill', 'SKILL.md'),
      content
    );

    const { stdout, exit } = runValidator(tmp);
    assert(
      `warning message contains "fat-skill/SKILL.md — ${actualLines} lines (>500 target)"`,
      stdout.includes(`fat-skill/SKILL.md — ${actualLines} lines (>500 target)`),
      stdout.slice(-400)
    );
    assert('exit code is 0 (soft warning, not an error)', exit === 0);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

// --- Run ---

console.log('Testing scripts/validate-skills.mjs');

testHappyPath();
testCRLFFrontmatterParses();
testMissingFrontmatterCaught();
testOver500LineWarning();

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);
