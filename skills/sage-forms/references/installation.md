# sage-forms — Installation

Detailed installation of HTML Forms + sage-html-forms on a Sage/Acorn/Bedrock/Lando project.

## 1. Install the WordPress plugin (via Bedrock Composer)

```bash
lando composer require wpackagist-plugin/html-forms
```

This adds the plugin to `composer.json` at the Bedrock root and places it under `web/app/plugins/html-forms/`. Activate it via the admin UI or WP-CLI:

```bash
lando wp plugin activate html-forms
```

Verify activation:

```bash
lando wp plugin list --status=active | grep html-forms
```

Expected: one row with `html-forms` and status `active`.

## 2. Install the Sage bridge

```bash
lando theme-composer require log1x/sage-html-forms
```

`composer.json` in the theme now contains:

```json
"log1x/sage-html-forms": "^1.1"
```

## 3. Verify Acorn auto-discovery

The bridge package ships a Service Provider that Acorn discovers automatically — there is no manual `config/app.php` edit. Confirm the provider is active:

```bash
lando acorn about
```

Look for `Log1x\SageHtmlForms\Providers\SageHtmlFormsServiceProvider` in the "Providers" section. If present, the filter `hf_form_html` is registered and `hf_get_form($id)->get_html()` calls will route to `resources/views/forms/{form-slug}.blade.php`.

## 4. Confirm the filter is registered

```bash
lando wp eval "var_dump(has_filter('hf_form_html'));"
```

Expected: `int(10)` (priority 10). If `false`, the bridge did not boot — run `lando flush` and re-check. If still `false`, the theme's `config/app.php` may be suppressing package discovery (rare; investigate `Theme` key).

## 5. Create the first `html-form` CPT post

Use WP-CLI or the admin UI. With WP-CLI:

```bash
lando wp post create \
  --post_type=html-form \
  --post_title="Contact" \
  --post_name=contact \
  --post_status=publish
```

The post's slug (`contact`) becomes the Blade view filename: `resources/views/forms/contact.blade.php`.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `hf_get_form()` is undefined | HTML Forms plugin not active | `lando wp plugin activate html-forms` |
| Form renders as plain HTML, not the Blade view | `hf_form_html` filter not registered | Run `lando flush`; verify provider via `lando acorn about` |
| `class not found: SageHtmlFormsServiceProvider` | Vendor autoload stale | `lando theme-composer dump-autoload` |
| Blade view updates not reflected | Blade cache | `lando flush` (clears Acorn + Blade + OPcache) |

## References

- [htmlformsplugin.com](https://htmlformsplugin.com/) — plugin documentation and submission pipeline
- [log1x/sage-html-forms on GitHub](https://github.com/Log1x/sage-html-forms) — bridge source
