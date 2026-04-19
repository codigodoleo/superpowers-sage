Deep reference for Sage/Lando troubleshooting. Loaded on demand from `skills/sage-lando/SKILL.md`.

# Troubleshooting

Common issues in Sage/Acorn/Lando development — Blade cache staleness, ACF sync errors, Vite HMR failures, autoloading problems, and container resolution failures.

## 1. Blade templates don't update after editing

**Cause:** Compiled Blade cache is stale.

**Fix:**
```bash
lando acorn view:clear
```

If that doesn't work, clear all caches:
```bash
lando acorn optimize:clear
```

## 2. `Class "App\Services\MyService" not found`

**Cause:** Composer autoload map is outdated after creating new files.

**Fix:**
```bash
lando theme-composer dump-autoload
```

Verify the class namespace matches the file path: `App\Services\MyService` must be at `app/Services/MyService.php`.

## 3. ACF fields don't appear in the Gutenberg editor

**Cause:** Field group isn't synced, or `setLocation()` is missing/wrong.

**Fix:**
```bash
lando acorn acf:sync
```

Check that:
- The Block/Field class is in the correct directory (`app/Blocks/` or `app/Fields/`)
- `setLocation()` targets the right post type or template
- ACF Pro is activated
- The class has no syntax errors (check `lando logs -s appserver`)

## 4. Vite HMR doesn't connect (changes don't hot-reload)

**Cause:** Vite dev server can't communicate through Lando's Docker network.

**Fix:** Verify `vite.config.js` has:
```js
server: {
  host: '0.0.0.0',
  port: 5173,
  strictPort: true,
  origin: 'https://{project}.lndo.site:5173',
  hmr: {
    host: '{project}.lndo.site',
    protocol: 'wss',
  },
}
```

And port 5173 is exposed in `.lando.yml`:
```yaml
services:
  appserver:
    overrides:
      ports:
        - '5173:5173'
```

Then restart: `lando restart && lando vite`

## 5. `wp acorn` returns "command not found" or "could not find WordPress"

**Cause:** WP core is in `wp/` subdirectory, not the webroot.

**Fix:** Always use `--path`:
```bash
lando wp --path=/app/wp acorn <command>
```

Or use the Lando tooling shortcut:
```bash
lando acorn <command>
```

If Acorn itself isn't recognized, ensure it's installed in the theme:
```bash
lando theme-composer require roots/acorn
```

## 6. Composer dependency conflicts between root and theme

**Cause:** Running `composer require` at project root instead of in the theme, or vice versa.

**Fix:** The project has two independent `composer.json` files:
- **Root** (`/composer.json`) — WordPress core, plugins. Use `lando composer`.
- **Theme** (`/content/themes/{theme}/composer.json`) — Acorn, ACF Composer, etc. Use `lando theme-composer`.

Never install theme dependencies at root or root dependencies in the theme. If you accidentally did, remove the package from the wrong location and install in the correct one.

## 7. Tailwind styles don't apply in the Gutenberg editor

**Cause:** Editor styles aren't enqueued, or `@source` doesn't scan block templates.

**Fix:**

1. Ensure `resources/css/editor.css` has the correct `@source`:
```css
@import "tailwindcss";
@source "../views/blocks/**/*.blade.php";
```

2. Ensure `editor.css` is in the Vite `input` array in `vite.config.js`

3. Enqueue editor styles:
```php
// app/setup.php or app/actions.php
add_action('enqueue_block_editor_assets', function () {
    wp_enqueue_style('editor-styles', \Illuminate\Support\Facades\Vite::asset('resources/css/editor.css'));
});
```
