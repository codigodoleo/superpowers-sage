Deep reference for migrating phase procedures. Loaded on demand from `skills/migrating/SKILL.md`.

# Migrating — Phase Detail

Full detail for each of the 7 migration phases — preconditions, deliverables, and validation steps before advancing.

## Phase 1 — Snapshot BEFORE

**Precondition:** migration name resolved, target scope confirmed.

**Deliverable:** non-empty snapshot file(s) at `/tmp/<migration>-before.*`.

**Procedure:**

Posts / post_content:
```bash
lando wp post list --post_type=any --format=ids | xargs -I {} lando wp post get {} --format=xml > /tmp/<migration>-before.xml
# OR for a filtered scope
lando wp post list --post_type=page --post_status=publish --format=ids \
  | xargs -I {} lando wp post get {} --format=xml > /tmp/<migration>-before.xml
```

Postmeta for specific keys:
```bash
lando wp db export --tables=$(lando wp db prefix --skip-plugins --skip-themes)postmeta /tmp/<migration>-postmeta-before.sql
```

Terms / taxonomies:
```bash
lando wp term list <taxonomy> --format=json > /tmp/<migration>-terms-before.json
```

Full DB as belt-and-suspenders:
```bash
lando wp db export /tmp/<migration>-full-before.sql
```

**Validation before advancing:**
```bash
wc -l /tmp/<migration>-before.xml  # must be > 0
```

If any snapshot fails, STOP. Do NOT proceed.

## Phase 2 — Dry-Run Compute

**Precondition:** Phase 1 snapshot exists and is non-empty.

**Deliverable:** `/tmp/<migration>-dryrun.log` with BEFORE/AFTER summary for each row.

**Procedure:**
```bash
lando wp eval-file scripts/migrations/<migration>-dry-run.php
```

The dry-run script must:
1. Query target rows
2. Compute the intended new value
3. Print `BEFORE: <summary>` and `AFTER: <summary>` for each row
4. Summarize: N rows would change, M rows no-op
5. Never call `wp_update_*`, `wp_insert_*`, or raw `$wpdb->update()`

Save output: `lando wp eval-file ... > /tmp/<migration>-dryrun.log`

**Validation before advancing:** log is non-empty, row counts are reasonable.

## Phase 3 — Human Approval Gate

**Precondition:** dry-run log exists.

**Deliverable:** explicit user 'y' confirmation.

**Procedure:** pause and display:

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

**Validation before advancing:** explicit 'y' received. Do NOT proceed on silence, 'ok', or ambiguous input.

## Phase 4 — Preflight Checks

**Precondition:** approval gate passed.

**Deliverable:** preflight checks passed; orphan meta cleaned.

**4a) `_wp_page_template` orphan check** (for `wp_update_post` migrations):
```bash
for POST_ID in $(<list of target IDs>); do
  TPL=$(lando wp post meta get "$POST_ID" _wp_page_template 2>/dev/null)
  if [ -n "$TPL" ] && [ ! -f "wp-content/themes/$(lando wp option get stylesheet)/${TPL}" ]; then
    echo "⚠️  Post $POST_ID has orphan template: $TPL"
    lando wp post meta delete "$POST_ID" _wp_page_template
  fi
done
```

**4b) `wp_slash` backslash escape** (for `--post_content` writes):
Ensure backslashes in content are double-escaped BEFORE `wp_update_post`.

**4c) Revision pressure** (for bulk updates >50 rows):
```bash
# Temporarily disable revisions during bulk apply
lando wp eval 'define("WP_POST_REVISIONS", false);'
```

**Validation before advancing:** no orphan templates remain; slash escaping confirmed.

## Phase 5 — Apply

**Precondition:** all preflight checks passed.

**Deliverable:** `/tmp/<migration>-apply.log` with per-row UPDATED/SKIPPED/FAILED entries and final count summary.

**Procedure:**
```bash
lando wp eval-file scripts/migrations/<migration>-apply.php 2>&1 | tee /tmp/<migration>-apply.log
```

The apply script must:
1. Loop affected rows (from Phase 2's computation, not re-query)
2. Apply via `wp_update_post()` / `update_post_meta()` / `wp_update_term()` as appropriate
3. Log `UPDATED <id>` or `SKIPPED <id> (already correct)` per row
4. Track counts: `$updated`, `$skipped`, `$failed`
5. Emit summary at end: "Updated: N, Skipped: M, Failed: 0"

If any row fails, log the reason and continue — the snapshot allows rollback.

**Validation before advancing:** apply log exists, "Failed: 0" in summary.

## Phase 6 — Snapshot AFTER + Verify

**Precondition:** apply completed without fatal errors.

**Deliverable:** after snapshot + verification report; rollback initiated if checks fail.

**Re-capture:**
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

# 2. Spot-check 3 random sample rows
lando wp post get <ID> --field=post_content > /tmp/<migration>-sample-<ID>-after.html
# Compare against dry-run prediction

# 3. Shape sanity
lando wp post list --post_type=page --post_status=publish --format=count
# Should match row count from before
```

If ANY verification fails, restore from snapshot (see `references/rollback-playbook.md`).

**Validation before advancing:** row counts match, spot-check samples correct.

## Phase 7 — Idempotency Proof

**Precondition:** Phase 6 verification passed.

**Deliverable:** re-run produces "Updated: 0, Skipped: N, Failed: 0".

**Procedure:**
```bash
lando wp eval-file scripts/migrations/<migration>-apply.php
# Expected output: "Updated: 0, Skipped: N, Failed: 0"
```

If re-run updates any row, the apply logic is non-idempotent. Fix the skip condition and re-run until 0 updates.

**Validation:** output shows "Updated: 0".

## Output Artifacts

After all 7 phases complete, commit the reusable scripts:

- `/tmp/<migration>-before.xml` / `-before.sql` — pre-snapshot (not committed)
- `/tmp/<migration>-dryrun.log` — dry-run output (not committed)
- `/tmp/<migration>-apply.log` — apply progress (not committed)
- `/tmp/<migration>-after.xml` — post-snapshot (not committed)
- `scripts/migrations/<migration>-dry-run.php` — committed for traceability
- `scripts/migrations/<migration>-apply.php` — committed for traceability

```bash
git add scripts/migrations/<migration>-*.php
git commit -m "feat(migrations): <migration-name> — snapshot, dry-run, idempotent apply"
```
