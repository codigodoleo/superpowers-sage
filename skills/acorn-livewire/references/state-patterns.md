Deep reference for Livewire state management patterns. Loaded on demand from `skills/acorn-livewire/SKILL.md`.

# State Patterns — wire:model, Computed Properties, Lifecycle Hooks

## wire:model Variants

| Directive | Behavior | When to use |
|---|---|---|
| `wire:model="name"` | Syncs on form submission (deferred) | Default for form fields |
| `wire:model.live="name"` | Syncs on every input event | Real-time search, instant feedback |
| `wire:model.blur="name"` | Syncs when input loses focus | Field-level validation |
| `wire:model.live.debounce.300ms="name"` | Syncs after 300ms of inactivity | Search inputs (avoids per-keystroke requests) |

**Performance rule:** Default to `wire:model` (deferred). Use `.live` only when the UX genuinely requires real-time server feedback. Each `.live` event triggers an HTTP request.

## Real-Time Search Example

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
            <li><a href="{{ get_permalink($post) }}">{{ $post->post_title }}</a></li>
        @empty
            <li>No posts found.</li>
        @endforelse
    </ul>
</div>
```

```php
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
            'post_type'      => $this->postType,
            's'              => $this->query,
            'posts_per_page' => 10,
        ]);

        return view('livewire.post-search', compact('posts'));
    }
}
```

## Computed Properties

Computed properties are not serialized between requests — they are re-evaluated on each render. Use them for derived data that would bloat the component payload if stored as a public property.

```php
use Livewire\Attributes\Computed;

class CategoryFilter extends Component
{
    public int $categoryId = 0;

    #[Computed]
    public function posts(): array
    {
        return get_posts([
            'category'       => $this->categoryId,
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

**Rule:** Never store large arrays (e.g. all posts) in public properties. Livewire serializes all public properties on every request. Use `#[Computed]` instead.

## Lifecycle Hooks

| Hook | When it runs |
|---|---|
| `mount(...$params)` | Once, when component is first rendered. Receives attributes from Blade tag. |
| `hydrate()` | Every subsequent request, after component is rehydrated from state |
| `dehydrate()` | Every request, before response is sent back |
| `updated($property)` | After any property is updated |
| `updating($property)` | Before a property is updated |
| `updatedPropertyName()` | After a specific named property changes (camelCase) |

### Per-Property Validation on Blur

```php
// Validates only the email field when it loses focus
public function updatedFormEmail(): void
{
    $this->form->validateOnly('email');
}
```

## Actions

```blade
<button wire:click="addToCart({{ $product->ID }})">Add to Cart</button>
<button wire:click="$toggle('showFilters')">Toggle Filters</button>
```

| Directive | Triggers on |
|---|---|
| `wire:click="method"` | Click event |
| `wire:submit="method"` | Form submission |
| `wire:keydown.enter="method"` | Enter key press |
| `wire:change="method"` | Input change |
| `wire:click.prevent="method"` | Click with `preventDefault()` |

## Loading States

```blade
{{-- Show spinner while loading --}}
<button wire:click="search">
    Search
    <span wire:loading wire:target="search">Searching...</span>
</button>

{{-- Fade content while model updates --}}
<div wire:loading.class="opacity-50" wire:target="query">
    <!-- results -->
</div>
```

| Modifier | Effect |
|---|---|
| `wire:loading` | Show element while loading |
| `wire:loading.remove` | Hide element while loading |
| `wire:loading.class="opacity-50"` | Add CSS class while loading |
| `wire:loading.attr="disabled"` | Add attribute while loading |
| `wire:target="methodName"` | Scope loading state to a specific action |

Always add `wire:target` — without it, loading states activate on every Livewire request on the page.

## Livewire Form Objects (v3)

Form objects extract validation and state from the component class:

```php
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
}
```

```php
class ContactForm extends Component
{
    public ContactFormData $form;
    public bool $submitted = false;

    public function submit(): void
    {
        $this->form->validate();

        wp_insert_post([
            'post_type'    => 'contact_submission',
            'post_title'   => $this->form->name,
            'post_content' => $this->form->message,
            'post_status'  => 'private',
            'meta_input'   => ['contact_email' => $this->form->email],
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

## Events Between Components

```php
// Dispatch from PHP
$this->dispatch('post-updated', postId: $post->ID);

// Dispatch to a specific component
$this->dispatch('item-added', productId: $id)->to(MiniCart::class);
```

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
}
```
