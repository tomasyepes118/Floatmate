<?php

namespace App\Http\Controllers;

use App\Services\RepositorioDemo;
use App\Services\ViajesDelConductor;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\ValidationException;

class MisViajesController extends Controller
{
    public function index(Request $request, RepositorioDemo $repositorio): JsonResponse
    {
        $usuario = $request->session()->get('usuario_demo');
        $flota = $repositorio->leer();
        $rutas = array_column($flota['rutas'], null, 'id');
        $buses = array_column($flota['vehiculos'], null, 'id');

        $viajes = collect($flota['viajes'])->whereStrict('conductor_id', (int) ($usuario['conductor_id'] ?? 0))
            ->sortByDesc('salida')->values()->map(function (array $viaje) use ($rutas, $buses): array {
                $ruta = $rutas[$viaje['ruta_id']];
                $bus = $buses[$viaje['vehiculo_id']];
                return [
                    'id'=>$viaje['id'], 'origen'=>$ruta['origen'], 'destino'=>$ruta['destino'], 'placa'=>$bus['placa'],
                    'salida'=>$viaje['salida'], 'estado'=>$viaje['estado'], 'observaciones'=>$viaje['observaciones'] ?? '',
                    'confirmado_en'=>$viaje['confirmado_por_conductor_en'] ?? null, 'llegada_real'=>$viaje['llegada_real'] ?? null,
                    'kilometraje_minimo'=>$viaje['estado'] === 'EN_CURSO' ? $bus['kilometraje'] : null,
                    'kilometraje_llegada'=>$viaje['kilometraje_llegada'] ?? null,
                ];
            });

        return response()->json(compact('usuario', 'viajes'));
    }

    public function confirmar(Request $request, RepositorioDemo $repositorio, int $id): JsonResponse
    {
        $conductorId = (int) $request->session()->get('usuario_demo.conductor_id');
        $confirmado = $repositorio->modificar(function (array &$flota) use ($id, $conductorId): string {
            $indice = array_search($id, array_column($flota['viajes'], 'id'), true);
            ViajesDelConductor::autorizar($indice === false ? null : $flota['viajes'][$indice], $conductorId);
            $viaje = &$flota['viajes'][$indice];
            if (isset($viaje['confirmado_por_conductor_en'])) return $viaje['confirmado_por_conductor_en'];
            if ($viaje['estado'] !== 'PROGRAMADO') {
                throw ValidationException::withMessages(['estado'=>'Solo puedes confirmar una asignación programada.']);
            }
            return $viaje['confirmado_por_conductor_en'] = Carbon::now('America/Bogota')->toIso8601String();
        });
        return response()->json(['message'=>'Asignación confirmada.', 'confirmado_en'=>$confirmado]);
    }
}
