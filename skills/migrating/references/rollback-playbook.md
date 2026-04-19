Deep reference for migrating rollback procedures. Loaded on demand from `skills/migrating/SKILL.md`.

# Migrating — Rollback Playbook

Step-by-step rollback procedure for each migration phase — how to revert cleanly if a phase fails mid-execution.

## When to Roll Back

If post-verification anything is wrong, choose the lowest-impact tier that covers the failure scope.

## Tier 1 — WP Revisions (Single Post Regression)

Fastest recovery. Works only if revisions were enabled during apply (default: yes).

```bash
# List revisions for a post
lando wp post list --post_type=revision --post_parent=<POST-ID> --fields=ID,post_date,post_title

# Restore a revision (get content and update the post)
REVISION_CONTENT=$(lando wp post get <REVISION-ID> --field=post_content)
lando wp post update <POST-ID> --post_content="$REVISION_CONTENT"
```

**Use when:** a single post regressed and revisions are available.

## Tier 2 — Table-Level Restore

Restores a specific table from the pre-snapshot SQL dump.

```bash
lando wp db import /tmp/<migration>-postmeta-before.sql
```

**Use when:** the failure is scoped to postmeta and you have a table-level snapshot.

## Tier 3 — Full DB Restore (Nuclear)

Last-resort guarantee. Restores the entire database from the full pre-snapshot.

```bash
lando wp db import /tmp/<migration>-full-before.sql
```

**Use when:** Tier 1 and Tier 2 are insufficient, or the failure scope is unclear.

Always have the Tier 3 snapshot. Tier 1 and 2 are faster; Tier 3 is the guarantee.

## Rollback Decision Matrix

| Failure Scope | Tier | Command |
|---|---|---|
| Single post regression, revisions enabled | 1 | `wp post list --post_type=revision --post_parent=<ID>` then `wp post update` |
| Postmeta-only failure, table snapshot available | 2 | `wp db import postmeta-before.sql` |
| Multi-table or unclear scope | 3 | `wp db import full-before.sql` |
| Snapshot missing or failed | STOP | Do not proceed with migration — restart from Phase 1 |

## After Rolling Back

1. Verify rollback worked: check spot-sample rows match pre-snapshot values.
2. Investigate the failure: read the apply log at `/tmp/<migration>-apply.log`.
3. Fix the apply script's detection/skip predicate.
4. Re-run the full 7-phase cycle from Phase 1.

## Anti-Drift — Common Rollback Mistakes

| Wrong | Correct |
|---|---|
| Assume revisions are enabled | Verify revision count before relying on Tier 1 |
| Use Tier 3 before trying lower tiers | Try Tier 1 or 2 first for faster recovery |
| Delete the snapshot after successful apply | Keep snapshots until the idempotency check passes |
| Rollback only postmeta when post_content was also changed | Scope the rollback to all affected tables |
