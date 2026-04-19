# Eval: tailwind-v4-auditor

## Scenario

User prompt: "Run the Tailwind v4 auditor on this theme."

## Expected agent behaviour

1. Reads `resources/css/app.css` — checks for `tailwind.config.js` reference, `theme()` calls, `@apply` usage.
2. Globs `resources/css/blocks/*.css` — checks for CSS variable declarations per block.
3. Globs `resources/views/components/*.blade.php` — checks for `match($tone)` / tone prop patterns.
4. Globs `resources/views/blocks/*.blade.php` — checks for arbitrary values and hardcoded color classes.
5. Returns a structured report with all four categories populated, severity-ranked.
6. Includes dark-mode readiness score: N/N blocks with CSS variable declarations.

## Pass criteria

- All four categories appear in the report.
- At least one finding reported per category (when run against a real project).
- No false positives on already-tokenized utility classes (e.g. `text-fg` is a token, not arbitrary).
- Dark-mode readiness score present.
- Report is in en-US.
