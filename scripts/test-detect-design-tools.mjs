#!/usr/bin/env node
// Test runner for detect-design-tools.mjs
// Usage: node scripts/test-detect-design-tools.mjs

import { spawnSync } from 'child_process';
import { mkdtempSync, copyFileSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join, resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DETECT = resolve(__dirname, 'detect-design-tools.mjs');
const FIXTURES = resolve(__dirname, '__fixtures__');

function runDetect(fixtureName) {
  const tmp = mkdtempSync(join(tmpdir(), 'detect-test-'));
  try {
    copyFileSync(join(FIXTURES, fixtureName), join(tmp, '.mcp.json'));
    const res = spawnSync('node', [DETECT, '--path', tmp], { encoding: 'utf8' });
    if (res.status !== 0) {
      throw new Error(`detect exited ${res.status}: ${res.stderr}`);
    }
    return JSON.parse(res.stdout);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

const cases = [
  {
    name: 'only paper',
    fixture: 'mcp-only-paper.json',
    expect: (out) => out.designTools.paper?.configured === true
      && out.designTools.figma?.configured === false
      && out.designTools.stitch?.configured === false,
  },
  {
    name: 'only figma',
    fixture: 'mcp-only-figma.json',
    expect: (out) => out.designTools.figma?.configured === true
      && out.designTools.paper?.configured === false
      && out.designTools.stitch?.configured === false,
  },
  {
    name: 'only stitch',
    fixture: 'mcp-only-stitch.json',
    expect: (out) => out.designTools.stitch?.configured === true
      && out.designTools.paper?.configured === false
      && out.designTools.figma?.configured === false,
  },
  {
    name: 'paper + figma',
    fixture: 'mcp-paper-figma.json',
    expect: (out) => out.designTools.paper?.configured === true
      && out.designTools.figma?.configured === true
      && out.designTools.stitch?.configured === false,
  },
  {
    name: 'all three + playwright',
    fixture: 'mcp-all-three.json',
    expect: (out) => out.designTools.paper?.configured === true
      && out.designTools.figma?.configured === true
      && out.designTools.stitch?.configured === true
      && out.verificationTools.playwright?.configured === true,
  },
  {
    name: 'none',
    fixture: 'mcp-none.json',
    expect: (out) => out.designTools.paper?.configured === false
      && out.designTools.figma?.configured === false
      && out.designTools.stitch?.configured === false,
  },
];

let failed = 0;
for (const c of cases) {
  try {
    const out = runDetect(c.fixture);
    if (!c.expect(out)) {
      console.error(`FAIL: ${c.name}\n  output: ${JSON.stringify(out, null, 2)}`);
      failed++;
    } else {
      console.log(`PASS: ${c.name}`);
    }
  } catch (err) {
    console.error(`ERROR: ${c.name}: ${err.message}`);
    failed++;
  }
}

if (failed > 0) {
  console.error(`\n${failed} test(s) failed`);
  process.exit(1);
}
console.log(`\nAll ${cases.length} tests passed`);
