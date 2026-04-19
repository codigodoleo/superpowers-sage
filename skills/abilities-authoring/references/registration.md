# Registration Reference

## AbilitiesServiceProvider setup

If the provider does not exist:

```bash
lando wp acorn make:provider AbilitiesServiceProvider
```

Add to `config/app.php` providers array:
```php
App\Providers\AbilitiesServiceProvider::class,
```

## Registering multiple abilities

```php
public function boot(): void
{
    $registry = $this->app->make(\Roots\AcornAi\Abilities\AbilityRegistry::class);
    $registry->register([
        new \App\Abilities\ListProjectsAbility(),
        new \App\Abilities\SearchProjectsAbility(),
        new \App\Abilities\ManageProjectAbility(),
    ]);
}
```

## Naming convention

Ability names use `noun/verb` format: `projects/list`, `posts/search`, `acf/field-groups`.
The MCP Adapter exposes them as `execute-ability` targets.
