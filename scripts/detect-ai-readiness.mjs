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
