<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RequiereSesionDemo
{
    public function handle(Request $request, Closure $next): Response
    {
        if (!$request->session()->has('usuario_demo')) {
            return response()->json(['message' => 'Ingresa para consultar tu flota.'], 401)->header('Cache-Control', 'no-store');
        }

        return $next($request)->header('Cache-Control', 'no-store, private');
    }
}
