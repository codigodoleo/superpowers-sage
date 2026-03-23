---
name: superpowers-sage:reviewing
description: Code review against Sage/Acorn conventions and design alignment; checks providers, hooks, ACF patterns, Blade structure, content modeling decisions, and visual alignment with design. Dispatches sage-reviewer agent.
user-invocable: true
argument-hint: "[file path or scope]"
---

# Reviewing — Convention Audit + Design Alignment

Review code against Sage/Acorn conventions and verify alignment with design reference.

## Inputs

$ARGUMENTS

If no scope specified, review all changed files (`git diff` against base branch).

## Procedure

### 0) Determine scope

- If file path provided, review that file and related files
- If "all" or no argument, scan full project
- If active plan exists, focus on plan components

### 1) Convention checklist

#### Service Providers
- [ ] Providers extend `SageServiceProvider`
- [ ] `register()` only contains bindings (no hooks, no side effects)
- [ ] `boot()` contains hooks and initialization
- [ ] Dependencies injected via constructor

#### ACF Blocks & Fields
- [ ] Blocks created via `acf:block` generator
- [ ] `with()` returns only data the view needs
- [ ] `fields()` uses Builder API
- [ ] Block views use `$variable` not `get_field()`
- [ ] Reusable fields extracted to Partials

#### Blade Templates
- [ ] Composers for data injection, Components for reusable UI
- [ ] No business logic in Blade views
- [ ] Proper layout inheritance (`@extends`, `@section`, `@yield`)

#### Routes & Controllers
- [ ] Clean route declarations (no logic in closures)
- [ ] Thin controllers (delegate to services)
- [ ] Prefer Acorn Routes over `register_rest_route()`

#### Frontend
- [ ] Tailwind v4 CSS-first approach
- [ ] Assets referenced via `@vite()` or `Vite::asset()`
- [ ] Editor styles included

#### Hooks Placement
- [ ] `add_action`/`add_filter` in ServiceProvider `boot()`
- [ ] `setup.php` only for `after_setup_theme` essentials
- [ ] No hooks scattered in random files

#### Content Architecture
- [ ] Content that grows over time uses CPTs (not hardcoded arrays)
- [ ] CPTs defined in `config/poet.php` (not `register_post_type()`)
- [ ] Shared content uses Options Pages (not duplicated across blocks)

### 2) Design alignment (if plan exists)

If active plan has assets:
1. Read design reference from `assets/`
2. Compare implemented components with design
3. Flag visual drift

### 3) Report findings

```markdown
## Review: {scope}

### Critical (must fix)
- **{file}:{line}** — {issue}. See `{skill}`.

### Improvement (should fix)
- **{file}:{line}** — {issue}. See `{skill}`.

### Good Practices Found
- {positive observation}

### Design Alignment
- {component}: {MATCH/DRIFT} — {details}

### Summary
{X} critical, {Y} improvements, {Z} good practices.
```

### 4) After review

- Offer `finishing-a-development-branch` for merge/PR workflow
- Use base skills: `requesting-code-review`, `receiving-code-review`

## Key Principles
- **Reference the relevant skill** for every issue
- **Be specific** — file path and line number for every issue
- **Acknowledge good code** — don't just report problems
- **Check content architecture** — hardcoded dynamic content is a critical finding
