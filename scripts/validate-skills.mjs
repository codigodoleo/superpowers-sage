#!/usr/bin/env node

import { readFileSync, existsSync, readdirSync, statSync } from "fs";
import { join, resolve } from "path";

const ROOT = resolve(import.meta.dirname, "..");
let errors = 0;
let warnings = 0;
let passed = 0;

function log(icon, msg) {
  console.log(`${icon} ${msg}`);
}

function parseFrontmatter(content) {
  // Accept both LF and CRLF line endings (Windows checkouts via Git Bash)
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return null;
  const fm = {};
  for (const line of match[1].split(/\r?\n/)) {
    const m = line.match(/^(\w[\w-]*):\s*(.+?)\s*$/);
    if (m) fm[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
  return fm;
}

// Validate skills
const skillsDir = join(ROOT, "skills");
if (existsSync(skillsDir)) {
  for (const entry of readdirSync(skillsDir, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const skillPath = join(skillsDir, entry.name, "SKILL.md");
    const label = `skills/${entry.name}/SKILL.md`;

    if (!existsSync(skillPath)) {
      log("✗", `${label} — file not found`);
      errors++;
      continue;
    }

    const content = readFileSync(skillPath, "utf8");
    const fm = parseFrontmatter(content);

    if (!fm) {
      log("✗", `${label} — missing YAML frontmatter`);
      errors++;
      continue;
    }

    if (!fm.name) {
      log("✗", `${label} — missing "name:" in frontmatter`);
      errors++;
      continue;
    }

    if (!fm.description) {
      log("✗", `${label} — missing "description:" in frontmatter`);
      errors++;
      continue;
    }

    if (
      !fm.name.startsWith("sage:") &&
      !fm.name.startsWith("wp-") &&
      !fm.name.startsWith("roots-") &&
      !fm.name.startsWith("superpowers-sage:")
    ) {
      log(
        "✗",
        `${label} — name "${fm.name}" must start with "sage:", "wp-", "superpowers-sage:", or "roots-"`,
      );
      errors++;
      continue;
    }

    passed++;
    log("✓", label);

    if (!content.includes("## Verification")) {
      log("⚠", `${label} — missing "## Verification" section`);
      warnings++;
    }
    if (!content.includes("## Failure modes")) {
      log("⚠", `${label} — missing "## Failure modes" section`);
      warnings++;
    }

    const lineCount = content.split(/\r?\n/).length;
    if (lineCount > 500) {
      log('⚠', `${label} — ${lineCount} lines (>500 target)`);
      warnings++;
    }
  }
}

// Validate plugin manifests
const pluginFiles = [
  [".claude-plugin/plugin.json", "Claude"],
  [".cursor-plugin/plugin.json", "Cursor"],
  ["plugin.json", "VSCode"],
];
const versions = {};

for (const [relPath, ide] of pluginFiles) {
  const fullPath = join(ROOT, relPath);
  const label = relPath;

  if (!existsSync(fullPath)) {
    log("✗", `${label} — file not found`);
    errors++;
    continue;
  }

  try {
    const data = JSON.parse(readFileSync(fullPath, "utf8"));
    const missing = ["name", "description", "version"].filter((k) => !data[k]);
    if (missing.length) {
      log("✗", `${label} — missing fields: ${missing.join(", ")}`);
      errors++;
    } else {
      log("✓", label);
      passed++;
      versions[ide] = data.version;
    }
  } catch (e) {
    log("✗", `${label} — invalid JSON: ${e.message}`);
    errors++;
  }
}

if (versions.Claude && versions.Cursor && versions.Claude !== versions.Cursor) {
  log(
    "✗",
    `Version mismatch: Claude=${versions.Claude}, Cursor=${versions.Cursor}`,
  );
  errors++;
}

if (versions.Claude && versions.VSCode && versions.Claude !== versions.VSCode) {
  log(
    "✗",
    `Version mismatch: Claude=${versions.Claude}, VSCode=${versions.VSCode}`,
  );
  errors++;
}

if (versions.Cursor && versions.VSCode && versions.Cursor !== versions.VSCode) {
  log(
    "✗",
    `Version mismatch: Cursor=${versions.Cursor}, VSCode=${versions.VSCode}`,
  );
  errors++;
}

// Validate agents
const agentsDir = join(ROOT, "agents");
if (existsSync(agentsDir)) {
  for (const entry of readdirSync(agentsDir, { withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith(".md")) continue;
    const agentPath = join(agentsDir, entry.name);
    const label = `agents/${entry.name}`;
    const content = readFileSync(agentPath, "utf8");
    const fm = parseFrontmatter(content);

    if (!fm?.name) {
      log("✗", `${label} — missing "name:" in frontmatter`);
      errors++;
    } else {
      log("✓", label);
      passed++;
    }
  }
}

// Summary
console.log(
  `\nSummary: ${passed} passed, ${warnings} warnings, ${errors} errors`,
);
process.exit(errors > 0 ? 1 : 0);
