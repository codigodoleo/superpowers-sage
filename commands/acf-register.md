# /acf-register

Scaffolds a new ACF field group as a PHP class via Acorn's ACF scaffolding command.

## Usage

```
/acf-register
```

You will be prompted for the field group name.

## What it does

1. Asks: "Field group name? (e.g. HeroFields, PageSettings)"
2. Runs: `lando acorn acf:field <FieldGroupName>`
3. Reports the file created (typically `app/Fields/<FieldGroupName>.php`).
4. Offers to open the file for editing.

## Requirements

- Acorn installed (`lando acorn` available).
- ACF Pro active in the project.
- Run from the theme root (`web/app/themes/<theme-name>/`).

## Notes

- This uses Acorn scaffolding, NOT the ACF GUI. Field groups are code-managed.
- After scaffolding, register the group inside the class's `register()` method.
- See the `acorn-eloquent` skill for field group best practices.
