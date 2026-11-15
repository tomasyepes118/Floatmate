<?php

namespace App\Http\Middleware;

use App\Services\AccesosOperativos;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RequiereSesionDemo
{
    public function __construct(private AccesosOperativos $accesos) {}

    public function handle(Request $request, Closure $next): Response
    {
        $sesion = $request->session();
        if ($acceso = $sesion->get('acceso_operativo')) {
            $cuenta = $this->accesos->buscar($acceso['usuario']);
            if (!$cuenta || $cuenta['revision'] !== $acceso['revision']) {
                $sesion->invalidate();
                $sesion->regenerateToken();
            } else {
                $sesion->put('usuario_demo', $cuenta['perfil']);
            }
        }
        if (!$sesion->has('usuario_demo')) {
            return response()->json(['message' => 'Ingresa para consultar tu flota.'], 401)->header('Cache-Control', 'no-store');
        }

        $respuesta = $next($request);
        $respuesta->headers->set('Cache-Control', 'no-store, private');
        return $respuesta;
    }
}
