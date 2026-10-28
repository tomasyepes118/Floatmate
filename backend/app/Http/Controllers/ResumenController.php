<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ResumenController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        // Valores de la referencia visual. No son consultas ni registros de una base de datos.
        return response()->json([
            'usuario' => $request->session()->get('usuario_demo'),
            'indicadores' => [
                ['nombre' => 'Vehículos registrados', 'valor' => 5, 'descripcion' => 'Inventario de la flota'],
                ['nombre' => 'Disponibles', 'valor' => 3, 'descripcion' => 'Listos para asignar'],
                ['nombre' => 'Viajes programados', 'valor' => 2, 'descripcion' => 'Programación registrada'],
                ['nombre' => 'En mantenimiento', 'valor' => 1, 'descripcion' => 'Fuera de operación'],
            ],
            'viajes' => [
                ['id' => 1, 'ruta' => 'Medellín - Rionegro', 'conductor' => 'Carlos Restrepo', 'salida' => '5 de oct, 07:30', 'placa' => 'TPQ482', 'estado' => 'Programado'],
                ['id' => 2, 'ruta' => 'Medellín - Guatapé', 'conductor' => 'Andrés Ruiz', 'salida' => '6 de oct, 08:00', 'placa' => 'JRC728', 'estado' => 'Programado'],
            ],
            'estados' => [
                ['nombre' => 'Disponible', 'cantidad' => 3],
                ['nombre' => 'En viaje', 'cantidad' => 1],
                ['nombre' => 'Mantenimiento', 'cantidad' => 1],
            ],
        ]);
    }
}
