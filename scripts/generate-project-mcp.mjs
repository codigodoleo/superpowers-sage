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

process.exit(0);
