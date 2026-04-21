# sage-forms — Traps

Three documented bugs that silently break form validation in this stack. Each has a confirmed reproduction and a concrete fix.

## T1 — `pattern` attribute backslash escaping in Blade components

### Symptom

Passing a regex-heavy `pattern` attribute to `x-form.input` produces broken HTML:

```blade
{{-- Source --}}
<x-form.input name="phone" pattern="\(\d{2}\)\s?\d{4,5}[-\s]?\d{4}" />
```

renders as:

```html
<input name="phone" pattern="\\(\d{2}\\)\s?\d{4,5}[-\s]?\d{4}">
```

The browser silently compiles the regex from the double-backslash string, which does not match any real phone format. `validity.patternMismatch` stays `false` for every value the user types — effectively no validation.

### Root Cause

Blade component attribute merging runs `htmlspecialchars()` on string attributes via `$attributes->merge()`. `htmlspecialchars()` encodes `&`, `<`, `>`, `"`, `'`, but Blade's tokenizer also preserves backslashes literally; when the attribute is round-tripped through the merge, the backslash gets doubled. The attribute string `\(` becomes `\\(` in output — a literal backslash followed by `(`, instead of an escaped parenthesis metacharacter.

### Fix

Do not pass `pattern` attributes with backslashes through `$attributes->merge()`. Instead, enforce the constraint in JS via the `validators` option:

```blade
{{-- Before (broken) --}}
<x-form.input type="text" name="phone" pattern="\(\d{2}\)\s?\d{4,5}[-\s]?\d{4}" />

{{-- After (works) --}}
<x-form.input type="text" inputmode="tel" name="phone" :required="true" />
```

```js
// In the block JS
initHfValidation(form, {
  messages: {
    phone: { customError: 'Formato inválido. Use (00) 00000-0000.' },
  },
  validators: {
    phone: (value) => /^\(\d{2}\)\s?\d{4,5}[-\s]?\d{4}$/.test(value),
  },
});
```

The JS validator fires on `blur` and re-validates on `input` while invalid — identical UX to a native `pattern` constraint, without the escaping trap.

### Detection signal (for the `forms` agent)

Grep form Blade views for `pattern="\` — any occurrence is a T1 hit.

---

## T2 — `type="tel"` skips `patternMismatch` in Chrome

### Symptom

Even with a correct, non-escaped `pattern` attribute (if T1 were not in play), Chrome does not flip `validity.patternMismatch` for `<input type="tel">`:

```html
<input type="tel" pattern="\d{10,11}">
```

Chrome accepts `abc` as "valid" — `patternMismatch` stays `false`. Firefox and Safari behave correctly, but Chrome's market share makes this effectively a production bug.

### Root Cause

Chrome's `type="tel"` implementation predates the full Constraint Validation API conformance for pattern matching. The input accepts any string to support international formats; Chrome chose to not enforce `pattern` for `tel` to avoid breaking locale-specific formats.

### Fix

Use `type="text"` with `inputmode="tel"`:

```blade
<x-form.input type="text" inputmode="tel" name="phone" :required="true" />
```

- `type="text"` — Constraint Validation API works normally; `pattern` (or JS validator) fires correctly.
- `inputmode="tel"` — mobile browsers show the numeric/tel keyboard on focus.

Users see the same keyboard; validation works in every browser.

### Detection signal (for the `forms` agent)

Grep form Blade views for `type="tel"` — any occurrence is a T2 hit (always).

---

## T3 — `ValidityState` is non-enumerable

### Symptom

Attempting to inspect the validity state by spreading returns an empty object:

```js
console.log({ ...field.validity });  // {}
console.log(Object.keys(field.validity));  // []
```

This broke early iterations of the `hf-validation` module when it tried to iterate validity keys dynamically.

### Root Cause

Per the HTML spec, `ValidityState` is a host object whose properties are defined with `enumerable: false` on the prototype. Spread (`...`) and `Object.keys()` only see own enumerable properties; they find none on `ValidityState` instances.

### Fix

Access properties directly:

```js
// Wrong
if (Object.keys(field.validity).some(k => field.validity[k])) { ... }

// Right
if (field.validity.valueMissing) { ... }
if (field.validity.tooShort) { ... }
if (field.validity.patternMismatch) { ... }
```

Or iterate a known list:

```js
const KEYS = ['valueMissing', 'tooShort', 'tooLong', 'typeMismatch', 'patternMismatch', 'rangeUnderflow', 'rangeOverflow', 'stepMismatch', 'badInput', 'customError'];
const firstFailure = KEYS.find(k => field.validity[k]);
```

### Detection signal (for the `forms` agent)

Grep JS modules for `{ ...` followed by `.validity` or `Object.keys(.*\.validity)` — any occurrence is a T3 hit.

---

## Trap Summary Table

| ID | Location | Detection grep | Fix |
|---|---|---|---|
| T1 | Form Blade view | `pattern="\` | Remove attribute; use JS validator |
| T2 | Form Blade view | `type="tel"` | `type="text" inputmode="tel"` |
| T3 | JS modules / block JS | `\{ \.\.\..*\.validity\|Object\.keys\(.*\.validity\)` | Access properties directly |

These are the three traps audited by the `forms` agent's A1/A2 axes. Any new occurrence in ongoing development should be caught on the next audit.
