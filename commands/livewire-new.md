# /livewire-new

Scaffolds a new Livewire component via the project's create-component script.

## Usage

```
/livewire-new
```

You will be prompted for the component name.

## What it does

1. Asks: "Component name? (e.g. SearchBar, UserProfile)"
2. Runs: `bash skills/acorn-livewire/scripts/create-component.sh <ComponentName>`
3. Reports the files created (PHP class + Blade view).

## Requirements

- Livewire installed in the project.
- Run from the project root where `skills/acorn-livewire/scripts/` is accessible.

## Notes

- Component class goes in `app/Http/Livewire/` by default.
- Blade view goes in `resources/views/livewire/` by default.
- See the `acorn-livewire` skill for wiring events, properties, and Alpine.js integration.
