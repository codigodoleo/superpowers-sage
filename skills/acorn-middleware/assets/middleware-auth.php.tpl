<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

class {{CLASS_NAME}}
{
    public function handle(Request $request, Closure $next)
    {
        if (! auth('{{GUARD_NAME}}')->check()) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        return $next($request);
    }
}
