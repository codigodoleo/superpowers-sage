# Plugin Expansion — Onda 2 Implementation Plan (full TDD)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply progressive-disclosure pattern to the 26 skills not covered by Onda 1; audit YAML descriptions for trigger-richness; create shared templates; extend `validate-skills.mjs` to enforce structural rules.

**Architecture:** Same progressive-disclosure pattern from Onda 1 — `SKILL.md ≤ 500 lines` (hard), `references/*.md` for deep topics loaded on demand, `scripts/` for Lando-wrapped bash, `assets/` for PHP/Blade templates where applicable. Shared boilerplate moves to `templates/skill-references/` and `templates/skill-scripts/`. Validator learns to enforce structure.

**Tech Stack:** Markdown, bash scripts (Lando-wrapped), Node (`.mjs`), existing `scripts/validate-skills.mjs`.

**Source spec:** `docs/superpowers/specs/2026-04-18-plugin-expansion-design.md`
**Prerequisite:** Onda 1 complete + `onda-1-validation.md` published ✅

**Execution order:** 2.6 + 2.7 (parallel, infrastructure first) → 2.8 (validator, run LAST after all refactors) → 2.1 + 2.2 + 2.3 + 2.4 (parallel groups) → 2.5 (YAML audit, concludes wave)

**Skill inventory (Onda 2 scope — 26 skills):**

| Skill | Lines | Needs refs/ | Notes |
|---|---|---|---|
| acorn-commands | 222 | no | YAML + 3 refs + 1 script |
| acorn-redis | 290 | no | YAML + 4 refs + 1 script |
| acorn-logging | 290 | no | YAML + 3 refs |
| architecting | 80 | no | YAML only |
| architecture-discovery | 436 | **yes** | 2 refs |
| block-refactoring | 328 | **yes** | 2 refs |
| building | 299 | no | YAML only |
| debugging | 117 | no | YAML only |
| designing | 128 | no | YAML only |
| install-plugin | 114 | no | YAML only |
| migrating | 301 | **yes** | 2 refs |
| modeling | 108 | no | YAML only |
| onboarding | 141 | no | YAML only |
| plan-generator | 355 | **yes** | 2 refs |
| reviewing | 121 | no | YAML only |
| sage-design-system | 348 | **yes** | 2 refs |
| sage-lando | 384 | **yes (exists)** | Extend + 2 scripts + slim |
| sageing | 263 | no | YAML + mcp-query-patterns placeholder |
| verifying | 141 | no | YAML only |
| wp-block-native | 413 | **yes** | 4 refs |
| wp-capabilities | 186 | no | YAML only |
| wp-cli-ops | 369 | **yes** | 4 refs + 2 scripts |
| wp-hooks-lifecycle | 313 | **yes** | 3 refs |
| wp-phpstan | 248 | no | YAML only |
| wp-rest-api | 414 | **yes** | 4 refs |
| wp-security | 285 | no | YAML only |

---

## Microplan 2.6 — Shared reference + script templates

**Goal:** Create shared boilerplate that all skill refactors in this wave adopt, preventing format drift.

**Files:**
- Create: `templates/skill-references/loader-note.tpl.md`
- Create: `templates/skill-references/reference-structure.tpl.md`
- Create: `templates/skill-scripts/lando-check.sh`
- Create: `templates/skill-scripts/script-skeleton.sh`

**Quality bar:** B. `depends_on: []`. Unblocks 2.1–2.4 and 2.8.

### Task 2.6.1 — Create reference file templates

- [ ] **Step 1: Create `templates/skill-references/loader-note.tpl.md`**

```markdown
Deep reference for {{TOPIC}} in {{SKILL_CONTEXT}}. Loaded on demand from `skills/{{SKILL_NAME}}/SKILL.md`.

# {{TITLE}}

{{ONE_SENTENCE_INTRO}}

## {{FIRST_SECTION}}
```

- [ ] **Step 2: Create `templates/skill-references/reference-structure.tpl.md`**

```markdown
# Reference File Contract (superpowers-sage)

Every `references/*.md` file in a skill MUST follow this structure:

1. **Line 1**: Loader note — `Deep reference for <topic>. Loaded on demand from \`skills/<name>/SKILL.md\`.`
2. **Line 2**: Blank
3. **Line 3**: H1 title — `# <Title>`
4. **Line 4**: Blank
5. **Line 5**: One-sentence intro — describes what this reference covers and when to read it.
6. **Line 6**: Blank
7. **Line 7+**: First `## ` section heading

Constraints:
- No code before line 7.
- One-sentence intro must stand alone (not be a heading).
- Reference must make sense read in isolation from SKILL.md.
```

- [ ] **Step 3: Verify files exist**

Run: `ls templates/skill-references/`
Expected: both `.tpl.md` files listed.

- [ ] **Step 4: Commit**

```bash
git add templates/skill-references/
git commit -m "feat(templates): add shared reference file templates (2.6)"
```

### Task 2.6.2 — Create script boilerplate templates

- [ ] **Step 1: Create `templates/skill-scripts/lando-check.sh`**

```bash
#!/usr/bin/env bash
# Standard Lando availability check — paste at top of every skill script.
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH — run this from inside a Lando project" >&2
    exit 1
fi
```

- [ ] **Step 2: Create `templates/skill-scripts/script-skeleton.sh`**

```bash
#!/usr/bin/env bash
# {{DESCRIPTION}}
# Usage: {{SCRIPT_NAME}} <{{REQUIRED_ARG}}>
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2
    exit 1
fi
ARG="${1:?usage: {{SCRIPT_NAME}} <{{REQUIRED_ARG}}>}"
# --- implementation ---
lando {{COMMAND}} "$ARG"
echo "Done: {{SUCCESS_MESSAGE}}"
```

- [ ] **Step 3: Make executable**

```bash
chmod +x templates/skill-scripts/lando-check.sh templates/skill-scripts/script-skeleton.sh
```

- [ ] **Step 4: Commit**

```bash
git add templates/skill-scripts/
git commit -m "feat(templates): add shared script templates (2.6)"
```

---

## Microplan 2.8 — validate-skills.mjs structural enforcement

**Goal:** (a) Upgrade 500-line soft warning to a hard error; (b) warn when a skill ≥ 300 lines has no `references/` directory.

**⚠ Run Task 2.8.1 LAST — after all 2.1–2.4 skill refactors are complete, so no false errors fire.**

**Files:**
- Modify: `scripts/validate-skills.mjs`
- Modify: `scripts/test-validate-skills.mjs`

**Quality bar:** C. `depends_on: [2.1, 2.2, 2.3, 2.4]`.

### Task 2.8.1 — Upgrade 500-line soft warning to error

- [ ] **Step 1: Write the failing test**

In `scripts/test-validate-skills.mjs`, add `testOver500LineIsNowError`. The fixture: a 501-line valid SKILL.md. Expected: exit code non-zero.

```js
function testOver500LineIsNowError() {
  console.log('\nCase: skill file with >500 lines is an error (not warning)');
  const tmp = mkdtempSync(join(tmpdir(), 'validate-skills-500error-'));
  try {
    const src = resolve(__dirname, '..');
    cpSync(join(src, 'scripts'), join(tmp, 'scripts'), { recursive: true });
    mkdirSync(join(tmp, 'skills', 'fat-skill'), { recursive: true });
    const paddingCount = 501 - 10;
    const header = `---\nname: sage:fat-skill\ndescription: test\nuser-invocable: false\n---\n\n# Fat\n\n## Verification\n\n`;
    const footer = `\n## Failure modes\n\n- none\n`;
    const padding = Array.from({ length: paddingCount }, (_, i) => `<!-- ${i} -->`).join('\n');
    writeFileSync(join(tmp, 'skills', 'fat-skill', 'SKILL.md'), header + padding + footer);
    mkdirSync(join(tmp, 'agents'), { recursive: true });
    for (const f of ['.claude-plugin/plugin.json', '.cursor-plugin/plugin.json', 'plugin.json']) {
      const dest = join(tmp, f);
      mkdirSync(dirname(dest), { recursive: true });
      cpSync(join(src, f), dest);
    }
    const { stdout, exit } = runValidator(tmp);
    assert('exit code non-zero (error, not warning)', exit !== 0, `stdout: ${stdout.slice(-200)}`);
    assert('error message for fat-skill', stdout.includes('fat-skill/SKILL.md'), stdout.slice(-200));
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}
```

Add `import { dirname } from 'node:path';` if not already imported. Call `testOver500LineIsNowError()` in run section.

Run: `node scripts/test-validate-skills.mjs`
Expected: new test FAILS (validator currently exits 0 for >500 lines).

- [ ] **Step 2: Change warning to error in `validate-skills.mjs`**

Find:
```js
const lineCount = content.split(/\r?\n/).length;
if (lineCount > 500) {
  log('⚠', `${label} — ${lineCount} lines (>500 target)`);
  warnings++;
}
```

Replace with:
```js
const lineCount = content.split(/\r?\n/).length;
if (lineCount > 500) {
  log('✗', `${label} — ${lineCount} lines (max 500)`);
  errors++;
}
```

- [ ] **Step 3: Update the existing `testOver500LineWarning` test**

The existing test `testOver500LineWarning` in `test-validate-skills.mjs` currently asserts `exit === 0`. Update it to assert `exit !== 0` and update the message check from `⚠` prefix to the new `✗` prefix.

- [ ] **Step 4: Run tests**

Run: `node scripts/test-validate-skills.mjs`
Expected: all tests pass.

- [ ] **Step 5: Run validator on real repo — must be 0 errors**

Run: `node scripts/validate-skills.mjs`
Expected: 0 errors. If any skill is still > 500 lines, fix it before committing.

- [ ] **Step 6: Commit**

```bash
git add scripts/validate-skills.mjs scripts/test-validate-skills.mjs
git commit -m "feat(validate-skills): upgrade 500L soft warning to error (2.8)"
```

### Task 2.8.2 — Warn when ≥ 300L skill has no references/

- [ ] **Step 1: Write the failing test**

Add `testMissingRefsWarnedFor300LSkill` — fixture: 300-line valid SKILL.md, no `references/` directory. Expected: exit 0 (soft warning), warning message mentions missing `references/`.

```js
function testMissingRefsWarnedFor300LSkill() {
  console.log('\nCase: skill ≥300 lines with no references/ emits warning');
  const tmp = mkdtempSync(join(tmpdir(), 'validate-skills-norefs-'));
  try {
    const src = resolve(__dirname, '..');
    cpSync(join(src, 'scripts'), join(tmp, 'scripts'), { recursive: true });
    mkdirSync(join(tmp, 'skills', 'dense-skill'), { recursive: true });
    const paddingCount = 300 - 10;
    const header = `---\nname: sage:dense-skill\ndescription: test\nuser-invocable: false\n---\n\n# Dense\n\n## Verification\n\n`;
    const footer = `\n## Failure modes\n\n- none\n`;
    const padding = Array.from({ length: paddingCount }, (_, i) => `<!-- ${i} -->`).join('\n');
    writeFileSync(join(tmp, 'skills', 'dense-skill', 'SKILL.md'), header + padding + footer);
    mkdirSync(join(tmp, 'agents'), { recursive: true });
    for (const f of ['.claude-plugin/plugin.json', '.cursor-plugin/plugin.json', 'plugin.json']) {
      const dest = join(tmp, f);
      mkdirSync(dirname(dest), { recursive: true });
      cpSync(join(src, f), dest);
    }
    const { stdout, exit } = runValidator(tmp);
    assert('exit code 0 (warning, not error)', exit === 0, `stdout: ${stdout.slice(-200)}`);
    assert('warning mentions dense-skill and references/', stdout.includes('dense-skill') && stdout.includes('references/'), stdout.slice(-200));
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}
```

Run: `node scripts/test-validate-skills.mjs`
Expected: new test FAILS.

- [ ] **Step 2: Add structural check to `validate-skills.mjs`**

After the lineCount error check, add:

```js
if (lineCount >= 300) {
  const refsDir = join(skillsDir, entry.name, 'references');
  if (!existsSync(refsDir)) {
    log('⚠', `${label} — ${lineCount} lines but no references/ directory`);
    warnings++;
  }
}
```

- [ ] **Step 3: Run tests**

Run: `node scripts/test-validate-skills.mjs`
Expected: all tests pass.

- [ ] **Step 4: Run validator on real repo — 0 warnings about missing references/**

Run: `node scripts/validate-skills.mjs`
Expected: 0 warnings about missing `references/` (all Onda 2 refactors must be complete).

- [ ] **Step 5: Commit**

```bash
git add scripts/validate-skills.mjs scripts/test-validate-skills.mjs
git commit -m "feat(validate-skills): warn when ≥300L skill has no references/ (2.8)"
```

---

## Microplan 2.1 — Refactor `acorn-commands`, `acorn-redis`, `acorn-logging`

**Goal:** Apply progressive-disclosure to the three Acorn infrastructure skills (222–290 lines, under the 300L refs threshold). Focus: YAML improvements + light references for deepest topics + one automation script each.

**Files:**
- Modify: `skills/acorn-commands/SKILL.md`
- Create: `skills/acorn-commands/references/{scheduling,practical-examples,troubleshooting}.md`
- Create: `skills/acorn-commands/scripts/create-command.sh`
- Modify: `skills/acorn-redis/SKILL.md`
- Create: `skills/acorn-redis/references/{cache-config,cache-tags,session-queue,troubleshooting}.md`
- Create: `skills/acorn-redis/scripts/redis-health.sh`
- Modify: `skills/acorn-logging/SKILL.md`
- Create: `skills/acorn-logging/references/{channels,structured-logging,troubleshooting}.md`

**Quality bar:** B. `depends_on: [2.6]`.

### Task 2.1.1 — `acorn-commands` refactor

- [ ] **Step 1: Read current SKILL.md sections**

Run: `grep -n '^##' skills/acorn-commands/SKILL.md`

- [ ] **Step 2: Improve YAML description**

Replace frontmatter `description:` with:

```yaml
description: >
  Acorn CLI commands for WordPress automation — lando acorn make:command,
  artisan-style commands, Command::class, $signature, $description,
  handle() method, command arguments and options, output formatting,
  dependency injection in commands, calling other commands, AppServiceProvider
  registration, wp acorn schedule:run, scheduled commands, data import scripts,
  maintenance commands, theme automation tasks, lando acorn list
```

- [ ] **Step 3: Create `references/scheduling.md`**

Extract "Scheduling" and "Running Commands" sections. Structure:

```markdown
Deep reference for Acorn command scheduling and execution. Loaded on demand from `skills/acorn-commands/SKILL.md`.

# Command Scheduling and Execution

Acorn commands can be scheduled via the `Schedule` facade or triggered manually with `lando acorn`.

## Scheduling Commands

[moved content from SKILL.md "Scheduling" section]

## Running Commands Manually

[moved content from SKILL.md "Running Commands" section]

## wp-cron vs Action Scheduler vs Real Cron

When to use each in development vs production for scheduled commands.
```

- [ ] **Step 4: Create `references/practical-examples.md`**

Extract "Practical Examples" section. One-sentence intro: "Worked examples for the three most common Acorn command use cases: bulk data import, cache warm-up, and site maintenance."

- [ ] **Step 5: Create `references/troubleshooting.md`**

```markdown
Deep reference for debugging Acorn command failures. Loaded on demand from `skills/acorn-commands/SKILL.md`.

# Acorn Commands — Troubleshooting

Common errors when creating and running Acorn CLI commands in Lando.

## Command Not Found

Symptom: `lando acorn my:command` returns "Command not found."
Fix: Register in `AppServiceProvider::boot()`:
```php
$this->commands([\App\Console\Commands\MyCommand::class]);
```

## Dependency Injection Fails

Symptom: Constructor argument is null or throws "Target [Interface] is not instantiable."
Fix: Bind the interface in `AppServiceProvider::register()`.

## Schedule Not Running

Symptom: `lando acorn schedule:run` exits silently.
Fix: Verify `ScheduleServiceProvider` is registered and command frequency is correct.
```

- [ ] **Step 6: Create `scripts/create-command.sh`**

```bash
#!/usr/bin/env bash
# Create a new Acorn CLI command via Lando.
# Usage: create-command.sh <CommandName>
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2
    exit 1
fi
NAME="${1:?usage: create-command.sh <CommandName>}"
if [[ "$NAME" =~ ^[a-z] ]]; then
    echo "Error: CommandName must be PascalCase (e.g. ImportProducts)" >&2
    exit 1
fi
lando acorn make:command "$NAME"
echo "Created: app/Console/Commands/${NAME}.php"
echo "Register in: app/Providers/AppServiceProvider.php → boot() → \$this->commands([...])"
```

- [ ] **Step 7: Make script executable**

Run: `chmod +x skills/acorn-commands/scripts/create-command.sh`

- [ ] **Step 8: Slim SKILL.md — remove extracted sections, add reference links**

Remove "Scheduling", "Running Commands", "Practical Examples". Add:

```markdown
See [`references/scheduling.md`](references/scheduling.md) for scheduling setup and `lando acorn schedule:run`.
See [`references/practical-examples.md`](references/practical-examples.md) for import/maintenance/cache-warmup patterns.
See [`references/troubleshooting.md`](references/troubleshooting.md) for command not found, DI failures, schedule issues.
```

Verify: `wc -l skills/acorn-commands/SKILL.md` — should be ≤ 180 lines.

- [ ] **Step 9: Run validator**

Run: `node scripts/validate-skills.mjs`
Expected: exit 0.

- [ ] **Step 10: Commit**

```bash
git add skills/acorn-commands/
git commit -m "refactor(acorn-commands): add references/scripts, improve YAML triggers (2.1)"
```

### Task 2.1.2 — `acorn-redis` refactor

- [ ] **Step 1: Improve YAML description**

```yaml
description: >
  Redis caching, sessions, and queue driver in WordPress via Acorn — lando redis-cli,
  Cache::remember(), Cache::tags(), cache invalidation, WP object cache drop-in,
  wp_cache_set, wp_cache_get, Redis facade, session driver redis, REDIS_HOST,
  REDIS_PORT, Lando Redis service, predis, phpredis, queue connection redis,
  cache tags group invalidation, WP transient replacement, cache hit rate,
  lando wp cache type, object-cache.php drop-in
```

- [ ] **Step 2: Create `references/cache-config.md`**

Extract "Lando Configuration", "Cache Configuration", "Using the Cache", "Best Practices". One-sentence intro: "Full Lando service config, Laravel cache store setup, and `Cache::remember()` / `Cache::tags()` usage patterns for Redis in Acorn."

- [ ] **Step 3: Create `references/cache-tags.md`**

Extract "Cache Tags" section, add tag-based invalidation on `save_post`/`edited_term`. One-sentence intro: "Cache tags group related entries for atomic invalidation — the recommended pattern for post-type and taxonomy caches in Sage."

- [ ] **Step 4: Create `references/session-queue.md`**

Extract "Session Configuration" and "Queue Driver". One-sentence intro: "Configuring Redis as the session driver and queue connection in Acorn, with Lando service wiring."

- [ ] **Step 5: Create `references/troubleshooting.md`**

Cover: connection refused, object cache drop-in not installed, cache not persisting, session not working. Pattern: symptom → cause → fix.

- [ ] **Step 6: Create `scripts/redis-health.sh`**

```bash
#!/usr/bin/env bash
# Check Redis health in the current Lando project.
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2
    exit 1
fi
echo "=== Redis PING ==="
lando redis-cli ping
echo "=== Object Cache Status ==="
lando wp cache type 2>/dev/null || echo "WP-CLI unavailable"
echo "=== Memory Usage ==="
lando redis-cli info memory | grep used_memory_human
```

- [ ] **Step 7: Slim SKILL.md, verify ≤ 220 lines, run validator**

Run: `wc -l skills/acorn-redis/SKILL.md && node scripts/validate-skills.mjs`

- [ ] **Step 8: Commit**

```bash
git add skills/acorn-redis/
git commit -m "refactor(acorn-redis): add references/scripts, improve YAML triggers (2.1)"
```

### Task 2.1.3 — `acorn-logging` refactor

- [ ] **Step 1: Improve YAML description**

```yaml
description: >
  Logging in Acorn/WordPress — Log::debug(), Log::error(), Log::channel(),
  custom log channels, daily log files, stack channel, Slack log notifications,
  exception handling logging, WordPress debug.log integration, WP_DEBUG_LOG,
  structured logging, context arrays, monolog handlers, log levels,
  emergency info warning error debug, lando logs, lando ssh tail log
```

- [ ] **Step 2: Create `references/channels.md`**

Extract "Configuration", "Custom Channels", "Integration with WordPress Debug". One-sentence intro: "Custom Monolog channels, daily file rotation, Slack handler, and WordPress `debug.log` bridge configuration for Acorn logging."

- [ ] **Step 3: Create `references/structured-logging.md`**

Extract "Structured Logging Rules", "Best Practices". One-sentence intro: "Context arrays, log correlation IDs, and the structured logging conventions that make logs machine-parseable in Acorn/Sage projects."

- [ ] **Step 4: Create `references/troubleshooting.md`**

Cover: logs not appearing (WP_DEBUG_LOG not set), permission errors on log file, daily channel not rotating, Slack not notified. Pattern: symptom → cause → fix.

- [ ] **Step 5: Slim SKILL.md, verify ≤ 200 lines, run validator**

Run: `wc -l skills/acorn-logging/SKILL.md && node scripts/validate-skills.mjs`

- [ ] **Step 6: Commit**

```bash
git add skills/acorn-logging/
git commit -m "refactor(acorn-logging): add references, improve YAML triggers (2.1)"
```

---

## Microplan 2.2 — Refactor WP-family skills

**Goal:** Progressive-disclosure for 7 WP-prefixed skills. Four ≥ 300L need full references extraction; three < 300L get YAML improvements only.

**Heavy (≥ 300L):** `wp-cli-ops` (369L), `wp-hooks-lifecycle` (313L), `wp-rest-api` (414L), `wp-block-native` (413L)
**Light (< 300L):** `wp-phpstan` (248L), `wp-security` (285L), `wp-capabilities` (186L)

**Quality bar:** B. `depends_on: [2.6]`.

### Task 2.2.1 — `wp-cli-ops` refactor (369L)

- [ ] **Step 1: Improve YAML description**

```yaml
description: >
  WP-CLI operations via Lando — lando wp db export, lando wp db import,
  lando wp search-replace, lando wp search-replace --dry-run, lando wp user create,
  lando wp post list, lando wp plugin install, database management,
  maintenance mode, lando wp maintenance-mode activate, lando wp cache flush,
  lando wp cron event run, lando wp option update, lando wp transient delete,
  deploy checklist, preflight checks, destructive operations safety
```

- [ ] **Step 2: Create `references/db-operations.md`**

Extract database procedures (export, import, search-replace with `--skip-columns`, flush). One-sentence intro: "Database backup, restore, and search-replace workflows using `lando wp db` with preflight safety checks."

- [ ] **Step 3: Create `references/content-ops.md`**

Extract user management, post operations, option operations. One-sentence intro: "User creation, capability assignment, bulk post operations, and option manipulation via `lando wp`."

- [ ] **Step 4: Create `references/maintenance-deploy.md`**

Extract maintenance mode, cron, cache flush, transient cleanup. One-sentence intro: "Maintenance mode activation, cron execution, cache flushing, and transient cleanup — the standard deploy-day WP-CLI sequence."

- [ ] **Step 5: Create `references/preflight-checks.md`**

Extract and expand "Preflight checks for destructive operations". One-sentence intro: "Mandatory verification steps before any WP-CLI command that modifies or deletes data — backup, dry-run, and rollback confirmation."

- [ ] **Step 6: Create `scripts/db-backup.sh`**

```bash
#!/usr/bin/env bash
# Backup the WordPress database via Lando WP-CLI.
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2
    exit 1
fi
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILE="db-backup-${TIMESTAMP}.sql"
lando wp db export "$FILE" --porcelain
echo "Backup written: $FILE"
```

- [ ] **Step 7: Create `scripts/search-replace.sh`**

```bash
#!/usr/bin/env bash
# Search-replace across WordPress DB with dry-run guard.
# Usage: search-replace.sh <from> <to> [--live]
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2
    exit 1
fi
FROM="${1:?usage: search-replace.sh <from> <to> [--live]}"
TO="${2:?usage: search-replace.sh <from> <to> [--live]}"
LIVE="${3:-}"
if [[ "$LIVE" != "--live" ]]; then
    echo "DRY RUN (pass --live to apply):"
    lando wp search-replace "$FROM" "$TO" --dry-run --report-changed-only
else
    lando wp search-replace "$FROM" "$TO" --report-changed-only
fi
```

- [ ] **Step 8: Slim SKILL.md, add reference/script links, verify ≤ 250 lines**

Run: `wc -l skills/wp-cli-ops/SKILL.md && node scripts/validate-skills.mjs`

- [ ] **Step 9: Commit**

```bash
git add skills/wp-cli-ops/
git commit -m "refactor(wp-cli-ops): add references/scripts, improve YAML triggers (2.2)"
```

### Task 2.2.2 — `wp-hooks-lifecycle` refactor (313L)

- [ ] **Step 1: Improve YAML description**

```yaml
description: >
  WordPress hooks lifecycle — add_action, add_filter, remove_action, remove_filter,
  hook priority, plugins_loaded, init, wp_loaded, after_setup_theme,
  the_content filter, wp_enqueue_scripts, admin_enqueue_scripts, hook execution order,
  Acorn hook registration in AppServiceProvider, boot hooks, register hooks,
  WordPress hook reference, Tailwind CSS filter conflicts, save_post,
  transition_post_status, pre_get_posts, late hooks, early hooks
```

- [ ] **Step 2: Create `references/hook-timing.md`**

Extract hook execution order and early/late hook guidance. One-sentence intro: "WordPress boot sequence and which hooks fire when — the timing reference for registering CPTs, enqueuing assets, and running Acorn boot."

- [ ] **Step 3: Create `references/filter-gotchas.md`**

Extract "WordPress filters that bite modern CSS frameworks" and gotchas. One-sentence intro: "Filters that commonly cause unexpected behavior in Sage/Tailwind v4 themes — `the_content`, `oembed_result`, and Gutenberg block output filters."

- [ ] **Step 4: Create `references/acorn-hook-patterns.md`**

Extract Acorn-specific hook registration patterns. One-sentence intro: "The three correct places to hook in Acorn — `register()`, `boot()`, and dedicated provider classes — and which hook category belongs where."

- [ ] **Step 5: Slim SKILL.md, verify ≤ 220 lines, run validator**

- [ ] **Step 6: Commit**

```bash
git add skills/wp-hooks-lifecycle/
git commit -m "refactor(wp-hooks-lifecycle): add references, improve YAML triggers (2.2)"
```

### Task 2.2.3 — `wp-rest-api` refactor (414L)

- [ ] **Step 1: Improve YAML description**

```yaml
description: >
  WordPress REST API — register_rest_route, WP_REST_Controller, REST namespace,
  custom endpoints, Application Passwords, JWT REST authentication, permission_callback,
  schema validation, WP_REST_Response, REST API versioning, rest_ensure_response,
  coexistence with Acorn Routes, register_rest_route vs routes/web.php decision,
  REST API debugging, wp rest-api namespace list, wp json discovery, CORS,
  REST nonce, cookie auth, REST API disable, JSON schema validation
```

- [ ] **Step 2: Create `references/custom-endpoints.md`**

Extract custom endpoint registration patterns. One-sentence intro: "Full `register_rest_route()` examples with schema validation, permission callbacks, and both object-style and controller-style registration."

- [ ] **Step 3: Create `references/authentication.md`**

Extract REST authentication section. One-sentence intro: "Application Passwords, cookie/nonce auth, and JWT for REST API consumers — when to use each and the Lando test workflow."

- [ ] **Step 4: Create `references/acorn-coexistence.md`**

Extract "coexistence with Acorn Routes" section. One-sentence intro: "Decision matrix for when to use `register_rest_route()` versus Acorn Routes, and how both can coexist in the same Sage project."

- [ ] **Step 5: Create `references/troubleshooting.md`**

Common REST errors: 401 permission denied, CORS, rest_no_route, schema validation failures, 404 on custom namespace.

- [ ] **Step 6: Slim SKILL.md, verify ≤ 280 lines, run validator**

- [ ] **Step 7: Commit**

```bash
git add skills/wp-rest-api/
git commit -m "refactor(wp-rest-api): add references, improve YAML triggers (2.2)"
```

### Task 2.2.4 — `wp-block-native` refactor (413L)

- [ ] **Step 1: Improve YAML description**

```yaml
description: >
  Native Gutenberg blocks without ACF — block.json, edit.js, save.js,
  register_block_type, @wordpress/scripts, block attributes, InnerBlocks,
  useBlockProps, ServerSideRender, dynamic blocks PHP render_callback,
  block supports, block.json apiVersion 3, block variations, block styles,
  block transforms, React in block editor, wp_register_block_script_handle,
  Vite and WordPress blocks, native block vs ACF Composer block decision,
  block.json editorScript viewScript, @wordpress/block-editor
```

- [ ] **Step 2: Create `references/block-json-native.md`**

Extract `block.json` schema for native blocks (distinct from ACF Composer). One-sentence intro: "`block.json` fields for native Gutenberg blocks — apiVersion, attributes, supports, editorScript, viewScript, and the PHP/JS split."

- [ ] **Step 3: Create `references/edit-save.md`**

Extract `edit.js`/`save.js` patterns. One-sentence intro: "The `edit` function (interactive editor UI) and `save` function (static serialized output) — their contract, constraints, and when `ServerSideRender` replaces `save`."

- [ ] **Step 4: Create `references/dynamic-blocks.md`**

Extract dynamic blocks with PHP `render_callback`. One-sentence intro: "Dynamic blocks skip the `save` function and render via PHP — the recommended pattern for blocks that query WordPress data."

- [ ] **Step 5: Create `references/vite-integration.md`**

Extract Vite-and-WordPress-blocks section. One-sentence intro: "Building native blocks with Vite in a Sage theme — wiring `block.json` `editorScript` to a Vite entry point and avoiding `@wordpress/scripts` conflicts."

- [ ] **Step 6: Slim SKILL.md, verify ≤ 280 lines, run validator**

- [ ] **Step 7: Commit**

```bash
git add skills/wp-block-native/
git commit -m "refactor(wp-block-native): add references, improve YAML triggers (2.2)"
```

### Task 2.2.5 — YAML improvements for wp-phpstan, wp-security, wp-capabilities

- [ ] **Step 1: `wp-phpstan` (248L)**

```yaml
description: >
  PHPStan static analysis in Sage/Acorn projects — lando composer phpstan,
  phpstan.neon configuration, PHPStan level 0-9, WordPress PHP stubs,
  szepeviktor/phpstan-wordpress, baseline generation, CI phpstan,
  suppress errors, type errors, return type mismatch, nullable types,
  WordPress function stubs, WP_Post WP_Query WP_User types
```

- [ ] **Step 2: `wp-security` (285L)**

```yaml
description: >
  WordPress security hardening — nonce verification, wp_nonce_field,
  check_admin_referer, sanitize_text_field, sanitize_email, esc_html, esc_attr,
  esc_url, wp_kses, SQL injection prevention, $wpdb->prepare(), capability checks,
  current_user_can, authentication hardening, wp-config.php secrets,
  security headers, file permissions, Bedrock .env secrets, disable XML-RPC,
  brute force wp-login.php, CSRF protection
```

- [ ] **Step 3: `wp-capabilities` (186L)**

```yaml
description: >
  WordPress capabilities and roles — add_role, remove_role, add_cap, remove_cap,
  current_user_can, user_can, WP_Roles, custom capabilities, administrator editor
  author contributor subscriber, capability mapping, meta capabilities,
  map_meta_cap, register_post_type capabilities, custom post type capabilities,
  WP_User roles and caps, ACF field group visibility by role
```

- [ ] **Step 4: Run validator**

Run: `node scripts/validate-skills.mjs`
Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add skills/wp-phpstan/ skills/wp-security/ skills/wp-capabilities/
git commit -m "refactor(wp-*): improve YAML triggers for phpstan/security/capabilities (2.2)"
```

---

## Microplan 2.3 — Refactor workflow skills

**Goal:** Workflow/orchestrator skills — process-flow guides that reference other skills. Three over 300L need references extraction (architecture-discovery 436L, plan-generator 355L, migrating 301L). Nine under 300L get YAML-only treatment.

**Quality bar:** B. `depends_on: [2.6]`.

### Task 2.3.1 — `architecture-discovery` refactor (436L)

- [ ] **Step 1: Improve YAML description**

```yaml
description: >
  Architecture discovery for Sage/Acorn projects — map existing codebase,
  discover post types, routes, ACF field groups, Livewire components,
  Service Providers, identify architectural gaps, architecture decision records,
  ADR, component boundary map, data flow diagram, risk register,
  implementation sequencing, discovery session, understanding unknown codebases,
  use before architecting or building new features, output contract
```

- [ ] **Step 2: Create `references/output-contract.md`**

Extract the "Output Contract" section. One-sentence intro: "The structured output format for an architecture discovery session — sections, required fields, and the contract downstream skills consume."

- [ ] **Step 3: Create `references/discovery-procedures.md`**

Extract the detailed procedure phases. One-sentence intro: "Step-by-step discovery procedures for each output section — what to read, what to ask, and what to record for Overview, Requirements, Architecture Decisions, Components, Data Flow, and Risk Register."

- [ ] **Step 4: Slim SKILL.md, keep HARD GATES + procedure summary + links. Target ≤ 280 lines.**

- [ ] **Step 5: Commit**

```bash
git add skills/architecture-discovery/
git commit -m "refactor(architecture-discovery): add references, improve YAML triggers (2.3)"
```

### Task 2.3.2 — `plan-generator` refactor (355L)

- [ ] **Step 1: Improve YAML description**

```yaml
description: >
  Generate implementation plans from approved designs — plan-generator,
  phase-based plans, parallel batch execution, task dependency graph,
  owner skill routing, acceptance criteria, global done criteria,
  plan frontmatter, layout contract, interaction contract, anti-drift rules,
  plan format, AD-2 byte-for-byte gate, scope definition, execution plan,
  phases and batches, task anatomy, plan file format
```

- [ ] **Step 2: Create `references/plan-format.md`**

Extract "Plan Frontmatter Template", "Layout Contract", "Interaction Contract", output templates. One-sentence intro: "Complete plan file format specification — frontmatter fields, phase/batch structure, task anatomy, and the contract downstream executing skills consume."

- [ ] **Step 3: Create `references/anti-drift.md`**

Extract "Anti-Drift Notes" and AD-2 gate. One-sentence intro: "Anti-drift rules that prevent plans from diverging from their spec — the AD-2 byte-for-byte gate and the patterns that violate plan integrity."

- [ ] **Step 4: Slim SKILL.md, target ≤ 240 lines.**

- [ ] **Step 5: Commit**

```bash
git add skills/plan-generator/
git commit -m "refactor(plan-generator): add references, improve YAML triggers (2.3)"
```

### Task 2.3.3 — `migrating` refactor (301L)

- [ ] **Step 1: Improve YAML description**

```yaml
description: >
  WordPress migration to Sage/Acorn — migrate classic theme to Sage,
  incremental migration, 7-phase migration contract, rollback playbook,
  migration hard gates, functions.php to Service Providers, shortcodes to Blade,
  CPT registration to Poet, field groups to ACF Composer,
  safe migration reversible steps, migration output artifacts,
  legacy plugin to Acorn, wp-content to Bedrock structure
```

- [ ] **Step 2: Create `references/rollback-playbook.md`**

Extract rollback section. One-sentence intro: "Step-by-step rollback procedure for each migration phase — how to revert cleanly if a phase fails mid-execution."

- [ ] **Step 3: Create `references/phase-detail.md`**

Extract 7-phase contract. One-sentence intro: "Full detail for each of the 7 migration phases — preconditions, deliverables, and validation steps before advancing."

- [ ] **Step 4: Slim SKILL.md, target ≤ 200 lines.**

- [ ] **Step 5: Commit**

```bash
git add skills/migrating/
git commit -m "refactor(migrating): add references, improve YAML triggers (2.3)"
```

### Task 2.3.4 — YAML improvements for remaining workflow skills (9 skills, all < 300L)

- [ ] **Step 1: `building` (299L)**

```yaml
description: >
  Build a feature in a Sage/Acorn project — implement from an approved plan,
  write code, commit, iterate; orchestrates acorn-routes, acorn-livewire,
  acorn-eloquent, block-scaffolding, acorn-commands; TDD in Sage,
  implementation phase, commit hygiene, PR creation, incremental delivery,
  changelog entry, lando acorn, lando yarn build, lando yarn dev
```

- [ ] **Step 2: `architecting` (80L)**

```yaml
description: >
  Define architecture for a Sage/Acorn feature — architecture decision records,
  component boundaries, data flow, dependency mapping, pre-implementation design,
  trade-off analysis, Acorn architecture patterns, ADR, design before building
```

- [ ] **Step 3: `designing` (128L)**

```yaml
description: >
  Design UI/UX in a Sage project — Figma to Blade, design tokens to Tailwind v4,
  Paper/Figma MCP integration, component design, layout design, responsive design,
  design-to-code workflow, visual design review, design system alignment,
  design approval before implementation
```

- [ ] **Step 4: `verifying` (141L)**

```yaml
description: >
  Verify implemented work meets acceptance criteria — run tests, check PHPCS,
  validate Blade output, lando phpunit, lando phpcs, lando yarn test,
  Playwright tests, accessibility check, post-implementation verification,
  done criteria validation, checklist review, verification phase
```

- [ ] **Step 5: `reviewing` (121L)**

```yaml
description: >
  Code review for Sage/Acorn projects — review PHP Blade JS CSS,
  review Service Providers ACF Composer blocks Livewire components,
  Eloquent models Acorn routes, security review, performance review,
  code quality, coding standards, PR review workflow, code review checklist
```

- [ ] **Step 6: `debugging` (117L)**

```yaml
description: >
  Debug issues in Sage/Acorn/Lando projects — PHP errors, Blade rendering errors,
  Livewire mount failures, Eloquent query errors, Acorn boot errors,
  queue job failures, middleware blocking, WP hook conflicts,
  lando logs, Query Monitor, Xdebug, lando php -r, WP_DEBUG, debug session
```

- [ ] **Step 7: `modeling` (108L)**

```yaml
description: >
  Content modeling for Sage/Bedrock — classify as CPT ACF fields Blade component
  Livewire component or Options Page, Poet CPT configuration, ACF Composer fields
  vs GUI, relational content, static vs dynamic, content architecture decisions,
  config/poet.php, modeling before building, content classification matrix
```

- [ ] **Step 8: `onboarding` (141L)**

```yaml
description: >
  Onboard to a Sage/Acorn/Lando project — understand project structure,
  discover CPTs routes field groups Livewire components, lando start, lando info,
  project orientation, first session setup, read CLAUDE.md, activate skills,
  understand what exists before building, lando wp post-type list
```

- [ ] **Step 9: `install-plugin` (114L)**

```yaml
description: >
  Install WordPress plugins in Bedrock — lando composer require, Bedrock plugin
  management, composer.json for WP plugins, WP packagist, wpackagist-plugin,
  mu-plugins vs plugins, Bedrock plugin activation, composer.json repositories,
  lando wp plugin list, plugin compatibility, roots/wordpress-packagist
```

- [ ] **Step 10: Commit**

```bash
git add skills/building/ skills/architecting/ skills/designing/ skills/verifying/ \
        skills/reviewing/ skills/debugging/ skills/modeling/ skills/onboarding/ \
        skills/install-plugin/
git commit -m "refactor(workflow-skills): improve YAML trigger descriptions (2.3)"
```

---

## Microplan 2.4 — Refactor sage-ecosystem skills

**Goal:** Progressive-disclosure for the 4 Sage-specific skills. Three ≥ 300L need references; `sageing` (263L) gets YAML + MCP placeholder.

**Quality bar:** B. `depends_on: [2.6]`.

### Task 2.4.1 — `sage-lando` refactor (384L — already has references/)

`sage-lando` already has 9 reference files. Goal: ensure all have one-sentence intros, slim SKILL.md further, add automation scripts.

- [ ] **Step 1: Audit existing references — verify one-sentence intro on line 5 of each**

Run: `for f in skills/sage-lando/references/*.md; do echo "=== $f ==="; sed -n '3,6p' "$f"; done`
Expected: each shows H1 on line 3, intro sentence on line 5. Add missing intros.

- [ ] **Step 2: Improve YAML description**

```yaml
description: >
  Sage theme with Acorn (Laravel IoC for WordPress) and Lando — lando start,
  lando info, lando acorn, Service Providers, View Composers, Blade components,
  ACF Composer blocks and fields, Poet CPT config/poet.php, AppServiceProvider,
  ViewServiceProvider, resources/views/, resources/css/app.css @theme Tailwind v4,
  resources/js/app.js, web/app/themes/{theme-name}/, lando yarn dev, lando yarn build,
  Blade @extends @section @include @component, Bedrock directory structure,
  lando wp, composer require, lando composer
```

- [ ] **Step 3: Move "Canonical Lando Command Reference" to `references/lando-command-reference.md`**

If this section is in SKILL.md and no dedicated reference exists, extract it. One-sentence intro: "Quick-reference table of all Lando commands used in Sage/Acorn development — organized by category."

- [ ] **Step 4: Create `scripts/lando-status.sh`**

```bash
#!/usr/bin/env bash
# Print current Lando project status and Sage theme info.
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2
    exit 1
fi
echo "=== Lando Info ==="
lando info --format=table 2>/dev/null || lando info
echo ""
echo "=== WordPress Version ==="
lando wp core version 2>/dev/null || echo "WP-CLI unavailable"
echo ""
echo "=== Active Theme ==="
lando wp theme list --status=active --format=table 2>/dev/null || echo "WP-CLI unavailable"
```

- [ ] **Step 5: Create `scripts/check-stack.sh`**

```bash
#!/usr/bin/env bash
# Verify Sage/Acorn/Lando stack versions.
set -euo pipefail
if ! command -v lando >/dev/null 2>&1; then
    echo "lando not found on PATH" >&2
    exit 1
fi
echo "PHP:      $(lando php --version 2>/dev/null | head -1 || echo 'N/A')"
echo "WP:       $(lando wp core version 2>/dev/null || echo 'N/A')"
echo "Acorn:    $(lando composer show roots/acorn 2>/dev/null | grep 'versions' | head -1 || echo 'not installed')"
echo "Composer: $(lando composer --version 2>/dev/null | head -1 || echo 'N/A')"
echo "Node:     $(lando node --version 2>/dev/null || echo 'N/A')"
```

- [ ] **Step 6: Slim SKILL.md to ≤ 300 lines**

Run: `wc -l skills/sage-lando/SKILL.md && node scripts/validate-skills.mjs`

- [ ] **Step 7: Commit**

```bash
git add skills/sage-lando/
git commit -m "refactor(sage-lando): slim SKILL.md, add scripts, fix reference intros (2.4)"
```

### Task 2.4.2 — `sage-design-system` refactor (348L)

- [ ] **Step 1: Improve YAML description**

```yaml
description: >
  Design system implementation in Sage/Tailwind v4 — Figma to @theme tokens,
  design tokens CSS, Tailwind v4 @theme, color tokens, typography tokens,
  spacing scale, Blade UI components, kitchensink page, design-to-code,
  @layer base @layer components, CSS custom properties, resources/css/app.css,
  Paper MCP, Figma MCP, design file to code, SVG icons, responsive layout,
  design system audit, UI component library, atom design, layout components
```

- [ ] **Step 2: Create `references/tokens-setup.md`**

Extract Phase 0 (classify design file) and Phase 1 (design tokens). One-sentence intro: "How to classify a design file (Paper/Figma/CSS spec) and extract it into `@theme` tokens in `resources/css/app.css`."

- [ ] **Step 3: Create `references/component-phases.md`**

Extract Phase 2 (atoms), Phase 3 (layout), Phase 4 (kitchensink), Phase 5 (structural layouts). One-sentence intro: "Phases 2–5 of design system implementation — from atomic UI components to structural page layouts with Tailwind v4 and Blade."

- [ ] **Step 4: Slim SKILL.md, target ≤ 220 lines.**

- [ ] **Step 5: Commit**

```bash
git add skills/sage-design-system/
git commit -m "refactor(sage-design-system): add references, improve YAML triggers (2.4)"
```

### Task 2.4.3 — `block-refactoring` refactor (328L)

- [ ] **Step 1: Improve YAML description**

```yaml
description: >
  Refactor ACF Composer blocks — evolve blocks along 4 axes: rendering model,
  field composition, block variants $styles, InnerBlocks adoption; legacy block
  migration, ACF Composer v2 to v3, block phase classification, atomic vs container,
  block evolution report, get_block_wrapper_attributes, $styles, $innerBlocks,
  refactor without breaking existing content, block refactoring report
```

- [ ] **Step 2: Create `references/evolution-axes.md`**

Extract "The 4 evolution axes". One-sentence intro: "The four dimensions along which ACF Composer blocks evolve — rendering model, field composition, variant system, and InnerBlocks adoption — and when each upgrade is worth the cost."

- [ ] **Step 3: Create `references/report-format.md`**

Extract the "Block Refactoring: {ClassName}" report format. One-sentence intro: "The structured output format for a block refactoring report — current state assessment, proposed changes, migration risk, and rollback plan."

- [ ] **Step 4: Slim SKILL.md, target ≤ 220 lines.**

- [ ] **Step 5: Commit**

```bash
git add skills/block-refactoring/
git commit -m "refactor(block-refactoring): add references, improve YAML triggers (2.4)"
```

### Task 2.4.4 — `sageing` improvements (263L)

- [ ] **Step 1: Extend YAML description with MCP keywords**

Append to existing description: `, WordPress MCP Adapter, discover-abilities, execute-ability, Acorn AI, mcp-query-patterns, query-first workflow`

- [ ] **Step 2: Create `references/mcp-query-patterns.md` (placeholder for Onda 5)**

```markdown
Placeholder reference for MCP query patterns. Loaded on demand from `skills/sageing/SKILL.md`.

# MCP Query Patterns

This reference is populated by Onda 5 when the WordPress MCP Adapter + Acorn AI integration ships.

## When Available

When `detect-ai-readiness.mjs` reports `ready: true`, consult this reference before generating code that involves post types, routes, ACF field groups, or Livewire components — query first, generate second.

## Status

Onda 5 prerequisite — file will be expanded when `/ai-setup` ships.
```

- [ ] **Step 3: Add reference link in SKILL.md**

In the relevant section of `sageing/SKILL.md`, add:

```markdown
See [`references/mcp-query-patterns.md`](references/mcp-query-patterns.md) for query-before-generate patterns (populated by Onda 5).
```

- [ ] **Step 4: Commit**

```bash
git add skills/sageing/
git commit -m "refactor(sageing): add mcp-query-patterns placeholder, expand YAML triggers (2.4)"
```

---

## Microplan 2.5 — YAML trigger-richness audit

**Goal:** Verify all 34 skill descriptions are trigger-rich after 2.1–2.4. Produce report. Rewrite any remaining weak descriptions.

**Files:**
- Create: `docs/superpowers/plans/onda-2-yaml-audit.md`

**Quality bar:** B. `depends_on: [2.1, 2.2, 2.3, 2.4]`.

### Task 2.5.1 — Audit and report

- [ ] **Step 1: List all skill descriptions**

```bash
for d in skills/*/; do
    name=$(basename "$d")
    echo "### $name"
    awk '/^description:/{p=1} p && /^[a-z]/{print; if (!/description:/) p=0}' "$d/SKILL.md" | head -8
    echo
done
```

- [ ] **Step 2: Score each description**

For each skill, evaluate:
1. ≥ 5 concrete identifiers (command names, class names, config keys)?
2. Covers primary and secondary use cases?
3. Avoids generic terms without grounding?

Mark: ✅ Good | ⚠ Needs improvement | ❌ Needs rewrite

- [ ] **Step 3: Rewrite any remaining weak descriptions not covered in 2.1–2.4**

Apply the same pattern: frontmatter block scalar with `description: >` and specific identifiers.

- [ ] **Step 4: Write `docs/superpowers/plans/onda-2-yaml-audit.md`**

```markdown
# Onda 2 — YAML Trigger-Richness Audit

## Summary

| Skill | Before | After | Changed in |
|---|---|---|---|
| acorn-commands | ⚠ | ✅ | 2.1 |
| acorn-redis | ⚠ | ✅ | 2.1 |
| acorn-logging | ⚠ | ✅ | 2.1 |
| ... | ... | ... | ... |

## Audit Criteria

A description is ✅ if it names ≥ 5 concrete identifiers (lando commands, PHP class names, config keys) and covers the primary use case.

## Findings

<any remaining gaps not covered in 2.1–2.4>
```

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/plans/onda-2-yaml-audit.md
git commit -m "docs(onda-2): YAML trigger-richness audit report (2.5)"
```

---

## Onda 2 completion criteria

- [ ] All 26 remaining skills have improved YAML descriptions.
- [ ] All 10 skills ≥ 300 lines have `references/` populated.
- [ ] Shared templates exist in `templates/skill-references/` and `templates/skill-scripts/`.
- [ ] `validate-skills.mjs` errors on > 500L and warns on ≥ 300L without `references/` — 0 errors and 0 structural warnings on the real repo.
- [ ] All tests pass: `node scripts/test-validate-skills.mjs`.
- [ ] YAML audit report at `docs/superpowers/plans/onda-2-yaml-audit.md`.

When all boxes are checked, Onda 3 becomes unblocked. Proceed to expand `2026-04-18-plugin-expansion-onda-3.md` from scoped scaffolding to full TDD plan.
