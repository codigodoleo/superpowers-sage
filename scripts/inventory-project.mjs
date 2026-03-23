#!/usr/bin/env node

import { readFileSync, existsSync, readdirSync, statSync } from 'fs';
import { join, relative, extname } from 'path';

const args = process.argv.slice(2);
const pathFlag = args.indexOf('--theme-path');
const themePath = pathFlag !== -1 ? args[pathFlag + 1] : null;

if (!themePath) {
  console.error('Usage: inventory-project.mjs --theme-path /path/to/theme');
  process.exit(1);
}

function globPhp(dir) {
  const results = [];
  if (!existsSync(dir)) return results;
  try {
    const entries = readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = join(dir, entry.name);
      if (entry.isDirectory()) {
        results.push(...globPhp(fullPath));
      } else if (entry.isFile() && extname(entry.name) === '.php') {
        results.push(fullPath);
      }
    }
  } catch { /* skip */ }
  return results;
}

function globBlade(dir) {
  const results = [];
  if (!existsSync(dir)) return results;
  try {
    const entries = readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = join(dir, entry.name);
      if (entry.isDirectory()) {
        results.push(...globBlade(fullPath));
      } else if (entry.isFile() && entry.name.endsWith('.blade.php')) {
        results.push(fullPath);
      }
    }
  } catch { /* skip */ }
  return results;
}

function extractClassName(filePath) {
  try {
    const content = readFileSync(filePath, 'utf8');
    const nsMatch = content.match(/namespace\s+([\w\\]+)/);
    const classMatch = content.match(/class\s+(\w+)/);
    if (nsMatch && classMatch) return `${nsMatch[1]}\\${classMatch[1]}`;
    if (classMatch) return classMatch[1];
  } catch { /* skip */ }
  return null;
}

function extractClasses(dir) {
  return globPhp(dir).map(extractClassName).filter(Boolean);
}

function countRoutes(filePath) {
  if (!existsSync(filePath)) return 0;
  try {
    const content = readFileSync(filePath, 'utf8');
    return (content.match(/Route::/g) || []).length;
  } catch { return 0; }
}

function parseProviders() {
  const configPath = join(themePath, 'config', 'app.php');
  if (!existsSync(configPath)) return [];
  try {
    const content = readFileSync(configPath, 'utf8');
    const matches = content.match(/[\w\\]+::class/g) || [];
    return matches.map(m => m.replace('::class', ''));
  } catch { return []; }
}

function parsePoet() {
  const poetPath = join(themePath, 'config', 'poet.php');
  if (!existsSync(poetPath)) return { post_types: [], taxonomies: [] };
  try {
    const content = readFileSync(poetPath, 'utf8');
    const postTypes = [];
    const taxonomies = [];

    let inPost = false;
    let inTaxonomy = false;

    for (const line of content.split('\n')) {
      if (/['"]post['"]\s*=>/.test(line)) { inPost = true; inTaxonomy = false; continue; }
      if (/['"]taxonomy['"]\s*=>/.test(line)) { inTaxonomy = true; inPost = false; continue; }
      if (/['"](?:admin_sidebar|block_category|block_pattern)['"]\s*=>/.test(line)) {
        inPost = false; inTaxonomy = false; continue;
      }

      const keyMatch = line.match(/['"](\w[\w-]*)['"]\s*=>/);
      if (keyMatch) {
        if (inPost) postTypes.push(keyMatch[1]);
        if (inTaxonomy) taxonomies.push(keyMatch[1]);
      }
    }

    return { post_types: postTypes, taxonomies };
  } catch { return { post_types: [], taxonomies: [] }; }
}

function categorizeViews() {
  const viewsDir = join(themePath, 'resources', 'views');
  const allViews = globBlade(viewsDir);
  const total = allViews.length;

  let layouts = 0, partials = 0, components = 0, blocks = 0;
  for (const v of allViews) {
    const rel = relative(viewsDir, v);
    if (rel.startsWith('layouts')) layouts++;
    else if (rel.startsWith('partials') || rel.includes('/_')) partials++;
    else if (rel.startsWith('components')) components++;
    else if (rel.startsWith('blocks')) blocks++;
  }

  return { total, layouts, partials, pages: total - layouts - partials - components - blocks, components, blocks };
}

// Main
const inventory = {
  blocks: extractClasses(join(themePath, 'app', 'Blocks')),
  components: extractClasses(join(themePath, 'app', 'View', 'Components')),
  livewire: extractClasses(join(themePath, 'app', 'Livewire')),
  providers: parseProviders(),
  routes: {
    web: countRoutes(join(themePath, 'routes', 'web.php')),
    api: countRoutes(join(themePath, 'routes', 'api.php')),
  },
  poet: parsePoet(),
  views: categorizeViews(),
};

console.log(JSON.stringify(inventory, null, 2));
