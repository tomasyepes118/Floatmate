<?php

namespace App\Http\Controllers;

use App\Services\MunicipiosAntioquia;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Validation\Rule;

class GeografiaController extends Controller
{
    public function municipios(MunicipiosAntioquia $catalogo): JsonResponse
    {
        return response()->json(['municipios'=>$catalogo->todos()]);
    }

    public function estimar(Request $request, MunicipiosAntioquia $catalogo): JsonResponse
    {
        $municipios = array_column($catalogo->todos(), null, 'codigo');
        $codigo = ['required','string',Rule::in(array_keys($municipios))];
        $datos = $request->validate([
            'origen'=>$codigo,
            'destino'=>[...$codigo, 'different:origen'],
        ], [
            'required'=>'Selecciona ambos municipios.',
            'string'=>'Selecciona un municipio válido.',
            'in'=>'Selecciona un municipio de Antioquia.',
            'destino.different'=>'Selecciona un destino distinto del origen.',
        ]);

        $motor = rtrim(config('rutas.motor_url'), '/');
        $clave = 'osrm:'.hash('sha256', $motor).":{$datos['origen']}:{$datos['destino']}";
        if ($estimacion = Cache::get($clave)) {
            return response()->json($estimacion);
        }
        if (!Cache::add('osrm:intervalo', true, 2)) {
            return response()->json(['message'=>'Espera unos segundos y vuelve a calcular.'], 503);
        }

        $origen = $municipios[$datos['origen']];
        $destino = $municipios[$datos['destino']];
        $puntos = "{$origen['longitud']},{$origen['latitud']};{$destino['longitud']},{$destino['latitud']}";
        try {
            $respuesta = Http::acceptJson()
                ->withUserAgent('FloatMate (https://github.com/tomasyepes118/Floatmate)')
                ->connectTimeout(3)->timeout(8)
                ->get("$motor/route/v1/driving/$puntos", [
                    'overview'=>'false', 'alternatives'=>'false', 'generate_hints'=>'false',
                ]);
        } catch (ConnectionException) {
            return response()->json(['message'=>'El servicio de mapas no respondió. Puedes ingresar la distancia y duración manualmente.'], 503);
        }

        if (in_array($respuesta->json('code'), ['NoRoute','NoSegment'], true)) {
            return response()->json(['message'=>'El mapa no encontró un trayecto por carretera entre estos puntos. Si conoces el recorrido, puedes ingresar los valores manualmente.'], 422);
        }
        $metros = $respuesta->json('routes.0.distance');
        $segundos = $respuesta->json('routes.0.duration');
        if (!$respuesta->successful() || !is_numeric($metros) || !is_numeric($segundos) || $metros <= 0 || $segundos <= 0) {
            return response()->json(['message'=>'El servicio de mapas no pudo calcular el recorrido. Puedes ingresar los valores manualmente.'], 503);
        }

        $estimacion = [
            'distancia'=>max(0.01, round($metros / 1000, 2)),
            'duracion'=>(int) ceil($segundos / 60),
        ];
        Cache::put($clave, $estimacion, now()->addDay());
        return response()->json($estimacion);
    }
}
