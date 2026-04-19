Deep reference for common Livewire errors in Sage/Acorn/WordPress. Loaded on demand from `skills/acorn-livewire/SKILL.md`.

# Common Livewire Errors

## "Unable to find component" / Component not found

**Cause:** The component class namespace does not match the auto-discovery path, or the Blade tag does not match the class name (PascalCase → kebab-case conversion).

**Fix:**
- Verify the class exists in `app/Livewire/` with namespace `App\Livewire`.
- Blade tag convention: `ContactForm` → `<livewire:contact-form />`, `Forms/ContactForm` → `<livewire:forms.contact-form />`.
- Always generate components with `lando acorn make:livewire ComponentName` — never create files manually.

```bash
# Wrong tag for class ContactForm
<livewire:contact-forms />   # plural — will fail

# Correct
<livewire:contact-form />
```

## Hydration Errors (non-serializable properties)

**Cause:** A public property holds a value Livewire cannot serialize between requests — closures, `WP_Post` objects, database connections, resource handles.

**Fix:**
- Store only scalar values, arrays, or simple plain objects in public properties.
- Use `#[Computed]` for derived data that should not be serialized.
- Pass WordPress objects into `mount()` and extract only the needed scalar values.

```php
// Bad — WP_Post is not serializable by Livewire
public \WP_Post $post;

// Good — store the ID and fetch in computed property
public int $postId;

#[Computed]
public function post(): ?\WP_Post
{
    return get_post($this->postId);
}
```

## 419 CSRF Token Expired

**Cause:** Livewire's AJAX requests require a valid Laravel CSRF token. If the session expires or the token is not present in the page, all Livewire requests return 419.

**Fix:**
- Ensure `@livewireScripts` is present in the layout. It injects the CSRF token into the Livewire configuration.
- If the session timeout is too short, increase `SESSION_LIFETIME` in `.env`.
- If using a caching layer (e.g. Nginx full-page cache), exclude Livewire endpoint routes (`/livewire/*`) from the cache.

```env
SESSION_LIFETIME=120   # minutes
```

## Alpine.js Conflicts

**Cause:** A second version of Alpine.js is loaded separately (e.g. from a WordPress plugin or another script), causing conflicts with the Alpine instance bundled by Livewire.

**Fix:**
- Livewire bundles Alpine — do not import Alpine separately in `resources/js/app.js`.
- If a plugin loads Alpine globally, dequeue it on pages that use Livewire:

```php
add_action('wp_enqueue_scripts', function (): void {
    wp_dequeue_script('plugin-alpinejs');
});
```

- Confirm only one Alpine instance is present by checking DevTools: `window.Alpine` should be defined exactly once.

## Missing Root Element in Component View

**Cause:** Livewire requires every component view to have exactly one root HTML element. Multiple root elements, comments at the root level, or missing wrappers cause hydration to break.

**Fix:** Always wrap component view content in a single `<div>`:

```blade
{{-- Wrong — two root elements --}}
<h1>Title</h1>
<p>Content</p>

{{-- Correct --}}
<div>
    <h1>Title</h1>
    <p>Content</p>
</div>
```

## Livewire Requests Return 404

**Cause:** WordPress permalink structure may not pass Livewire's internal endpoint (`/livewire/update`) through to the application.

**Fix:**
- Verify `Pretty Permalinks` is enabled in WP Admin > Settings > Permalinks and saved after Livewire install.
- Confirm Acorn routes are being processed. Run `lando acorn route:list` and verify Livewire's internal routes are registered.

## Component Updates but Page Does Not Reflect Changes

**Cause:** Browser cache or full-page cache serving a stale HTML snapshot.

**Fix:**
- In development: hard refresh (Ctrl+Shift+R).
- In production: exclude pages with Livewire components from full-page cache, or add cache-busting query parameters.

## `wire:model` Not Syncing

**Cause:** `wire:model` on a non-public property, or a typo in the property name.

**Fix:** The bound property must be `public` on the component class. `protected` and `private` properties are not bindable.

```php
// Bad
protected string $query = '';

// Good
public string $query = '';
```

## Escalation Paths

- **Livewire AJAX payloads too large:** See `state-patterns.md` for computed properties and payload optimization.
- **File upload issues:** See `file-uploads.md` for Lando storage paths and temporary file setup.
- **Alpine interop issues:** See `alpine-interop.md` for `$wire.entangle` and conflict resolution.
- **Performance / caching:** Consult the `wp-performance` skill for caching strategies on Livewire-rendered pages.
