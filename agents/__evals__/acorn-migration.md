# Eval: acorn-migration

## Scenario

User prompt: "Analyze this legacy plugin and give me a migration plan to Acorn."
Context: plugin at `web/app/plugins/my-legacy-plugin/`

## Expected agent behaviour

1. Globs `web/app/plugins/*/` to find plugin entry points.
2. Reads main plugin file — checks for `register_post_type`, `add_action`, `add_filter`, `global $wpdb`, `WP_Query`.
3. Classifies patterns into migration categories (Service Provider, Eloquent Model, Route, Queue Job).
4. Produces a phased migration plan: Phase 1 (low risk), Phase 2 (data layer), Phase 3 (background work).
5. Each item names the source WP pattern AND the Acorn replacement with a code snippet.

## Pass criteria

- Migration phases clearly numbered and ordered by risk.
- Each item names source WP pattern AND Acorn replacement.
- No hallucinated Acorn APIs — all classes/methods exist in roots/acorn.
- "Stay-as-WP" section lists patterns not worth migrating.
- Output in en-US.
