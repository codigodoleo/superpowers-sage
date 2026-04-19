# JSON Schema Reference

The `$schema` property follows JSON Schema Draft-07.

## Common patterns

```php
public array $schema = [
    'type' => 'object',
    'required' => ['id'],
    'properties' => [
        'id'     => ['type' => 'integer', 'description' => 'Post ID.'],
        'status' => ['type' => 'string', 'enum' => ['publish', 'draft']],
        'limit'  => ['type' => 'integer', 'minimum' => 1, 'maximum' => 100],
        'query'  => ['type' => 'string'],
    ],
];
```

## Validation

The MCP Adapter validates input against the schema before calling `execute()`.
Invalid input returns an error without reaching your code.

## Return value

`execute()` must return an array. It is JSON-serialized by the adapter.
Return flat arrays for simple results, nested arrays for collections.
