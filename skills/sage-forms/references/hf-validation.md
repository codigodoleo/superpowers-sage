# sage-forms — `hf-validation` JS Module

Reusable ES module layered on top of the HTML Forms plugin's AJAX submission pipeline. Provides progressive client-side validation without replacing the plugin's server-side handling.

## Location

One file per project (not per form):

```
resources/js/modules/hf-validation.js
```

Imported by each block JS that embeds a form:

```js
import { initHfValidation } from '../modules/hf-validation';
```

## Public API

```js
initHfValidation(formEl, {
  messages,    // { fieldName: { validityKey: 'localized message' } }
  validators,  // { fieldName: (value) => boolean }
  onSuccess,   // (formEl) => void — optional; called after hf-success
  onError,     // (formEl) => void — optional; called after hf-error
});
```

| Option | Type | Required | Purpose |
|---|---|---|---|
| `messages` | `Record<string, Record<string, string>>` | yes | Per-field, per-validity-key localized error strings |
| `validators` | `Record<string, (value: string) => boolean>` | no | Custom sync validators; return `true` if valid |
| `onSuccess` | `(formEl) => void` | no | Fired after the plugin's `hf-success` event |
| `onError` | `(formEl) => void` | no | Fired after the plugin's `hf-error` event |

### `messages` example

```js
const messages = {
  name: {
    valueMissing: 'Por favor, informe seu nome.',
    tooShort: 'Nome muito curto (mínimo 2 caracteres).',
  },
  phone: {
    valueMissing: 'Informe um telefone para contato.',
    customError: 'Formato de telefone inválido. Use (00) 00000-0000.',
  },
};
```

Keys under each field are names from `ValidityState`: `valueMissing`, `tooShort`, `tooLong`, `typeMismatch`, `patternMismatch`, `rangeUnderflow`, `rangeOverflow`, `stepMismatch`, `badInput`, `customError`.

### `validators` example

```js
const validators = {
  phone: (value) => /^\(\d{2}\)\s?\d{4,5}[-\s]?\d{4}$/.test(value),
};
```

A validator returning `false` triggers `customError` — the `messages.{field}.customError` entry becomes the displayed message.

## Validation Layers

The module layers four validation passes, ordered by when they fire:

1. **Native HTML5 constraints** — `required`, `minlength`, `maxlength`, `type`. The browser blocks the form submission before AJAX fires. Fastest feedback; no JS needed.
2. **`blur` handler** — on field exit, runs native `checkValidity()` then custom `validators[name]`. Injects the error span into the `x-form.field` wrapper. Skips optional fields that are empty.
3. **`input` handler** — fires only while `aria-invalid="true"` is set on the field. Re-validates as the user corrects the value; clears the error span when the field becomes valid. Avoids eager validation while the user is still typing.
4. **`hf-success` / `hf-error` events** — the HTML Forms plugin dispatches `CustomEvent`s on `<form>` after AJAX completes; the module scrolls `.hf-message` into view and invokes `onSuccess` / `onError`.

## HTML Forms Plugin DOM Events

| Event | Target | When | Notes |
|---|---|---|---|
| `hf-success` | `<form>` | AJAX returned success; `.hf-message.hf-success` has been injected into the DOM | Module scrolls the message into view and calls `onSuccess(formEl)` |
| `hf-error` | `<form>` | AJAX returned validation/server error; `.hf-message.hf-error` injected | Module scrolls and calls `onError(formEl)` |
| `hf-submitted` | `<form>` | Fires after either outcome | Not wired by default; use if you need analytics or double-submit protection |

## Error Element Injection

The module targets the wrapper div emitted by `x-form.field` (`<div class="flex flex-col gap-2">`) to inject the error span alongside label + input, matching the pattern the component uses for its static `$error` prop:

```js
const wrap = (field) => field.closest('.flex.flex-col');

function showError(field, msg) {
  let el = wrap(field).querySelector('[role="alert"]');
  if (!el) {
    el = document.createElement('span');
    el.className = 'text-[11px] text-error';
    el.setAttribute('role', 'alert');
    wrap(field).appendChild(el);
  }
  el.textContent = msg;
  field.classList.replace('border-border', 'border-error');
  field.setAttribute('aria-invalid', 'true');
}

function clearError(field) {
  const el = wrap(field).querySelector('[role="alert"]');
  if (el) el.remove();
  field.classList.replace('border-error', 'border-border');
  field.removeAttribute('aria-invalid');
}
```

If the project's `x-form.field` uses a different wrapper class, adjust `wrap()` accordingly — but prefer to align the component and the module on the same anchor.

## Full Module Skeleton

This is the scaffold produced by Phase 0c / the agent's scaffold mode when the file does not yet exist. The logic is minimal and functional; projects can extend with more validation layers if needed, but should not rewrite the core event wiring:

```js
// resources/js/modules/hf-validation.js
const wrap = (field) => field.closest('.flex.flex-col');

function showError(field, msg) {
  let el = wrap(field)?.querySelector('[role="alert"]');
  if (!el && wrap(field)) {
    el = document.createElement('span');
    el.className = 'text-[11px] text-error';
    el.setAttribute('role', 'alert');
    wrap(field).appendChild(el);
  }
  if (el) el.textContent = msg;
  field.classList.replace('border-border', 'border-error');
  field.setAttribute('aria-invalid', 'true');
}

function clearError(field) {
  const el = wrap(field)?.querySelector('[role="alert"]');
  if (el) el.remove();
  field.classList.replace('border-error', 'border-border');
  field.removeAttribute('aria-invalid');
}

function pickMessage(field, messages) {
  const perField = messages[field.name] || {};
  for (const key of ['valueMissing', 'tooShort', 'tooLong', 'typeMismatch', 'patternMismatch', 'customError']) {
    if (field.validity[key] && perField[key]) return perField[key];
  }
  return field.validationMessage;
}

function validateField(field, { messages, validators }) {
  const hasValue = field.value.trim().length > 0;
  if (!field.required && !hasValue) {
    clearError(field);
    return true;
  }

  field.setCustomValidity('');
  const nativeOk = field.checkValidity();
  const customOk = validators[field.name] ? validators[field.name](field.value) : true;

  if (!customOk) field.setCustomValidity('custom');

  if (!nativeOk || !customOk) {
    showError(field, pickMessage(field, messages));
    return false;
  }

  clearError(field);
  return true;
}

export function initHfValidation(formEl, opts = {}) {
  const { messages = {}, validators = {}, onSuccess, onError } = opts;
  const fields = formEl.querySelectorAll('input, textarea, select');

  fields.forEach((field) => {
    field.addEventListener('blur', () => validateField(field, { messages, validators }));
    field.addEventListener('input', () => {
      if (field.getAttribute('aria-invalid') === 'true') {
        validateField(field, { messages, validators });
      }
    });
  });

  formEl.addEventListener('hf-success', () => {
    formEl.querySelector('.hf-message')?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    if (onSuccess) onSuccess(formEl);
  });

  formEl.addEventListener('hf-error', () => {
    formEl.querySelector('.hf-message')?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    if (onError) onError(formEl);
  });
}
```

## Block JS Integration Example

```js
// resources/js/blocks/contact-section.js
import BaseCustomElement from '../core/BaseCustomElement.js';
import { initHfValidation } from '../modules/hf-validation';

export default class BlockContactSection extends BaseCustomElement {
  static tagName = 'block-contact-section';

  init() {
    const form = this.querySelector('.hf-form');
    if (!form) return;

    initHfValidation(form, {
      messages: {
        name:  { valueMissing: 'Informe seu nome.', tooShort: 'Mínimo 2 caracteres.' },
        phone: { valueMissing: 'Informe um telefone.', customError: 'Formato inválido.' },
      },
      validators: {
        phone: (v) => /^\(\d{2}\)\s?\d{4,5}[-\s]?\d{4}$/.test(v),
      },
    });
  }
}

BaseCustomElement.register(BlockContactSection);
```

## Why a Module, Not a Global Enqueue

- **Dedup** — Vite deduplicates imported modules automatically. Multiple blocks on the same page share one instance.
- **Scope** — each block's JS configures the module for its own form. No cross-form interference.
- **No WordPress enqueue boilerplate** — no `wp_enqueue_script` call, no handle management, no dependency declaration.
- **Tree-shaking** — unused exports are removed at build time.

## References

- [references/blade-form-views.md](blade-form-views.md) — form Blade view structure
- [references/traps.md](traps.md) — validation traps (T3 covers `ValidityState` non-enumerable)
