Deep reference for troubleshooting. Loaded on demand from `skills/wp-rest-api/SKILL.md`.

# WordPress REST API Troubleshooting

Common REST errors: 401, CORS, rest_no_route, schema validation failures, 404 on custom namespace.

## Error Reference

| Symptom | Cause | Fix |
|---|---|---|
| 404 on REST endpoint | Missing `rest_api_init` hook or permalink flush needed | Verify hook fires; flush permalinks via Settings > Permalinks or `lando wp rewrite flush` |
| `rest_no_route` error | Typo in namespace or route path | Check `register_rest_route()` namespace and path match the request URL |
| `_doing_it_wrong` notice | Missing `permission_callback` | Add `permission_callback` to every route registration |
| 401 on authenticated endpoint | Nonce not sent or expired | Send `X-WP-Nonce` header; regenerate nonce if expired |
| CPT not appearing in `/wp/v2/` | `show_in_rest` not set | Add `'show_in_rest' => true` to CPT registration |
| Stale cached responses | Transient not invalidated on data change | Add cache invalidation on `save_post_{type}` hook |
| 401 with Application Passwords | HTTP vs HTTPS | Application Passwords require HTTPS; use `https://` in Lando |
| CORS preflight fails | Missing CORS headers | Add `Access-Control-Allow-Origin` via `rest_pre_serve_request` filter |

## Diagnosing 404 on Custom Namespace

```bash
# List all registered namespaces
lando wp rest-api namespace list

# Discover all endpoints at a namespace
curl https://mysite.lndo.site/wp-json/myapp/v1 | jq .

# Check if permalink structure is set (plain permalinks disable REST)
lando wp option get permalink_structure
```

If `permalink_structure` is empty, the REST API routes are not available. Set a permalink structure in Settings > Permalinks.

## Diagnosing 401 Unauthorized

```bash
# Test with Application Password
curl -u 'admin:xxxx xxxx xxxx xxxx xxxx xxxx' \
    https://mysite.lndo.site/wp-json/myapp/v1/events

# Test with nonce (from browser — nonces are user+session specific)
# Check the browser Network tab: X-WP-Nonce header must be present
```

Check for `rest_authentication_errors` filters that may be rejecting requests:

```bash
lando wp eval 'var_export(apply_filters("rest_authentication_errors", null));'
```

## Diagnosing CORS Failures

```php
// Add CORS headers for specific origins
add_filter('rest_pre_serve_request', function ($served, $result, $request, $server) {
    header('Access-Control-Allow-Origin: https://yourapp.com');
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, X-WP-Nonce, Authorization');
    return $served;
}, 10, 4);
```

For development, use `*` as the origin (never in production).

## Diagnosing Schema Validation Failures

REST API rejects requests when argument schemas fail validation. Errors return 400 with `rest_invalid_param`:

```json
{
    "code": "rest_invalid_param",
    "message": "Invalid parameter(s): status",
    "data": {
        "status": 400,
        "params": {
            "status": "status is not one of draft, publish, pending."
        }
    }
}
```

**Fix:** check that the request body matches the `args` schema defined in `register_rest_route()`. Use `enum` and `type` constraints carefully — the REST API performs strict type checking.

## REST API Disabled by Security Plugin

If the REST API is entirely disabled (by a security plugin or custom code):

```bash
# Check for filters disabling REST
lando wp eval 'var_export(has_filter("rest_enabled")); var_export(has_filter("rest_authentication_errors"));'
```

Common culprits: Wordfence, iThemes Security, custom `add_filter('rest_enabled', '__return_false')`. Remove the filter or configure the security plugin to allow REST access for your namespace.

## Discovery via JSON

```bash
# Full endpoint discovery
curl https://mysite.lndo.site/wp-json/ | jq '.namespaces'

# Check a specific namespace
curl https://mysite.lndo.site/wp-json/myapp/v1 | jq '.routes | keys'
```
