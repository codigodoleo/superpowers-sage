<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class {{CLASS_NAME}}
{
    public function handle(Request $request, Closure $next): Response
    {
        if (! auth('{{GUARD_NAME}}')->check()) {
            return response()->json(['error' => 'Unauthorized'], 401);
        }

        // Sync WordPress current user so current_user_can() works downstream.
        // wp_set_current_user(auth('{{GUARD_NAME}}')->id());

        return $next($request);
    }
}
