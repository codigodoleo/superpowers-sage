# Ability Patterns

## Query pattern (read-only list)

Use template `assets/ability-query-content.php.tpl`.
Replace `{{ABILITY_NAME}}` with PascalCase, `{{snake_name}}` with `noun/verb`, `{{post_type}}` with CPT slug.

## CRUD pattern (full lifecycle)

Use template `assets/ability-crud.php.tpl`.
Exposes create/read/update/delete in one Ability via `action` parameter.

## Search pattern (full-text)

Use template `assets/ability-search.php.tpl`.
Uses WP_Query `s` parameter for full-text search.

## ACF field groups pattern

```php
public function execute(array $args): array
{
    $groups = acf_get_field_groups(['post_type' => $args['post_type'] ?? null]);
    return array_map(fn ($g) => [
        'key'    => $g['key'],
        'title'  => $g['title'],
        'fields' => array_map(
            fn ($f) => ['name' => $f['name'], 'type' => $f['type']],
            acf_get_fields($g['key']) ?: []
        ),
    ], $groups);
}
```

## Livewire components pattern

```php
public function execute(array $args): array
{
    $dir = get_template_directory() . '/app/Livewire/';
    $files = glob($dir . '*.php') ?: [];
    return array_map(fn ($f) => [
        'class' => 'App\\Livewire\\' . basename($f, '.php'),
        'tag'   => str_replace('_', '-', strtolower(preg_replace('/([A-Z])/', '-$1', lcfirst(basename($f, '.php'))))),
    ], $files);
}
```
