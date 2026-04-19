Deep reference for Core Web Vitals optimization in Sage/Vite-based themes. Loaded on demand from `skills/wp-performance/SKILL.md`.

# Core Web Vitals for Sage / Vite

Core Web Vitals — LCP, CLS, INP — are the key browser performance metrics affecting SEO ranking and user experience in Sage/Vite themes.

## Metrics and Targets

| Metric | Target | Measurement |
|---|---|---|
| **LCP** (Largest Contentful Paint) | < 2.5s | Time until the largest visible element is rendered |
| **INP** (Interaction to Next Paint) | < 200ms | Latency from user input to next visual update |
| **CLS** (Cumulative Layout Shift) | < 0.1 | Total unexpected layout shift during page load |

Measure with: Lighthouse, PageSpeed Insights, or the `web-vitals` npm library.

## LCP Optimizations

### Hero images

The hero image is almost always the LCP element. Optimize it:

```html
{{-- Preload the hero image in <head> to start fetching early --}}
<link rel="preload" as="image" href="{{ $heroImageUrl }}" fetchpriority="high">
```

```blade
{{-- Blade: explicit dimensions prevent CLS, eager loading for LCP element --}}
<img
    src="{{ $heroImageUrl }}"
    width="1920"
    height="1080"
    loading="eager"
    fetchpriority="high"
    alt="{{ $heroAlt }}"
>
```

### Render-blocking CSS

Sage's Vite build produces a single CSS bundle loaded in `<head>`.
For very large bundles, extract critical above-the-fold CSS:

1. Use a Vite plugin (e.g. `vite-plugin-critical`) to inline critical CSS.
2. Load the full stylesheet asynchronously:
   ```html
   <link rel="stylesheet" href="..." media="print" onload="this.media='all'">
   ```

### TTFB

High TTFB (> 600ms) delays LCP. Fixes:
- Enable Redis object cache (see `references/caching.md`)
- Audit autoloaded options (see `skills/wp-performance/scripts/autoload-audit.sh`)
- Add full-page caching for high-traffic static pages

## INP Optimizations

INP (replaces FID in CWV 2024) measures responsiveness to user input.

### Long tasks on the main thread

Use Lighthouse "Total Blocking Time" to identify long tasks. Fixes:
- Split large synchronous JS into smaller chunks
- Defer non-critical scripts: `<script defer>` or `type="module"`
- Use `requestIdleCallback` for non-urgent work

### Livewire hydration latency

Each `wire:model.live` event triggers a server round-trip. Mitigate:
- Debounce: `wire:model.live.debounce.300ms`
- Prefer `wire:model` (submit-only) over `wire:model.live` where real-time is not needed

### Vite bundle size

```bash
# Analyse bundle sizes
lando theme-build -- --analyze
```

- Dynamic imports for conditionally loaded modules: `const m = await import('./heavy-module.js')`
- Split large vendor libraries into separate chunks via `manualChunks` in `vite.config.js`
- Target: no single chunk > 200KB gzipped

## CLS Optimizations

Cumulative Layout Shift occurs when content shifts after initial render.

### Images without explicit dimensions

Always declare `width` and `height` on images. WordPress generates these for
media library images via `wp_get_attachment_image()`:

```php
echo wp_get_attachment_image($attachmentId, 'full');
// → <img src="..." width="1920" height="1080" ...>
```

In Blade, use the `$image` ACF field with explicit dimensions:

```blade
@if ($image)
    <img
        src="{{ $image['url'] }}"
        width="{{ $image['width'] }}"
        height="{{ $image['height'] }}"
        alt="{{ $image['alt'] }}"
        loading="lazy"
    >
@endif
```

### Web fonts causing FOUT / layout shift

```css
@font-face {
    font-family: 'MyFont';
    font-display: swap;   /* swap: FOUT; optional: no shift */
}
```

Preload critical fonts:

```html
<link rel="preload" as="font" type="font/woff2" href="/fonts/myfont.woff2" crossorigin>
```

### Dynamically injected content

If JS injects content above the fold after load (banners, cookie notices),
reserve space with `min-height` or use `position: fixed` to avoid shifting layout.

## Lazy Loading Below-the-Fold Images

```blade
<img
    src="{{ $image['url'] }}"
    width="{{ $image['width'] }}"
    height="{{ $image['height'] }}"
    alt="{{ $image['alt'] }}"
    loading="lazy"
>
```

Use `loading="eager"` for the LCP element only. All other images should use
`loading="lazy"`.

## Critical CSS with Vite

Sage uses Vite for bundling. To extract critical CSS:

```js
// vite.config.js — add vite-plugin-critical
import critical from 'vite-plugin-critical';

export default {
    plugins: [
        // ... other plugins
        critical({
            criticalUrl: 'https://yoursite.lndo.site',
            criticalPages: [{ uri: '/', template: 'index' }],
            criticalConfig: {},
        }),
    ],
};
```

## Measurement Workflow

1. Run Lighthouse in Chrome DevTools on the production URL (or Lando with caching enabled)
2. Note LCP, INP, CLS scores and the specific element/interaction flagged
3. Implement the highest-impact fix first
4. Re-run Lighthouse to confirm improvement
5. Check PageSpeed Insights for field data (real-user measurements)

## Third-Party Scripts

If CWV cannot be met due to third-party scripts (analytics, chat widgets,
ad networks), document the constraint and escalate to the project lead.
Options: load third-party scripts with `loading="lazy"` or after `load` event;
use a consent-based loader (load only after user accepts cookies).
