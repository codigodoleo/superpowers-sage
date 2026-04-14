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
    if (nameLower === 'paper' || nameLower.includes('paper.design') || cmdStr.includes('paper-design') || cmdStr.includes('paper.design')) {
      result.paper = { name, configured: true };
    }
    if (nameLower.includes('playwright') || cmdStr.includes('playwright')) {
      result.playwright = { name, configured: true };
    }
    if (nameLower.includes('chrome') || nameLower.includes('browser') || cmdStr.includes('chrome') || cmdStr.includes('puppeteer')) {
      result.chrome = { name, configured: true };
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
