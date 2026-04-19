{{-- Livewire component view: {{VIEW_SLUG}}.blade.php
     REQUIRED: wrap everything in a single root <div>.
     Tailwind v4: use @theme tokens from app.css — no tailwind.config.js exists. --}}
<div>
    {{-- Loading spinner — scoped to this component's actions --}}
    <div wire:loading wire:target="save,search" class="text-sm text-gray-500">
        Loading...
    </div>

    {{-- Example: deferred model (syncs on form submit) --}}
    {{-- Use wire:model.live for real-time updates (one HTTP request per event) --}}
    <input
        type="text"
        wire:model="{{PROPERTY}}"
        placeholder="Enter value..."
        class="rounded border border-gray-300 px-3 py-2 text-sm"
    />

    {{-- Example action button --}}
    <button
        wire:click="save"
        wire:loading.attr="disabled"
        wire:target="save"
        class="mt-2 rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700 disabled:opacity-50"
    >
        Save
    </button>
</div>
