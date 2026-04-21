# sage-forms — Blade Form Views

Complete pattern for rendering forms via Blade using HTML Forms + sage-html-forms. Covers the block field declaration, `with()` mapping, block view, form Blade view, and shared `x-form.*` component usage.

## Block Field Declaration

In the block's controller (`app/Blocks/{ClassName}.php`), declare a single `addPostObject` field scoped to the `html-form` CPT:

```php
public function fields(): array
{
    $fields = Builder::make('{slug}');

    $fields
        ->addPostObject('form', [
            'label'         => __('Form', 'sage'),
            'post_type'     => ['html-form'],
            'return_format' => 'object',
        ]);

    return $fields->build();
}
```

Key choices:

- `post_type` is `['html-form']` — scopes the dropdown to form posts only
- `return_format` is `'object'` — the view receives a `WP_Post` object, not an ID
- The field name is `form` — convention for every form-embedding block

## `with()` Mapping

Pass the form post to the view:

```php
public function with(): array
{
    return [
        'form' => get_field('form') ?: null,
    ];
}
```

The `?: null` fallback keeps the block renderable in the editor before the editor picks a form.

## Block View

Guard and render:

```blade
{{-- resources/views/blocks/{slug}.blade.php --}}
@if ($form)
    {!! hf_get_form($form->ID)->get_html() !!}
@endif
```

Required patterns:

- `@if ($form)` guard — avoids a fatal if the editor has not selected a form yet
- `{!! ... !!}` unescaped output — the HTML Forms plugin already renders sanitized markup
- No form-specific HTML in the block view — the form view owns that markup

## Form Blade View

The sage-html-forms bridge routes rendering to `resources/views/forms/{form-slug}.blade.php`, where `{form-slug}` is the `post_name` of the selected `html-form` post.

```blade
{{-- resources/views/forms/contact.blade.php --}}
<x-html-forms :form="$form">
    <x-form.field label="Name" for="name" :required="true">
        <x-form.input type="text" name="name" placeholder="Your full name" :required="true" minlength="2" />
    </x-form.field>

    <x-form.field label="WhatsApp" for="phone" :required="true">
        <x-form.input type="text" inputmode="tel" name="phone" placeholder="(00) 00000-0000" :required="true" />
    </x-form.field>

    <x-form.field label="Project type" for="project_type">
        <x-form.input type="text" name="project_type" placeholder="Residential, commercial, automation..." />
    </x-form.field>

    <x-form.field label="Message" for="message">
        <x-form.textarea name="message" placeholder="Tell us about your project..." :rows="5" />
    </x-form.field>

    <x-button type="submit" variant="primary" class="w-full">Submit</x-button>
</x-html-forms>
```

## `x-form.*` Component Catalogue

The design system provides form primitives in `resources/views/components/form/`:

| Component | Props (common) | Purpose |
|---|---|---|
| `x-form.field` | `label`, `for`, `required`, `error` | Wraps label + input + error span |
| `x-form.input` | `type`, `name`, `placeholder`, `required`, `minlength`, `inputmode` | Styled input; `id` defaults to `name` |
| `x-form.textarea` | `name`, `rows`, `placeholder`, `required` | Styled textarea |
| `x-html-forms` | `form` (`WP_Post`) | Outer wrapper; renders `<form action method>` attributes from the plugin |
| `x-button` | `type`, `variant`, `class` | Design-system button, used with `type="submit"` |

Using these eliminates form-specific CSS in the block — all borders, sizes, colors, focus states, and placeholder styles come from the design system.

## Accessibility

`x-form.field` renders:

- A `<label for="{for}">` tied to the input `id`
- An `aria-hidden="true"` asterisk when `:required="true"`
- An `[role="alert"]` span when the `error` prop is non-empty

The JS validation module (see `references/hf-validation.md`) dynamically injects the same `[role="alert"]` span on blur when the field is invalid.

## CSS Scoping

Form styling is inherited — the block CSS file should contain **zero** form-specific rules. If the block needs to scope form layout (e.g. a two-column split), use structural utilities on the form wrapper:

```css
block-contact-section .hf-form {
  @apply grid grid-cols-1 gap-4;
}
```

Anything that touches input borders, typography, placeholder color, or focus state belongs in the `x-form.*` components, not the block. If you find yourself writing `.hf-form input { border: ... }`, stop — the input is already styled.

## Anti-Patterns

| Wrong | Correct |
|---|---|
| Raw `<input>` / `<label>` in the form view | `x-form.field` + `x-form.input` |
| `wp_enqueue_style` for form-specific CSS in the block | Form styling is in the design-system component CSS |
| `pattern="\(\d{2}\)..."` on `x-form.input` | No `pattern` attribute — use a JS validator (see traps.md T1) |
| `type="tel"` with `pattern` constraint | `type="text" inputmode="tel"` (see traps.md T2) |
| Form markup inside the block view | Form markup lives in `resources/views/forms/{slug}.blade.php` |

## References

- [references/hf-validation.md](hf-validation.md) — JS validation module
- [references/traps.md](traps.md) — bug catalogue
- [references/installation.md](installation.md) — setup
