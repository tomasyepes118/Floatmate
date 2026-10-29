<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Services\RepositorioDemo;
use Illuminate\Support\Carbon;

class ResumenController extends Controller
{
    public function __invoke(Request $request, RepositorioDemo $repositorio): JsonResponse
    {
        $datos = $repositorio->leer();
        $vehiculos = collect($datos['vehiculos']);
        $programados = collect($datos['viajes'])->where('estado', 'PROGRAMADO');
        $proximos = $programados->sortBy('salida')->take(4)->map(function (array $viaje) use ($datos): array {
            $ruta = collect($datos['rutas'])->firstWhere('id', $viaje['ruta_id']);
            $vehiculo = collect($datos['vehiculos'])->firstWhere('id', $viaje['vehiculo_id']);
            $conductor = collect($datos['conductores'])->firstWhere('id', $viaje['conductor_id']);
            $fecha = Carbon::createFromFormat('!Y-m-d\TH:i', $viaje['salida'], 'America/Bogota')->locale('es');
            return ['id'=>$viaje['id'], 'ruta'=>$ruta['origen'].' - '.$ruta['destino'], 'conductor'=>$conductor['nombre'], 'placa'=>$vehiculo['placa'], 'salida'=>$fecha->translatedFormat('j \d\e M, H:i'), 'estado'=>'Programado'];
        })->values()->all();
        return response()->json([
            'usuario' => $request->session()->get('usuario_demo'),
            'indicadores' => [
                ['nombre' => 'Vehículos registrados', 'valor' => $vehiculos->count(), 'descripcion' => 'Inventario de la flota'],
                ['nombre' => 'Disponibles', 'valor' => $vehiculos->where('estado','DISPONIBLE')->count(), 'descripcion' => 'Listos para asignar'],
                ['nombre' => 'Viajes programados', 'valor' => $programados->count(), 'descripcion' => 'Programación registrada'],
                ['nombre' => 'En mantenimiento', 'valor' => $vehiculos->where('estado','MANTENIMIENTO')->count(), 'descripcion' => 'Fuera de operación'],
            ],
            'viajes' => $proximos,
            'estados' => collect(['DISPONIBLE'=>'Disponible','EN_RUTA'=>'En viaje','MANTENIMIENTO'=>'Mantenimiento','FUERA_SERVICIO'=>'Fuera de servicio'])->map(fn ($nombre,$estado) => ['nombre'=>$nombre,'cantidad'=>$vehiculos->where('estado',$estado)->count()])->values()->all(),
        ]);
    }
}
