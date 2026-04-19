Deep reference for Alpine.js + Livewire interop and Tailwind v4 coordination. Loaded on demand from `skills/acorn-livewire/SKILL.md`.

# Alpine.js + Livewire Interop

## When to Use Each

| Approach | Use for |
|---|---|
| **Livewire** | State that must persist server-side, server queries, form validation, paginated lists |
| **Alpine.js** | Client-only UI (dropdowns, modals, tabs, accordion, local toggle visibility) |
| **Both together** | Server state via Livewire + UI state via Alpine in the same component |

Livewire ships with Alpine.js — no separate install is needed.

## Combining Livewire with Alpine

Alpine manages client-only UI state; Livewire manages server state:

```blade
<div>
    {{-- Livewire handles server state --}}
    <input type="text" wire:model.live.debounce.300ms="query" />

    {{-- Alpine handles client-only show/hide --}}
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

## $wire.entangle — Shared State

`$wire.entangle` synchronizes an Alpine property with a Livewire public property. Changes in either direction are automatically reflected:

```blade
<div
    x-data="{ open: $wire.entangle('showModal') }"
    x-show="open"
>
    <!-- Modal content -->
</div>
```

```php
class ProductModal extends Component
{
    public bool $showModal = false;

    public function openModal(): void
    {
        $this->showModal = true;
    }
}
```

Use `$wire.entangle` when a UI state needs to be readable/writable from both Alpine and Livewire methods.

**Performance note:** Every `$wire.entangle` update triggers a Livewire network request. For purely client-side state (no server needs), use plain `x-data` instead.

## Accessing Livewire Properties from Alpine

```blade
<div x-data>
    <span x-text="$wire.count"></span>
    <button @click="$wire.increment()">+</button>
</div>
```

`$wire` is the Alpine magic property injected by Livewire. It exposes:
- `$wire.propertyName` — read a public property
- `$wire.methodName()` — call a Livewire method (returns a Promise)
- `$wire.entangle('propertyName')` — two-way binding

## Dispatching Livewire Events from Alpine / JavaScript

```blade
{{-- From an Alpine @click --}}
<button @click="$dispatch('open-modal', { id: 'confirm-delete' })">Delete</button>

{{-- From plain JavaScript --}}
<script>
    Livewire.dispatch('post-selected', { postId: 42 });
</script>
```

## Tailwind v4 Coordination

Tailwind v4 uses `@theme` directives in `resources/css/app.css` instead of `tailwind.config.js`. No config file exists.

**Livewire views can use all Tailwind utilities** that are included by Vite's content scanning. However:

- Dynamically constructed class names (e.g. `"text-{{ $color }}-500"`) will **not** be included by the scanner. Use full class names or explicit safelists.
- Prefer utility composition over `@apply` in Livewire view partials.
- Use `@theme` tokens for design system consistency in Livewire-rendered content.

```blade
{{-- Good: full class name Tailwind can scan --}}
<div class="text-red-500">Error</div>

{{-- Bad: dynamic class not scannable --}}
<div class="text-{{ $color }}-500">Error</div>

{{-- Good: conditional classes with ternary --}}
<div class="{{ $hasError ? 'text-red-500' : 'text-green-500' }}">Status</div>
```

## Loading States with Tailwind

```blade
{{-- Fade while loading --}}
<div
    wire:loading.class="opacity-50 pointer-events-none"
    wire:target="query"
    class="transition-opacity duration-150"
>
    @foreach ($results as $result)
        <div>{{ $result->post_title }}</div>
    @endforeach
</div>

{{-- Skeleton with Tailwind animate-pulse --}}
<div wire:loading wire:target="categoryId">
    @for ($i = 0; $i < 3; $i++)
        <div class="animate-pulse">
            <div class="h-4 w-3/4 rounded bg-gray-200"></div>
            <div class="mt-2 h-3 w-1/2 rounded bg-gray-200"></div>
        </div>
    @endfor
</div>
```

## When Livewire is Not the Right Tool

Switch to REST API + JavaScript when:
- The component updates more than once per second (live charts, real-time feeds)
- The dataset requires client-side virtual scrolling
- Offline support is needed
- The interaction is purely client-side (tab switching, accordion, tooltip) — use Alpine.js instead
