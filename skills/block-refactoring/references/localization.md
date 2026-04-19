Deep reference for block localization. Loaded on demand from `skills/block-refactoring/SKILL.md`.

# Block Localization

Full cycle for making block strings translatable in a Sage/Acorn theme.

## Text Domain Registration

In `ThemeServiceProvider::boot()` — use `load_textdomain()` directly, NOT `load_theme_textdomain()`:

```php
public function boot(): void
{
    parent::boot();

    // load_theme_textdomain() returns true but silently fails in Acorn WP 6.9 boot context.
    // Use load_textdomain() with explicit path instead.
    load_textdomain(
        'sage',
        get_template_directory() . '/resources/lang/' . get_locale() . '.mo'
    );
}
```

## PHP Localization Functions

| Context | Function | Example |
|---|---|---|
| Plain string | `__('text', 'sage')` | `$label = __('Read more', 'sage')` |
| Escaped for HTML output | `esc_html__('text', 'sage')` | `echo esc_html__('Title', 'sage')` |
| With substitutions | `sprintf(__('Hello %s', 'sage'), $name)` | inline |
| In Blade (echo) | `{{ esc_html__('text', 'sage') }}` | `<span>{{ esc_html__('View', 'sage') }}</span>` |

Always use `esc_html__()` for string literals directly echoed into HTML attributes or text nodes. Use `__()` only when the string will be further processed (e.g., passed to a function that escapes it).

## Blade Shorthand

In Blade views, localize strings via the echo shorthand:

```blade
{{-- ✅ Correct --}}
<span>{{ esc_html__('Learn more', 'sage') }}</span>
<button aria-label="{{ esc_attr__('Close menu', 'sage') }}">...</button>

{{-- ❌ Wrong — bare string --}}
<span>Learn more</span>
```

## Generating the POT File

Run once to create or update the translation catalog:

```bash
lando wp i18n make-pot . resources/lang/sage.pot --domain=sage --exclude=vendor,node_modules
```

This scans all PHP and Blade files for `__()`, `esc_html__()`, and similar calls and produces a `.pot` template file translators can use with Poedit or Loco Translate.

## wp_localize_script (for JS)

To pass PHP strings to JavaScript:

```php
// In ThemeServiceProvider::boot()
add_action('wp_enqueue_scripts', function () {
    wp_localize_script('theme', 'themeStrings', [
        'readMore'  => esc_html__('Read more', 'sage'),
        'closeMenu' => esc_html__('Close menu', 'sage'),
    ]);
}, 20);
```

In JS: `window.themeStrings.readMore`.

Alternatively, use `wp_set_script_translations()` with a JSON file if the project uses the WP Scripts package (Gutenberg toolchain).

## Common Mistakes

| Mistake | Fix |
|---|---|
| `load_theme_textdomain()` silently fails in Acorn boot context | Use `load_textdomain($domain, $path, $locale)` directly |
| POT file not regenerated after adding strings | Run `wp i18n make-pot` before submitting to translation |
| Using `__()` directly in HTML output | Use `esc_html__()` to prevent XSS |
| Text domain mismatch | Check domain in `load_textdomain()` matches `__()` calls — typos produce silent failures |
