---
name: superpowers-sage:migrating
description: Safely execute destructive WordPress data migrations (post_content, postmeta, users, terms, attachments) with snapshot-before, dry-run diff, human approval gate, apply, snapshot-after verification, and idempotency check. Extracted from the W01 pattern validated in real projects.
user-invocable: true
argument-hint: "<migration-name> [target-scope]"
---

# Migrating — Safe Destructive Data Operations

Execute data migrations with full safety harness: snapshot, dry-run, gate, apply, verify, confirm idempotency. Never destructive-first.

**Announce at start:** "I'm using the migrating skill for a safe data migration with snapshot/dry-run/gate/apply/verify/idempotency checks."

## When to use

- `post_content` rewrites (injecting blocks, replacing shortcodes, updating markup)
- `wp_postmeta` cleanup (orphan keys, schema changes, re-computing derived values)
- Term taxonomy fixes (renaming, merging, re-assigning terms)
- Attachment regeneration (thumbnails, metadata, rewriting paths)
- User role migrations
- Bulk option updates with serialized data
- Any operation that could lose data if applied incorrectly

## When NOT to use

- Developer-only refactors that don't touch DB data (routes, hooks, CSS) — use `/building` or direct edits
- Simple one-shot admin tasks (delete one post, update one user) — use `lando wp` directly
- Schema changes at the table level (new columns, indexes) — use Laravel migrations or `acorn-eloquent` migrations
- Long-running pipelines with failure-retry needs — use `acorn-queues` with jobs

## Input

$ARGUMENTS

Resolve to a migration name (used for snapshot filenames and logs) and target scope.

---

## Hard gates

- **Never apply without snapshot-before.** If the snapshot step fails, STOP.
- **Never apply without human approval of the dry-run diff.** Autonomous apply is forbidden.
- **Never declare done without snapshot-after verification** proving row counts, field shapes, and spot-check samples match expectations.
- **Never leave the migration without idempotency proof.** Re-running it must be a no-op (0 rows changed).

---

## The 7-phase contract

```
┌─────────────────────────────────────────────────────────┐
│  1. SNAPSHOT BEFORE    → /tmp/<migration>-before.xml    │
├─────────────────────────────────────────────────────────┤
│  2. DRY-RUN COMPUTE    → list affected rows + new shape │
├─────────────────────────────────────────────────────────┤
│  3. HUMAN APPROVAL     → show diff, pause, await 'y'    │
├─────────────────────────────────────────────────────────┤
│  4. PREFLIGHT CHECKS   → orphan meta, template validity │
├─────────────────────────────────────────────────────────┤
│  5. APPLY              → loop, log progress, wp_slash() │
├─────────────────────────────────────────────────────────┤
│  6. SNAPSHOT AFTER     → /tmp/<migration>-after.xml     │
│     + VERIFY           → count + shape + spot-check     │
├─────────────────────────────────────────────────────────┤
│  7. IDEMPOTENCY CHECK  → re-run, assert 0 rows changed  │
└─────────────────────────────────────────────────────────┘
```

---

## Procedure

### Phase 1 — Snapshot BEFORE

Capture the target rows in a restorable format.

**Posts / post_content:**
```bash
lando wp post list --post_type=any --format=ids | xargs -I {} lando wp post get {} --format=xml > /tmp/<migration>-before.xml
# OR for a filtered scope
lando wp post list --post_type=page --post_status=publish --format=ids \
  | xargs -I {} lando wp post get {} --format=xml > /tmp/<migration>-before.xml
```

**Postmeta for specific keys:**
```bash
lando wp db export --tables=$(lando wp db prefix --skip-plugins --skip-themes)postmeta /tmp/<migration>-postmeta-before.sql
```

**Terms / taxonomies:**
```bash
lando wp term list <taxonomy> --format=json > /tmp/<migration>-terms-before.json
```

**Full DB as belt-and-suspenders:**
```bash
lando wp db export /tmp/<migration>-full-before.sql
```

Verify snapshot is non-empty:
```bash
wc -l /tmp/<migration>-before.xml  # must be > 0
```

If any snapshot fails, STOP. Do NOT proceed.

### Phase 2 — Dry-run compute

Write a script that computes the transformation WITHOUT applying. Emit the diff.

```bash
# Template — adapt per migration
lando wp eval-file scripts/migrations/<migration>-dry-run.php
```

The dry-run script should:
1. Query target rows
2. Compute the intended new value
3. Print `BEFORE: <summary>` and `AFTER: <summary>` for each row
4. Summarize: N rows would change, M rows no-op
5. Never call `wp_update_*`, `wp_insert_*`, or raw `$wpdb->update()`

Save the dry-run output to `/tmp/<migration>-dryrun.log` for the approval diff.

### Phase 3 — Human approval gate

**Pause and display:**

```
📋 Dry-run summary for <migration-name>:

Affected rows: N
Sample changes (first 5):
  ID 8:  post_content length 1234 → 1456 (delta +222 bytes)
  ID 12: post_content length 987  → 1120 (delta +133 bytes)
  ...

Full dry-run log: /tmp/<migration>-dryrun.log
Full snapshot: /tmp/<migration>-before.xml

Review the diff. Type 'y' to apply, anything else to abort.
```

Wait for explicit 'y' (or equivalent affirmative). Do NOT proceed on silence, 'ok', or any other input that could be accidental.

### Phase 4 — Preflight checks

Run known preflights that block common failures:

**4a) `_wp_page_template` orphan check** (for `wp_update_post` migrations):

```bash
# See @wp-cli-ops "Preflight checks for destructive operations" for the full script
for POST_ID in $(<list of target IDs>); do
  TPL=$(lando wp post meta get "$POST_ID" _wp_page_template 2>/dev/null)
  if [ -n "$TPL" ] && [ ! -f "wp-content/themes/$(lando wp option get stylesheet)/${TPL}" ]; then
    echo "⚠️  Post $POST_ID has orphan template: $TPL"
    lando wp post meta delete "$POST_ID" _wp_page_template
  fi
done
```

**4b) `wp_slash` backslash escape** (for `--post_content` writes):

Ensure backslashes in content are double-escaped BEFORE `wp_update_post`. See `@wp-cli-ops` for details.

**4c) Revision pressure** (for bulk updates >50 rows):

```bash
# Temporarily disable revisions during bulk apply
lando wp eval 'define("WP_POST_REVISIONS", false);'
# OR use remove_action wrapping
```

### Phase 5 — Apply

Run the apply script with progress logging:

```bash
lando wp eval-file scripts/migrations/<migration>-apply.php 2>&1 | tee /tmp/<migration>-apply.log
```

The apply script should:
1. Loop affected rows (from Phase 2's computation, not re-query)
2. Apply via `wp_update_post()` / `update_post_meta()` / `wp_update_term()` as appropriate
3. Log `UPDATED <id>` or `SKIPPED <id> (already correct)` per row
4. Track counts: `$updated`, `$skipped`, `$failed`
5. Emit summary at end: "Updated: N, Skipped: M, Failed: 0"

If any row fails, log the reason and continue (don't abort on individual failures — the snapshot allows rollback).

### Phase 6 — Snapshot AFTER + verify

**Re-capture the same targets:**

```bash
# Same command as Phase 1 but with -after suffix
lando wp post list --post_type=page --post_status=publish --format=ids \
  | xargs -I {} lando wp post get {} --format=xml > /tmp/<migration>-after.xml
```

**Verification checks:**

```bash
# 1. Row count matches expectation
COUNT_BEFORE=$(grep -c '<item>' /tmp/<migration>-before.xml)
COUNT_AFTER=$(grep -c  '<item>' /tmp/<migration>-after.xml)
[ "$COUNT_BEFORE" = "$COUNT_AFTER" ] || echo "❌ Row count mismatch: $COUNT_BEFORE -> $COUNT_AFTER"

# 2. Spot-check 3 random sample rows — read full before/after content
lando wp post get <ID> --field=post_content > /tmp/<migration>-sample-<ID>-after.html
# Manually compare or diff against what dry-run predicted

# 3. Shape sanity
lando wp post list --post_type=page --post_status=publish --format=count
# Should match row count from before
```

If ANY verification fails, **restore from snapshot**:

```bash
lando wp db import /tmp/<migration>-full-before.sql
```

Then investigate, fix the apply script, re-run the full 7-phase cycle.

### Phase 7 — Idempotency proof

**Re-run the apply script.** A correctly written migration should produce 0 changes on re-run:

```bash
lando wp eval-file scripts/migrations/<migration>-apply.php
# Expected output: "Updated: 0, Skipped: N, Failed: 0"
```

If re-run updates any row, the apply logic is non-idempotent (detect-and-skip predicate is wrong). Fix the skip condition and re-run until 0 updates.

---

## Rollback playbook

If post-verification anything is wrong:

### Tier 1 — WP revisions (single post regression)

```bash
lando wp post list-revisions <ID>
lando wp post revision-restore <REVISION-ID>
```

Works only if revisions were enabled during apply (default yes).

### Tier 2 — Table-level restore

```bash
lando wp db import /tmp/<migration>-postmeta-before.sql
```

### Tier 3 — Full DB restore (nuclear)

```bash
lando wp db import /tmp/<migration>-full-before.sql
```

Always have the Tier 3 snapshot. Tier 1 and 2 are faster recoveries; Tier 3 is the last-resort guarantee.

---

## Output artifacts

After completion, the migration leaves:

- `/tmp/<migration>-before.xml` / `-before.sql` — pre-snapshot
- `/tmp/<migration>-dryrun.log` — dry-run output
- `/tmp/<migration>-apply.log` — apply progress
- `/tmp/<migration>-after.xml` — post-snapshot
- `scripts/migrations/<migration>-dry-run.php` — reusable dry-run logic
- `scripts/migrations/<migration>-apply.php` — reusable apply logic
- Idempotency assertion in the apply log (0 updates on re-run)

Commit the two scripts (not the /tmp snapshots) to the repo for traceability:

```bash
git add scripts/migrations/<migration>-*.php
git commit -m "feat(migrations): <migration-name> — snapshot, dry-run, idempotent apply"
```

---

## Anti-drift — don't do this

| Wrong | Correct |
|---|---|
| Apply first, snapshot after | Snapshot BEFORE apply, always |
| Skip dry-run ("trust me") | Dry-run + diff always — no autonomous apply |
| Approve on silence | Explicit 'y' required; silence is not consent |
| Bulk `$wpdb->update()` without `wp_slash()` | `wp_slash()` for user content; `esc_sql()` for raw SQL |
| One-shot script with no idempotency check | Re-run after apply, assert 0 updates |
| Delete target rows before apply | Never; update in place, rollback via snapshot |
| Skip `_wp_page_template` preflight | Check orphan meta before `wp_update_post` on legacy posts |
| Apply without Tier-3 snapshot | `lando wp db export` full DB before any destructive op |
