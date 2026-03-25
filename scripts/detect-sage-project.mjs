#!/usr/bin/env node

import { readFileSync, existsSync, readdirSync, statSync } from 'fs';
import { join, resolve, relative } from 'path';

const args = process.argv.slice(2);
const pathFlag = args.indexOf('--path');
const rootPath = resolve(pathFlag !== -1 && args[pathFlag + 1] ? args[pathFlag + 1] : process.cwd());

function findComposerFiles(dir, depth = 0, maxDepth = 3) {
  if (depth > maxDepth) return [];
  const results = [];
  try {
    const entries = readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      if (['vendor', 'node_modules', '.git', 'storage'].includes(entry.name)) continue;
      const fullPath = join(dir, entry.name);
      if (entry.isFile() && entry.name === 'composer.json') {
        results.push(fullPath);
      } else if (entry.isDirectory()) {
        results.push(...findComposerFiles(fullPath, depth + 1, maxDepth));
      }
    }
  } catch { /* permission denied or similar */ }
  return results;
}

function readJSON(filePath) {
  try {
    return JSON.parse(readFileSync(filePath, 'utf8'));
  } catch { return null; }
}

function getInstalledVersion(lockPath, packageName) {
  const lock = readJSON(lockPath);
  if (!lock?.packages) return null;
  const pkg = lock.packages.find(p => p.name === packageName);
  return pkg?.version ?? null;
}

function getConstraint(composer, packageName) {
  return composer?.require?.[packageName] ?? composer?.['require-dev']?.[packageName] ?? null;
}

function detectLando(rootPath) {
  const landoFile = join(rootPath, '.lando.yml');
  if (!existsSync(landoFile)) return { detected: false };

  try {
    const content = readFileSync(landoFile, 'utf8');
    const services = [];
    const proxy = {};
    let inServices = false;
    let inProxy = false;
    let currentProxyService = null;

    for (const line of content.split('\n')) {
      if (/^services:/.test(line)) { inServices = true; inProxy = false; continue; }
      if (/^proxy:/.test(line)) { inProxy = true; inServices = false; continue; }
      if (/^\S/.test(line) && !/^#/.test(line)) { inServices = false; inProxy = false; }

      if (inServices && /^\s{2}\w+:/.test(line)) {
        services.push(line.trim().replace(':', ''));
      }
      if (inProxy && /^\s{2}\w+:/.test(line)) {
        currentProxyService = line.trim().replace(':', '');
        proxy[currentProxyService] = [];
      }
      if (inProxy && currentProxyService && /^\s{4}-\s/.test(line)) {
        proxy[currentProxyService].push(line.trim().replace(/^-\s*/, ''));
      }
    }

    return { detected: true, services, proxy };
  } catch {
    return { detected: true, services: [], proxy: {} };
  }
}

function detectProject(composerPath) {
  const composer = readJSON(composerPath);
  if (!composer) return null;

  const hasAcorn = getConstraint(composer, 'roots/acorn');
  if (!hasAcorn) return null;

  const dir = composerPath.replace(/\/composer\.json$/, '');
  const lockPath = join(dir, 'composer.lock');
  const hasLock = existsSync(lockPath);

  const getVersion = (pkg) => {
    if (hasLock) {
      const installed = getInstalledVersion(lockPath, pkg);
      if (installed) return installed;
    }
    return getConstraint(composer, pkg);
  };

  const packages = {};
  const checkPackages = [
    ['livewire', 'livewire/livewire'],
    ['livewire', 'roots/acorn-livewire'],
    ['acf-composer', 'log1x/acf-composer'],
    ['poet', 'log1x/poet'],
    ['navi', 'log1x/navi'],
    ['sage-directives', 'log1x/sage-directives'],
  ];

  for (const [key, pkg] of checkPackages) {
    if (packages[key]) continue;
    const version = getVersion(pkg);
    if (version) packages[key] = version;
  }

  const hasSage = getConstraint(composer, 'roots/sage');
  const phpConstraint = composer?.require?.php ?? composer?.config?.platform?.php ?? null;

  return {
    path: relative(rootPath, dir) || '.',
    type: hasSage ? 'sage-theme' : 'acorn-standalone',
    acorn: getVersion('roots/acorn') ?? hasAcorn,
    sage: hasSage ? (getVersion('roots/sage') ?? hasSage) : null,
    php: phpConstraint,
    packages,
  };
}

// Main
const composerFiles = findComposerFiles(rootPath);
const projects = composerFiles.map(detectProject).filter(Boolean);

if (projects.length === 0) {
  console.log(JSON.stringify({ detected: false }));
  process.exit(1);
}

// Determine active project (closest to cwd)
let activeProject = projects[0].path;
for (const p of projects) {
  if (p.path === '.') { activeProject = '.'; break; }
  if (p.path.length < activeProject.length) activeProject = p.path;
}

const lando = detectLando(rootPath);

const result = {
  detected: true,
  projects,
  lando,
  activeProject,
};

console.log(JSON.stringify(result, null, 2));
process.exit(0);
