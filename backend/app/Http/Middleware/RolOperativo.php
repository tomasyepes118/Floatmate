<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RolOperativo
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        if (!in_array($request->session()->get('usuario_demo.rol'), $roles, true)) {
            return response()->json(['message'=>'Tu perfil no tiene permiso para realizar esta acción.'], 403);
        }
        return $next($request);
    }
}
