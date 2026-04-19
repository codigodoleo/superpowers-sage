Deep reference for plan-generator anti-drift rules. Loaded on demand from `skills/plan-generator/SKILL.md`.

# Plan Generator — Anti-Drift Rules

Anti-drift rules that prevent plans from diverging from their spec — the AD-2 byte-for-byte gate and the patterns that violate plan integrity.

## AD-2 — Byte-for-Byte Gate (Blocking)

When the spec's "chosen approach" is "zero-migration port from legacy schema", emit
an **AD-2 byte-for-byte gate** in the plan for every ported component:

```markdown
## AD-2 — Byte-for-byte gate (blocking)

Before any code is written for a component that ports a legacy schema, run:

\`\`\`bash
# Compare legacy source with intended new file
git show <legacy-ref>:<legacy-path> > /tmp/legacy-current.php
diff -u /tmp/legacy-current.php <intended-new-path> | head -100
\`\`\`

The output must be EMPTY (except for namespace/import differences). Any field
name, type, or Builder chain that differs → BLOCK the commit and re-align.

This gate has prevented field key divergence (MD5 hash regressions) and post_content
re-hydration failures in real-world ports. Do not skip.
```

This block is emitted once per ported component, not per plan.

## Handoff Payload Validation (Preflight)

Before generating any plan files, validate the architecture spec against its claimed sources.
This catches handoff payload drift — where the spec claims field names, types, or shapes
that don't match reality.

**For each source referenced in the spec (e.g. `bkp_main:app/Fields/Foo.php`, legacy ACF JSON exports):**

1. If it's a git ref (`bkp_main:<path>`, `legacy:<ref>:<path>`):
   ```bash
   git show <ref>:<path> 2>/dev/null
   ```
   Read the actual file. Grep for `Builder::make`, `->addX(`, field names, class names.
   Compare against what the spec claims. If mismatch:
   ```
   ⛔ HANDOFF VALIDATION FAILED
   Spec claims field 'cta' on block PropostaValor.
   git show bkp_main:app/Fields/PropostaValor.php shows:
     ['cta_primario', 'cta_secundario'] (no 'cta').
   Reject the spec and request correction from architecture-discovery.
   ```

2. If it's an external API or DB schema:
   - Request the caller provide a sample response or schema file on disk
   - Read and cross-reference the spec's claimed field names/types

3. If the spec references content models (`content-model.md`):
   - Verify each CPT and ACF field group mentioned is classified
   - Flag unclassified content

**Never accept a spec silently.** Every claim about a legacy source MUST be verified.
Data loss from trusting stale handoff payloads is a documented failure mode (3 prevented
incidents in production — see feedback from interioresdecora.com.br).

## Plan Consistency Validation

After generating plan files, verify:

- Every component appears exactly once
- Every dependency has a source node
- No component is both parallel and sequential in the same stage
- Strategy aligns with risk/complexity
- Every interactive component has a visual checkpoint owner (`superpowers-sage:verifying` or `superpowers-sage:visual-verifier`)

## Failure Modes

- Spec missing or unapproved: block and request architecture approval.
- Dependency cycle detected: surface cycle and propose reordering.
- Incomplete component definitions: return to architecture spec for clarification.
- Too many cross-component dependencies: split into phased plan and mark phase gates.
- Missing visual artifacts despite visual-required components: mark visual checks as blocked and request refreshed architecture approval package.
