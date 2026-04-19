Deep reference for Livewire integration with Sage/Acorn/WordPress. Loaded on demand from `skills/acorn-livewire/SKILL.md`.

# Sage Integration — Acorn Boot, Layout, Blade Setup

## Install Packages

```bash
lando theme-composer require roots/acorn-livewire livewire/livewire
```

## Publish Configuration

```bash
lando acorn vendor:publish --tag=livewire:config
```

This creates `config/livewire.php` in the theme directory. Review it to set the component discovery namespace and view paths if needed.

## Add Livewire Directives to Your Layout

In `resources/views/layouts/app.blade.php`:

```blade
<!doctype html>
<html @php(language_attributes())>
  <head>
    @livewireStyles
    @head
  </head>
  <body @php(body_class())>
    @yield('content')
    @livewireScripts
    @footer
  </body>
</html>
```

**Critical:** `@livewireStyles` must be inside `<head>` and `@livewireScripts` must appear before the closing `</body>` tag. Livewire will not function if either is missing.

## Acorn Service Provider Boot

`roots/acorn-livewire` registers itself as an Acorn service provider. No manual binding is required. The provider:

1. Boots the Livewire core singleton inside the Acorn container
2. Registers Blade directives (`@livewireStyles`, `@livewireScripts`, `@livewire`)
3. Wires Livewire's HTTP endpoint into the WordPress request lifecycle

If Livewire components fail to render after install, confirm Acorn's `boot()` ran by checking `lando acorn about`.

## Creating Components

Always use the Artisan generator — never create files manually:

```bash
lando acorn make:livewire SearchFilter
# → app/Livewire/SearchFilter.php
# → resources/views/livewire/search-filter.blade.php

# Subdirectory notation
lando acorn make:livewire Forms/ContactForm
# → app/Livewire/Forms/ContactForm.php
# → resources/views/livewire/forms/contact-form.blade.php

# Inline component (no view file)
lando acorn make:livewire Counter --inline
```

Or use the helper script (validates PascalCase, checks lando availability):

```bash
bash skills/acorn-livewire/scripts/create-component.sh ContactForm
```

## Using Components in Blade Templates

```blade
{{-- Tag syntax (preferred) --}}
<livewire:post-search :post-type="$postType" />

{{-- With subdirectory --}}
<livewire:forms.contact-form />

{{-- Directive syntax --}}
@livewire('post-search', ['postType' => 'page'])
```

## Passing WordPress Data to Components

From a Sage View Composer:

```php
class ArchivePage extends Composer
{
    protected static $views = ['archive'];

    public function with(): array
    {
        return [
            'currentCategory' => get_queried_object_id(),
        ];
    }
}
```

In the Blade view:

```blade
<livewire:category-filter :category-id="$currentCategory" />
```

The component receives the value in `mount()`:

```php
public function mount(int $categoryId = 0): void
{
    $this->categoryId = $categoryId;
}
```

## WordPress Context in Components

Livewire components run inside the WordPress request lifecycle, so `get_current_user_id()` and `current_user_can()` work normally in most cases. However, if a component is used in a context where the user is not yet set (e.g., a REST-like endpoint or custom route), call:

```php
wp_set_current_user(get_current_user_id());
```

in `mount()` to ensure WP user functions return correct values.

## sage-html-forms vs Livewire

| Criteria | Livewire Form | sage-html-forms |
|---|---|---|
| **Complexity** | Multi-step, conditional logic, dynamic fields | Simple contact, newsletter, feedback |
| **Interactivity** | Real-time validation, dependent dropdowns | Submit and done |
| **File uploads** | Preview, progress, multi-file | Basic file input |
| **Caching** | Not page-cacheable (stateful) | Fully cacheable |
| **Examples** | Application forms, configurators, wizards | Contact form, newsletter signup |

Rule: if the form needs to react to user input before submission, use Livewire. Otherwise, use `sage-html-forms`.
