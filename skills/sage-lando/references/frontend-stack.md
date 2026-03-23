# Frontend Stack

Sage uses Vite as its build tool, Tailwind CSS v4 for utility-first styling, and the Laravel Vite plugin for seamless asset integration with Acorn. This reference covers the complete frontend configuration for a Lando-based WordPress development environment.

---

## `vite.config.js` -- Complete Configuration

This is the recommended Vite configuration for Sage running inside Lando.

```js
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';

export default defineConfig({
  plugins: [
    laravel({
      input: [
        'resources/css/app.css',
        'resources/js/app.js',
        'resources/css/editor.css',
      ],
      refresh: true,
    }),
  ],
  server: {
    host: '0.0.0.0',
    port: 5173,
    strictPort: true,
    origin: 'https://{project}.lndo.site:5173',
    hmr: {
      host: '{project}.lndo.site',
      protocol: 'wss',
    },
    https: false, // Lando proxy handles HTTPS
  },
});
```

### Option-by-option breakdown

- **`input`** -- The entry points Vite will compile. Three are standard:
  - `resources/css/app.css` -- main frontend stylesheet (Tailwind + custom styles)
  - `resources/js/app.js` -- main frontend JavaScript bundle
  - `resources/css/editor.css` -- Gutenberg block editor styles so blocks render correctly in the admin
- **`server.host: '0.0.0.0'`** -- Binds Vite to all network interfaces. Required because Vite runs inside the Lando container and must be reachable from the host machine and the Lando proxy.
- **`server.port: 5173`** / **`strictPort: true`** -- Uses Vite's default port and fails if it is already taken rather than silently picking another port.
- **`server.origin`** -- Tells Vite the external URL that the browser uses to load HMR assets. Without this, asset URLs would point to `localhost` inside the container, which the browser cannot reach.
- **`server.hmr.host`** / **`server.hmr.protocol`** -- Configures the WebSocket connection for hot module replacement to go through Lando's HTTPS proxy using `wss://`.
- **`server.https: false`** -- Vite itself does not terminate TLS. Lando's proxy handles HTTPS and forwards plain HTTP to Vite.
- **`refresh: true`** -- Watches Blade template files for changes and triggers a full page reload when they are modified (CSS/JS changes use HMR instead).

---

## Tailwind CSS v4 -- CSS-First Configuration

Tailwind CSS v4 introduces a paradigm shift: there is no `tailwind.config.js` file. All configuration lives in CSS using native `@theme`, `@source`, and `@import` directives. Do not create a `tailwind.config.js` -- it is not needed and not recommended.

### `resources/css/app.css`

```css
@import "tailwindcss";

@source "../views/**/*.blade.php";
@source "../js/**/*.js";

@theme {
  --color-primary: #1a365d;
  --color-secondary: #2d3748;
  --font-family-sans: 'Inter', sans-serif;
  --font-family-heading: 'Playfair Display', serif;
  /* Custom spacing, breakpoints, etc. */
}
```

- **`@import "tailwindcss"`** -- Replaces the old `@tailwind base; @tailwind components; @tailwind utilities;` directives from v3. This single import loads everything.
- **`@source`** -- Tells Tailwind where to scan for class usage. This replaces the `content` array from `tailwind.config.js` in v3. Point it at your Blade templates and JS files so unused classes are purged in production.
- **`@theme`** -- Replaces the `theme.extend` object from `tailwind.config.js`. Define custom colors, fonts, spacing, breakpoints, and any other design tokens as CSS custom properties. These become available as Tailwind utilities (e.g., `--color-primary` enables `text-primary`, `bg-primary`, etc.).

### `resources/css/editor.css`

```css
@import "tailwindcss";

@source "../views/blocks/**/*.blade.php";

@theme {
  /* Same theme tokens as app.css -- keep in sync or use @import */
}
```

The editor stylesheet should share the same design tokens as `app.css` so that blocks look identical in the Gutenberg editor and on the frontend. The `@source` directive is scoped to block templates only since the editor does not render layout or page-level templates.

To keep tokens in sync, extract shared values into a partial file (e.g., `resources/css/_theme.css`) and `@import` it from both `app.css` and `editor.css`.

---

## CSS/JS Structure

```
resources/
├── css/
│   ├── app.css          # Main frontend stylesheet (Tailwind + custom)
│   ├── editor.css       # Gutenberg editor styles
│   └── blocks/          # Optional: per-block CSS (loaded via Block::assets())
│       └── hero.css
├── js/
│   ├── app.js           # Main frontend JS entry
│   ├── editor.js        # Optional: editor-only JS
│   └── blocks/          # Optional: per-block JS
│       └── hero.js
└── fonts/
    └── inter/           # Self-hosted fonts
```

### When to use per-block assets vs. the main bundle

Put styles and scripts in the **main bundle** (`app.css` / `app.js`) when:

- The code is used on most pages (global nav, footer, typography)
- The code is small enough that splitting it out adds more overhead than it saves
- The styles are Tailwind utilities (they are already tree-shaken)

Use **per-block assets** (`blocks/hero.css`, `blocks/hero.js`) when:

- A block pulls in a heavy third-party library (e.g., Swiper, GSAP, Mapbox)
- The block appears on only a few pages
- You want the block to be fully self-contained and portable

Per-block assets are loaded via `Block::assets()` and only enqueued when the block is present on the page.

---

## HMR with Lando

How hot module replacement works in the Lando environment, step by step:

1. Vite runs inside the Lando `appserver` container, bound to `0.0.0.0:5173`.
2. Lando proxies `{project}.lndo.site` (ports 80/443) to the appserver for normal page requests.
3. Port 5173 is exposed directly so the browser can reach the Vite dev server.
4. The `@vite` Blade directive detects the running dev server and injects `<script>` tags pointing to `https://{project}.lndo.site:5173`.
5. Vite's HMR WebSocket connects via `wss://{project}.lndo.site:5173`.
6. The `origin` setting in `vite.config.js` ensures all asset URLs resolve to the correct external hostname.

### Exposing port 5173

Port 5173 must be accessible from the host. Add this to `.lando.yml` if it is not already configured:

```yaml
services:
  appserver:
    overrides:
      ports:
        - '5173:5173'
```

### Running the dev server

```bash
lando vite
```

This starts Vite inside the container. Changes to CSS, JS, and Blade files trigger instant browser updates -- CSS changes are injected without a full reload, Blade changes cause a full reload.

---

## Using Assets in PHP and Blade

### In Blade templates

Add the `@vite` directive to your layout file. This outputs the correct `<link>` and `<script>` tags for both development (dev server URLs) and production (compiled manifest URLs).

```blade
{{-- resources/views/layouts/app.blade.php --}}
@vite(['resources/css/app.css', 'resources/js/app.js'])
```

### In PHP (setup.php, block assets, etc.)

The `Vite` facade provides helper methods for working with assets outside of Blade:

```php
use Illuminate\Support\Facades\Vite;

// Get the full URL to a compiled asset (for wp_enqueue_style/script)
Vite::asset('resources/css/app.css');

// Get the file contents as a string (for inline styles)
Vite::content('resources/css/editor.css');

// Check if the Vite dev server is currently running
Vite::isRunningHot();
```

### Enqueuing editor styles

Register the editor stylesheet so Gutenberg blocks are styled correctly in the admin:

```php
// In app/setup.php or a service provider
add_action('enqueue_block_editor_assets', function () {
    wp_enqueue_style('editor-styles', Vite::asset('resources/css/editor.css'));
});
```

---

## Code Splitting

### Lazy-loading heavy modules

For blocks or components that depend on large libraries, use dynamic `import()` to load them only when needed:

```js
// resources/js/app.js
if (document.querySelector('.swiper-container')) {
  import('./blocks/slider.js').then(module => module.init());
}
```

This keeps the main bundle small. The slider code is fetched as a separate chunk only on pages that contain `.swiper-container`.

### Per-block entry points

For blocks that need their own dedicated entry point, add the file to the `input` array in `vite.config.js`:

```js
input: [
  'resources/css/app.css',
  'resources/js/app.js',
  'resources/css/editor.css',
  'resources/js/blocks/hero.js',  // additional entry point
],
```

Then load it from the block's `assets()` method:

```php
public function assets(array $block): void
{
    wp_enqueue_script(
        'block-hero',
        Vite::asset('resources/js/blocks/hero.js'),
        [],
        null,
        true
    );
}
```

This approach gives you full control over when and where each script loads.

---

## Production Build

Run the production build inside Lando:

```bash
lando vite-build
```

This generates:

- Compiled, minified CSS and JS files in `public/build/`
- A `manifest.json` that maps source file paths to their hashed output filenames

The Vite facade automatically reads the manifest in production (when the dev server is not running) and outputs the correct `<link>` and `<script>` tags with cache-busted URLs.

No manual cache-busting is needed -- hashed filenames ensure browsers always load the latest assets after a deploy.
