---
name: superpowers-sage:acorn-livewire
description: Livewire components in WordPress via Acorn; reactive forms, real-time validation, file uploads, and interactive UI without writing JavaScript
user-invocable: false
---

# Livewire in WordPress via Acorn

## Overview

Acorn Livewire brings Laravel Livewire into WordPress Sage themes, enabling reactive UI components — dynamic forms, real-time search, filters, modals — without writing JavaScript. Each Livewire component is a PHP class paired with a Blade view that stays in sync with the server via AJAX requests.

**Stack requirements:**
- **Sage** theme with **Acorn** (Laravel IoC for WordPress)
- **roots/acorn-livewire** — bridge package that registers Livewire inside Acorn
- **livewire/livewire** — the Livewire framework itself
- PHP 8.2+

## Setup

### Install packages

```bash
lando theme-composer require roots/acorn-livewire livewire/livewire
```

### Publish configuration

```bash
lando acorn vendor:publish --tag=livewire:config
```

This creates `config/livewire.php` in the theme directory.

### Add Livewire directives to your layout

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

**Critical:** `@livewireStyles` must be in the `<head>` and `@livewireScripts` must be before the closing `</body>` tag for Livewire to function.

## Creating Components

### Generator command

```bash
lando acorn make:livewire SearchFilter
# → app/Livewire/SearchFilter.php
# → resources/views/livewire/search-filter.blade.php
```

Subdirectory notation works the same as other Acorn generators:

```bash
lando acorn make:livewire Forms/ContactForm
# → app/Livewire/Forms/ContactForm.php
# → resources/views/livewire/forms/contact-form.blade.php
```

**Never create Livewire component files manually.** Always use the generator.

### Inline components

```bash
lando acorn make:livewire Counter --inline
# → app/Livewire/Counter.php (with inline render method, no view file)
```

## Component Anatomy

### Basic component class

```php
<?php

namespace App\Livewire;

use Livewire\Component;

class PostSearch extends Component
{
    public string $query = '';
    public string $postType = 'post';

    public function mount(string $postType = 'post'): void
    {
        $this->postType = $postType;
    }

    public function render(): \Illuminate\View\View
    {
        $posts = get_posts([
            'post_type' => $this->postType,
            's' => $this->query,
            'posts_per_page' => 10,
        ]);

        return view('livewire.post-search', [
            'posts' => $posts,
        ]);
    }
}
```

### Lifecycle hooks

| Hook | When it runs |
|---|---|
| `mount(...$params)` | Once, when component is first rendered. Receives parameters passed from Blade. |
| `hydrate()` | Every subsequent request, after component is rehydrated from state |
| `dehydrate()` | Every request, before response is sent back |
| `updated($property)` | After a specific property is updated |
| `updating($property)` | Before a property is updated |
| `updatedPropertyName()` | After a named property changes (camelCase convention) |

### Computed properties

```php
use Livewire\Attributes\Computed;

class CategoryFilter extends Component
{
    public int $categoryId = 0;

    #[Computed]
    public function posts(): array
    {
        return get_posts([
            'category' => $this->categoryId,
            'posts_per_page' => 12,
        ]);
    }

    public function render(): \Illuminate\View\View
    {
        return view('livewire.category-filter');
    }
}
```

Access in Blade with `$this->posts`:

```blade
@foreach ($this->posts as $post)
    <article>{{ $post->post_title }}</article>
@endforeach
```

## Data Binding

| Directive | Behavior |
|---|---|
| `wire:model="name"` | Syncs on form submission (deferred) |
| `wire:model.live="name"` | Syncs on every input event (sends HTTP request per keystroke) |
| `wire:model.blur="name"` | Syncs when the input loses focus |
| `wire:model.live.debounce.300ms="name"` | Syncs after 300ms of inactivity |

### Example — real-time search

```blade
{{-- resources/views/livewire/post-search.blade.php --}}
<div>
    <input
        type="text"
        wire:model.live.debounce.300ms="query"
        placeholder="Search posts..."
    />

    <ul>
        @forelse ($posts as $post)
            <li>
                <a href="{{ get_permalink($post) }}">
                    {{ $post->post_title }}
                </a>
            </li>
        @empty
            <li>No posts found.</li>
        @endforelse
    </ul>
</div>
```

**Important:** Every Livewire component view must have a single root element (typically a `<div>`).

## Actions

### Calling component methods

```blade
<button wire:click="addToCart({{ $product->ID }})">Add to Cart</button>
<button wire:click="$toggle('showFilters')">Toggle Filters</button>
```

### Common action directives

| Directive | Triggers on |
|---|---|
| `wire:click="method"` | Click event |
| `wire:submit="method"` | Form submission |
| `wire:keydown.enter="method"` | Enter key press |
| `wire:change="method"` | Input change |
| `wire:click.prevent="method"` | Click with `preventDefault()` |

### Example — WooCommerce-style mini cart

```php
<?php

namespace App\Livewire;

use Livewire\Component;

class MiniCart extends Component
{
    /** @var array<int, int> Product ID => quantity */
    public array $items = [];

    public function addItem(int $productId, int $qty = 1): void
    {
        $this->items[$productId] = ($this->items[$productId] ?? 0) + $qty;
    }

    public function removeItem(int $productId): void
    {
        unset($this->items[$productId]);
    }

    public function render(): \Illuminate\View\View
    {
        $products = [];
        foreach (array_keys($this->items) as $id) {
            $products[$id] = get_post($id);
        }

        return view('livewire.mini-cart', [
            'products' => $products,
        ]);
    }
}
```

## Forms

### Using Livewire Form objects

Form objects extract validation and state management out of the component.

```php
<?php

namespace App\Livewire\Forms;

use Livewire\Attributes\Validate;
use Livewire\Form;

class ContactFormData extends Form
{
    #[Validate('required|string|max:255')]
    public string $name = '';

    #[Validate('required|email')]
    public string $email = '';

    #[Validate('required|string|min:10|max:2000')]
    public string $message = '';

    #[Validate('required|in:general,support,sales')]
    public string $subject = 'general';
}
```

### Component using the Form object

```php
<?php

namespace App\Livewire;

use App\Livewire\Forms\ContactFormData;
use Livewire\Component;

class ContactForm extends Component
{
    public ContactFormData $form;

    public bool $submitted = false;

    public function submit(): void
    {
        $this->form->validate();

        // Store as WordPress post or send email
        wp_insert_post([
            'post_type' => 'contact_submission',
            'post_title' => $this->form->subject . ': ' . $this->form->name,
            'post_content' => $this->form->message,
            'post_status' => 'private',
            'meta_input' => [
                'contact_email' => $this->form->email,
            ],
        ]);

        $this->form->reset();
        $this->submitted = true;
    }

    public function render(): \Illuminate\View\View
    {
        return view('livewire.contact-form');
    }
}
```

### Form view with validation errors

```blade
{{-- resources/views/livewire/contact-form.blade.php --}}
<div>
    @if ($submitted)
        <div class="rounded-md bg-green-50 p-4">
            <p class="text-green-800">Thank you! We'll be in touch.</p>
        </div>
    @else
        <form wire:submit="submit">
            <div>
                <label for="name">Name</label>
                <input type="text" id="name" wire:model="form.name" />
                @error('form.name')
                    <p class="text-red-600 text-sm">{{ $message }}</p>
                @enderror
            </div>

            <div>
                <label for="email">Email</label>
                <input type="email" id="email" wire:model="form.email" />
                @error('form.email')
                    <p class="text-red-600 text-sm">{{ $message }}</p>
                @enderror
            </div>

            <div>
                <label for="subject">Subject</label>
                <select id="subject" wire:model="form.subject">
                    <option value="general">General Inquiry</option>
                    <option value="support">Support</option>
                    <option value="sales">Sales</option>
                </select>
                @error('form.subject')
                    <p class="text-red-600 text-sm">{{ $message }}</p>
                @enderror
            </div>

            <div>
                <label for="message">Message</label>
                <textarea id="message" wire:model="form.message" rows="5"></textarea>
                @error('form.message')
                    <p class="text-red-600 text-sm">{{ $message }}</p>
                @enderror
            </div>

            <button type="submit">Send Message</button>
        </form>
    @endif
</div>
```

### Real-time validation

Add `wire:model.blur` to validate on field blur:

```blade
<input type="email" wire:model.blur="form.email" />
```

Then add `updated()` to the component to validate per-field:

```php
public function updatedFormEmail(): void
{
    $this->form->validateOnly('email');
}
```

## File Uploads

### Component with file uploads

```php
<?php

namespace App\Livewire;

use Livewire\Attributes\Validate;
use Livewire\Component;
use Livewire\WithFileUploads;

class AvatarUpload extends Component
{
    use WithFileUploads;

    #[Validate('image|max:2048')] // 2MB max
    public $photo;

    public ?string $uploadedUrl = null;

    public function save(): void
    {
        $this->validate();

        // Store in WordPress uploads directory
        $uploadDir = wp_upload_dir();
        $path = $this->photo->store('avatars', 'public');

        // Or use WordPress media functions
        $attachmentId = media_handle_sideload([
            'name' => $this->photo->getClientOriginalName(),
            'tmp_name' => $this->photo->getRealPath(),
        ], 0);

        if (! is_wp_error($attachmentId)) {
            $this->uploadedUrl = wp_get_attachment_url($attachmentId);
            update_user_meta(get_current_user_id(), 'custom_avatar', $attachmentId);
        }

        $this->reset('photo');
    }

    public function render(): \Illuminate\View\View
    {
        return view('livewire.avatar-upload');
    }
}
```

### File upload view

```blade
<div>
    <form wire:submit="save">
        <input type="file" wire:model="photo" />

        @error('photo')
            <p class="text-red-600 text-sm">{{ $message }}</p>
        @enderror

        {{-- Preview before upload --}}
        @if ($photo)
            <img src="{{ $photo->temporaryUrl() }}" alt="Preview" class="mt-2 h-24 w-24 rounded-full object-cover" />
        @endif

        <button type="submit" wire:loading.attr="disabled" wire:target="photo">
            Upload
        </button>
    </form>
</div>
```

## Events

### Dispatching events from a component

```php
// Dispatch from PHP
$this->dispatch('post-updated', postId: $post->ID);

// Dispatch to a specific component
$this->dispatch('item-added', productId: $id)->to(MiniCart::class);

// Dispatch to self
$this->dispatch('refresh-data')->self();
```

### Listening for events

```php
use Livewire\Attributes\On;

class CartCounter extends Component
{
    public int $count = 0;

    #[On('item-added')]
    public function incrementCount(int $productId): void
    {
        $this->count++;
    }

    public function render(): \Illuminate\View\View
    {
        return view('livewire.cart-counter');
    }
}
```

### Dispatching from Blade / JavaScript

```blade
{{-- From Blade --}}
<button wire:click="$dispatch('open-modal', { id: 'confirm-delete' })">
    Delete
</button>

{{-- From JavaScript (for integration with third-party scripts) --}}
<script>
    Livewire.dispatch('post-selected', { postId: 42 });
</script>
```

## Loading States

### Basic loading indicators

```blade
<button wire:click="search">
    Search
    <span wire:loading wire:target="search">Searching...</span>
</button>
```

### CSS class toggling

```blade
<div wire:loading.class="opacity-50" wire:target="query">
    {{-- Content fades while loading --}}
</div>
```

### Skeleton screens

```blade
<div>
    <div wire:loading wire:target="categoryId">
        {{-- Skeleton placeholder --}}
        @for ($i = 0; $i < 3; $i++)
            <div class="animate-pulse">
                <div class="h-4 w-3/4 rounded bg-gray-200"></div>
                <div class="mt-2 h-3 w-1/2 rounded bg-gray-200"></div>
            </div>
        @endfor
    </div>

    <div wire:loading.remove wire:target="categoryId">
        {{-- Actual content --}}
        @foreach ($this->posts as $post)
            <article>{{ $post->post_title }}</article>
        @endforeach
    </div>
</div>
```

### Loading state modifiers

| Modifier | Effect |
|---|---|
| `wire:loading` | Show element while loading |
| `wire:loading.remove` | Hide element while loading |
| `wire:loading.class="opacity-50"` | Add CSS class while loading |
| `wire:loading.class.remove="opacity-100"` | Remove CSS class while loading |
| `wire:loading.attr="disabled"` | Add attribute while loading |
| `wire:target="methodName"` | Scope loading state to a specific action or model update |

## Using in Blade Templates

### Component tag syntax (preferred)

```blade
{{-- In any Sage Blade template --}}
<livewire:post-search :post-type="$postType" />

{{-- With subdirectory --}}
<livewire:forms.contact-form />
```

### Blade directive syntax

```blade
@livewire('post-search', ['postType' => 'page'])
```

### Passing WordPress data to Livewire components

From a View Composer or Blade template, pass data via component attributes:

```blade
{{-- In a Sage view --}}
<livewire:category-filter :category-id="get_queried_object_id()" />
```

From a View Composer:

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

```blade
{{-- resources/views/archive.blade.php --}}
<livewire:category-filter :category-id="$currentCategory" />
```

## Integration with sage-html-forms

`log1x/sage-html-forms` and Livewire forms serve different purposes. Use the right tool:

| Criteria | Livewire Form | sage-html-forms |
|---|---|---|
| **Complexity** | Multi-step, conditional logic, dynamic fields | Simple contact, newsletter, feedback |
| **Interactivity** | Real-time validation, dependent dropdowns, previews | Submit and done |
| **File uploads** | With preview, progress, multi-file | Basic file input |
| **Dependencies** | Requires Livewire (adds ~80KB JS) | Lightweight, minimal overhead |
| **Caching** | Not page-cacheable (stateful) | Fully cacheable |
| **Example use cases** | Application forms, product configurators, multi-step wizards | Contact form, newsletter signup, simple feedback |

**Rule of thumb:** If the form needs to react to user input before submission, use Livewire. If it only needs to collect data and submit, use sage-html-forms.

## Performance Considerations

### HTTP request overhead

Every `wire:model.live` input creates an HTTP request to the server. For a form with 5 fields using `wire:model.live`, that is 5 requests per interaction cycle.

**Mitigations:**
- Prefer `wire:model` (deferred) or `wire:model.blur` over `wire:model.live`
- Use `wire:model.live.debounce.500ms` when live updates are needed
- Batch related updates in a single method call

### Payload size

Livewire serializes all public properties on every request. Large datasets in public properties bloat the payload.

```php
// Bad — serializes 1000 posts on every request
public array $allPosts = [];

// Good — use computed properties (not serialized)
#[Computed]
public function posts(): array
{
    return get_posts(['posts_per_page' => 10, 'paged' => $this->page]);
}
```

### When Livewire is not the right tool

Switch to REST API + JavaScript when:
- The component updates more than once per second (live charts, real-time feeds)
- The dataset is very large and needs client-side virtual scrolling
- Offline support is required
- The interaction is purely client-side (tab switching, accordion, tooltip)

## When to Use Livewire vs Other Approaches

| Approach | Best for | Examples |
|---|---|---|
| **Livewire** | Interactive server-driven UI, forms with validation, real-time filtering | Post search with filters, multi-step forms, quiz builders, dynamic pricing tables, wishlist toggles |
| **Blade Component** | Static display, no interactivity needed | Cards, buttons, badges, hero sections, icon wrappers |
| **ACF Block** | Editor-managed content placed in Gutenberg | Hero banners, testimonial sliders, CTA sections |
| **REST API + JavaScript** | High-frequency updates, large datasets, offline support | Live dashboards, infinite scroll with 10k+ items, offline-first apps, drag-and-drop builders |
| **Alpine.js** | Client-only interactivity (no server needed) | Dropdowns, modals, tabs, accordions, toggle visibility |

### Combining Livewire with Alpine.js

Livewire ships with Alpine.js. You can use both in the same component:

```blade
<div>
    {{-- Livewire handles server state --}}
    <input type="text" wire:model.live.debounce.300ms="query" />

    {{-- Alpine handles client-only UI --}}
    <div x-data="{ showFilters: false }">
        <button @click="showFilters = !showFilters">
            Toggle Filters
        </button>
        <div x-show="showFilters" x-transition>
            <select wire:model.live="category">
                <option value="">All Categories</option>
                @foreach ($categories as $cat)
                    <option value="{{ $cat->term_id }}">{{ $cat->name }}</option>
                @endforeach
            </select>
        </div>
    </div>
</div>
```

Use Alpine for UI state that does not need the server (show/hide, transitions, local toggles). Use Livewire for state that must persist or query data.

## Common Mistakes

| Mistake | Correct approach |
|---|---|
| Missing root element in component view | Every Livewire view must have exactly one root element (`<div>...</div>`) |
| Storing large arrays/collections in public properties | Use `#[Computed]` properties or paginate server-side |
| Using `wire:model.live` on every input | Default to `wire:model` (deferred); use `.live` only when real-time feedback is needed |
| Forgetting `@livewireStyles` / `@livewireScripts` in layout | Both directives are required in `resources/views/layouts/app.blade.php` |
| Creating Livewire files manually | Always use `lando acorn make:livewire ComponentName` |
| Using Livewire for purely client-side interactions | Use Alpine.js for dropdowns, tabs, modals that need no server data |
| Not adding `wire:target` to loading states | Without a target, loading states activate on every request |
| Calling WordPress functions that expect the loop outside of it | Pass WordPress data into the component via `mount()` parameters |

## Verification

- Render the component in a Blade template and confirm it appears in the browser with the correct initial state.
- Interact with `wire:click`, `wire:submit`, or `wire:model` bindings and confirm the component updates reactively without a full page reload.
- Open browser DevTools Network tab and verify Livewire AJAX requests return 200 with the expected payload.

## Failure modes

### Problem: Component not found
- **Cause:** The component class namespace does not match the expected auto-discovery path, or the class name does not follow the naming convention (e.g., `ContactForm` class but trying to render `<livewire:contact-forms />`).
- **Fix:** Verify the class exists in `app/Livewire/` with the correct namespace (`App\Livewire`). Use the kebab-case tag that matches the class name: `ContactForm` becomes `<livewire:contact-form />`. Always generate components with `lando acorn make:livewire`.

### Problem: Hydration errors (non-serializable properties)
- **Cause:** A public property on the component holds a value that Livewire cannot serialize between requests -- such as closures, `WP_Post` objects, database connections, or resource handles.
- **Fix:** Store only scalar values, arrays, or simple objects in public properties. Use `#[Computed]` for derived data that should not be serialized. Pass WordPress objects into `mount()` and extract the needed scalar values.

## Escalation

- If Livewire AJAX payloads are excessively large (causing slow responses or timeouts), consult the `sage:wp-performance` skill for payload optimization and caching strategies.
- If you need purely client-side interactivity (dropdowns, tabs, modals) without server round-trips, use Alpine.js instead of Livewire.
