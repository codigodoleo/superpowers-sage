<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class {{CLASS_NAME}}
{
    /**
     * Handle an incoming request.
     *
     * Inspect or transform the request before passing it to the controller,
     * or return a response early to short-circuit the pipeline.
     *
     * Replace the condition below with your actual filter logic, e.g.:
     *   - Check a request header:  $request->hasHeader('{{HEADER_NAME}}')
     *   - Verify a query param:    $request->query('{{PARAM_NAME}}') === '{{EXPECTED_VALUE}}'
     *   - Validate a capability:   current_user_can('{{CAPABILITY}}')
     */
    public function handle(Request $request, Closure $next): Response
    {
        if (! $this->passes($request)) {
            return response()->json(['error' => '{{REJECTION_MESSAGE}}'], {{REJECTION_STATUS}});
        }

        return $next($request);
    }

    protected function passes(Request $request): bool
    {
        // TODO: implement your filter condition
        return true;
    }
}
