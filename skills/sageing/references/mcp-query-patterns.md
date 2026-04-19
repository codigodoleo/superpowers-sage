# MCP Query Patterns

When the AI stack is ready (`detect-ai-readiness` reports `ready: true`), query the live
WordPress environment before generating any code that involves post types, custom fields,
routes, or Livewire components.

## The query-first rule

Before writing code that **references** any of the following, run the corresponding query:

| Thing to reference | Query to run | Tool |
|---|---|---|
| Custom post types | `execute-ability posts/list-types` | MCP |
| ACF field groups | `execute-ability acf/field-groups` | MCP |
| Acorn routes | `execute-ability routes/list` | MCP |
| Livewire components | `execute-ability livewire/components` | MCP |
| Menu locations | `execute-ability menus/locations` | MCP |

## Step-by-step pattern

1. Call `discover-abilities` to see what is available in this project.
2. Call `execute-ability <name>` with the relevant ability.
3. Use the real data (slugs, field names, class names) — not invented names.
4. If the ability does not exist, suggest the user create it with `/abilities-authoring`.
5. If `ready: false`, ask the user for the information instead of guessing.

## Example: building a Livewire component that references a CPT

**Bad (generates code with invented slug):**
```
I'll create a Livewire component that queries `project` posts...
```

**Good (queries first):**
```
1. discover-abilities
   → sees "posts/list-types", "livewire/components"
2. execute-ability posts/list-types
   → returns [{"slug":"projeto","label":"Projetos"}]
3. execute-ability livewire/components
   → returns existing components to avoid duplication
4. Now generates code using slug "projeto" (real value, not invented)
```

## Fallback when stack is not installed

If `detect-ai-readiness.mjs --path .` returns `ready: false`:
- Ask the user: "What custom post types does this project use?"
- Suggest running `/ai-setup` to install the stack.
- Do not guess or invent slugs, field names, or component names.
