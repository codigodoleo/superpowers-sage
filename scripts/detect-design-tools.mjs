#!/usr/bin/env node

import { readFileSync, existsSync, readdirSync } from 'fs';
import { join, resolve } from 'path';
import { homedir } from 'os';

const args = process.argv.slice(2);
const pathFlag = args.indexOf('--path');
const rootPath = resolve(pathFlag !== -1 && args[pathFlag + 1] ? args[pathFlag + 1] : process.cwd());

function readJSON(filePath) {
  try {
    return JSON.parse(readFileSync(filePath, 'utf8'));
  } catch { return null; }
}

function detectMCPServers(config) {
  const servers = config?.mcpServers || {};
  const result = {};

  for (const [name, def] of Object.entries(servers)) {
    const nameLower = name.toLowerCase();
    const cmdStr = [def.command, ...(def.args || [])].join(' ').toLowerCase();

    if (nameLower.includes('stitch') || cmdStr.includes('stitch')) {
      result.stitch = { name, configured: true };
    }
    if (nameLower.includes('figma') || cmdStr.includes('figma')) {
      result.figma = { name, configured: true };
    }
    if (nameLower.includes('paper') || cmdStr.includes('paper')) {
      result.paper = { name, configured: true };
    }
    if (nameLower.includes('playwright') || cmdStr.includes('playwright')) {
      result.playwright = { name, configured: true };
    }
    if (nameLower.includes('chrome') || nameLower.includes('browser') || cmdStr.includes('chrome') || cmdStr.includes('puppeteer')) {
      result.chrome = { name, configured: true };
    }
    if (nameLower.includes('pencil') || cmdStr.includes('pencil')) {
      result.pencil = { name, configured: true };
    }
  }

  return result;
}

// Check multiple .mcp.json locations
const sources = [
  join(rootPath, '.mcp.json'),
  join(homedir(), '.claude', '.mcp.json'),
  join(homedir(), '.mcp.json'),
];

const tools = {};
const checkedPaths = [];

for (const src of sources) {
  if (existsSync(src)) {
    checkedPaths.push(src);
    const config = readJSON(src);
    if (config) {
      Object.assign(tools, detectMCPServers(config));
    }
  }
}

// Pencil — scan design/ folder for .pen files
const designDir = join(rootPath, 'design');
if (existsSync(designDir)) {
  const penFiles = readdirSync(designDir).filter(f => f.endsWith('.pen'));
  const libFile =
    penFiles.find(f => f.endsWith('.lib.pen') && f.includes('design-system')) ||
    penFiles.find(f => f.endsWith('.lib.pen')) ||
    null;
  const pageFiles = penFiles.filter(f => !f.endsWith('.lib.pen'));
  tools.pencil = {
    configured: false,
    ...tools.pencil,
    hasFiles: penFiles.length > 0,
    libFile: libFile ? `design/${libFile}` : null,
    pageFiles: pageFiles.map(f => `design/${f}`),
  };
}

// Check for active plan
let activePlan = null;
const plansDir = join(rootPath, 'docs', 'plans');
if (existsSync(plansDir)) {
  try {
    const dirs = readdirSync(plansDir, { withFileTypes: true })
      .filter(d => d.isDirectory())
      .map(d => d.name)
      .sort()
      .reverse();

    for (const dir of dirs) {
      const planFile = join(plansDir, dir, 'plan.md');
      if (existsSync(planFile)) {
        const content = readFileSync(planFile, 'utf8');
        if (content.includes('status: in-progress')) {
          activePlan = {
            path: `docs/plans/${dir}`,
            directory: dir,
            hasAssets: existsSync(join(plansDir, dir, 'assets')),
          };
          break;
        }
      }
    }
  } catch { /* ignore */ }
}

const result = {
  designTools: {
    paper: tools.paper || { configured: false },
    stitch: tools.stitch || { configured: false },
    figma: tools.figma || { configured: false },
    pencil: tools.pencil || { configured: false },
  },
  verificationTools: {
    playwright: tools.playwright || { configured: false },
    chrome: tools.chrome || { configured: false },
  },
  activePlan,
  checkedPaths,
};

console.log(JSON.stringify(result, null, 2));
process.exit(0);
