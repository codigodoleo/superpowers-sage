Deep reference for filter-gotchas. Loaded on demand from `skills/wp-hooks-lifecycle/SKILL.md`.

# WordPress Filter Gotchas

Filters that commonly cause unexpected behavior in Sage/Tailwind v4 themes — `the_content`, `oembed_result`, and Gutenberg block output filters.

## `wptexturize` Corrupts Tailwind Arbitrary Variants

WordPress applies "smart quote" transformations to block content via `wptexturize` on `the_content`. The filter is aggressive and rewrites sequences like `0"` into `0″` (U+2033 PRIME), treating them as inch/arc-second notation — **inside HTML attributes it has no business touching**.

**Observed failure:** a Blade view with the Tailwind v4 arbitrary variant `<div class="[&>p:last-child]:mb-0">` rendered as `<div class="[&>p:last-child]:mb-0″>`. The unterminated attribute consumed the rest of the page markup as a giant `class` value, collapsing all siblings into a single malformed element.

**Symptoms:**
- Block rendering DOM collapses — Playwright shows block siblings absorbed as children
- DevTools shows class attribute containing page HTML up to the next quote
- Only affects content fields processed through `the_content`

**Fix: disable `wptexturize` globally in `ThemeServiceProvider::boot()`:**

```php
public function boot(): void
{
    parent::boot();

    // wptexturize rewrites [&>p:last-child]:mb-0" into mb-0″ (U+2033),
    // corrupting Tailwind v4 arbitrary variants inside class attributes.
    add_filter('run_wptexturize', '__return_false');
}
```

**Detect preemptively:** search the theme for arbitrary variants ending in a digit inside an attribute:

```bash
grep -rE '\[[^]]*[0-9]"' resources/views/
```

Any match is a candidate for `wptexturize` corruption.

## `wpautop` Inserts `<p>` Around Block Content

`wpautop` wraps non-paragraph content in `<p>` tags. For ACF blocks rendered via `the_content`, this produces invalid nesting like `<p><div>...</div></p>` (browsers auto-close the `<p>` before the `<div>`, orphaning the closing `</p>`).

**Fix:** strip `wpautop` from ACF block output:

```php
add_filter('the_content', function ($content) {
    if (has_block('acf/')) {
        remove_filter('the_content', 'wpautop');
    }
    return $content;
}, 9);
```

## `wp_kses_post` Strips Unexpected Tags

WYSIWYG content saved via ACF text areas runs through `wp_kses_post` on save, which strips tags not in `$allowedposttags`. Custom elements like `<block-hero>` will be stripped if an editor pastes them into a text field.

**Fix:** this is usually desirable for editor-entered content. If you need to allow custom elements, extend `$allowedposttags` via `wp_kses_allowed_html` filter, scoped to the specific context.

## `the_content` Filter Order — Priority Reference

Default priority order on `the_content`:

| Priority | Filter | Effect |
|---|---|---|
| 6 | `run_shortcode` | Parses shortcodes |
| 8 | `autoembed` | Replaces URLs with oEmbed |
| 9 | `do_blocks` | Renders Gutenberg blocks |
| 10 | `wpautop` | Wraps in `<p>` |
| 10 | `shortcode_unautop` | Removes `<p>` wrapping shortcodes |
| 10 | `prepend_attachment` | Adds attachment markup |
| 11 | `capital_P_dangit` | Capitalizes "WordPress" |
| 20 | `convert_smilies` | Replaces text smilies with images |

**Guideline:** Add your filter at priority >= 11 to see post-block output; priority < 9 to see raw block markup.

## Common Filter Anti-Patterns

- **Returning nothing from a filter:** Filters MUST return a value. Forgetting the return statement silently nullifies the data.
- **Hooks inside hooks:** Adding `add_action('init', ...)` inside another `add_action('init', ...)` callback means the inner hook never fires (init already happened).
- **Infinite loop:** Filter modifies data that triggers the same filter (e.g., calling `wp_update_post` inside `save_post`). Use `remove_action` before the triggering call, then re-add.
