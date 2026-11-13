<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class AccesoController extends Controller
{
    public function ingresar(Request $request): JsonResponse
    {
        $validador = Validator::make($request->all(), [
            'usuario' => ['required', 'string', 'max:60'],
            'clave' => ['required', 'string', 'max:72'],
        ]);

        if ($validador->fails()) {
            return response()->json(['message' => 'Completa el usuario y la contraseña.'], 422);
        }

        $datos = $validador->validated();
        $usuario = trim($datos['usuario']);
        $cuenta = hash_equals(config('demo.usuario'), $usuario)
            ? ['hash'=>config('demo.clave_hash'), 'perfil'=>config('demo.perfil')]
            : config('demo.cuentas')[$usuario] ?? null;
        $hash = $cuenta['hash'] ?? null;
        $claveCorrecta = strlen($datos['clave']) <= 72 && !str_contains($datos['clave'], "\0")
            && Hash::check($datos['clave'], $hash ?: config('demo.clave_hash'));
        if (!$hash || !$claveCorrecta) {
            return response()->json(['message' => 'Usuario o contraseña incorrectos. Intenta de nuevo.'], 422);
        }

        $request->session()->regenerate();
        $request->session()->put('usuario_demo', $cuenta['perfil']);

        return response()->json(['usuario' => $cuenta['perfil']])->header('Cache-Control', 'no-store');
    }

    public function sesion(Request $request): JsonResponse
    {
        return response()->json(['usuario' => $request->session()->get('usuario_demo')]);
    }

    public function salir(Request $request): JsonResponse
    {
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return response()->json(['message' => 'Sesión cerrada.']);
    }
}
