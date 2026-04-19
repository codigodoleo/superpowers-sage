# Plugin Expansion — Onda 6 Implementation Plan (scoped, conditional)

> **Status:** Scoped scaffolding. **Conditional on Onda 5 results** — this wave only activates if Onda 5's measurement shows real-world projects cannot use the official WP MCP Adapter stack (WP < 6.9, incompatible hosting, no Lando, etc.) and a custom fallback delivers measurable value.

**Goal:** Provide a co-located fallback MCP server (`sage-introspect`) for projects that cannot adopt the official Roots/WP AI stack.

**Architecture:** Node MCP server in `mcp/sage-introspect/`, distributed with the plugin, declared conditionally in `.mcp.json` only when `detect-ai-readiness.mjs` reports the official stack unavailable. Exposes a minimal tool surface mirroring (not duplicating) the official Adapter's core tools: post types, routes, Livewire components, ACF field groups, raw `wp_query` for read-only inspection.

**Tech Stack:** Node MCP SDK, MCP stdio transport, Lando-aware PHP inspection commands under the hood (`wp post-type list`, etc.).

**Source spec:** `docs/superpowers/specs/2026-04-18-plugin-expansion-design.md`
**Prerequisite:** Onda 5 deployed + measured; explicit go/no-go decision based on `onda-5-validation.md`.

---

## Microplan scope

| ID | Target | Output |
|---|---|---|
| 6.1 | API design | `mcp/sage-introspect/API.md` — tool surface, JSON schemas, error shapes, scope boundary (read-only, inspection only) |
| 6.2 | Implementation | `mcp/sage-introspect/server.js` + `package.json` + tests; conditional activation hook in `scripts/generate-project-mcp.mjs` (Onda 5's generator learns to emit a `sage-introspect` entry only when AI-readiness probe reports the official stack as unavailable) |

## Quality bar

**B**. Fallback is best-effort and optional. Ships with:
- Unit tests for each tool.
- Manual smoke against a Lando fixture project without Acorn AI installed.
- Clear docs noting that this is a stop-gap, not the recommended path.

## Dependencies

- Both microplans gated by explicit decision documented in `docs/superpowers/plans/onda-5-validation.md` → section "Fallback decision: go / no-go".
- 6.1 must complete before 6.2.

## Decision criteria (go / no-go)

Go if AT LEAST TWO of:
- ≥ 20% of observed user projects run WP < 6.9.
- ≥ 10% of projects run without Lando (WP MCP Adapter stdio setup gets awkward).
- Users explicitly request a fallback in issues/discussions after Onda 5 ships.
- Measurable token-reduction value when MCP is available is demonstrated, creating demand for a fallback to capture the same value where the official stack cannot run.

No-go if the official stack reaches > 90% of target user base and no clear fallback demand materializes.

## Tool surface (if built)

Minimum viable:
- `sage-introspect/list-post-types` — returns registered CPTs from `wp post-type list`.
- `sage-introspect/list-routes` — returns Acorn routes from `wp acorn route:list`.
- `sage-introspect/list-livewire-components` — scans `app/Livewire/` PHP classes.
- `sage-introspect/list-acf-field-groups` — from `wp acf list` (if ACF CLI present) or `wp option get` introspection.
- `sage-introspect/wp-query-read` — read-only WP_Query shim (sanitized args, limit 100 posts).

## Handoff note

If the go decision happens, expand both microplans to full TDD with JSON schema fixtures and MCP conformance tests.
