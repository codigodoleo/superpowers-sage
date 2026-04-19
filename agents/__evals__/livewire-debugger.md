# Eval: livewire-debugger

## Scenario

User prompt: "My Livewire SearchBar component renders but doesn't update when I type."

## Expected agent behaviour

1. Reads `app/Http/Livewire/SearchBar.php` — checks `$query` property, `updatedQuery()` / `updated()` lifecycle, `wire:model` vs `wire:model.live`.
2. Reads corresponding Blade view — checks `wire:model` binding, `@livewireScripts` presence.
3. Checks routes/middleware for `web` group (required for CSRF/session).
4. Reports root cause with a concrete fix — e.g. "`wire:model` needs `.live` modifier for real-time updates in Livewire v3."
5. Suggests a prevention test: `Livewire::test(SearchBar::class)->set('query', 'foo')->assertSee(...)`.

## Pass criteria

- Root cause identified (not generic advice).
- Fix is a concrete code change (before/after).
- Prevention step included.
- Output in en-US.
