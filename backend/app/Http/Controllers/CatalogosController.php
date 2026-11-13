<?php

namespace App\Http\Controllers;

use App\Services\RepositorioDemo;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class CatalogosController extends Controller
{
    public const TIPOS = ['rutas', 'conductores'];

    public function index(Request $request, RepositorioDemo $repositorio): JsonResponse
    {
        return response()->json(['usuario'=>$request->session()->get('usuario_demo')]
            + array_intersect_key($repositorio->leer(), array_flip(self::TIPOS)));
    }

    public function guardar(Request $request, RepositorioDemo $repositorio, string $tipo, ?int $id = null): JsonResponse
    {
        $entrada = $request->all();
        foreach (['codigo', 'nombre', 'origen', 'destino'] as $campo) {
            if (is_string($entrada[$campo] ?? null)) {
                $entrada[$campo] = trim($entrada[$campo]);
            }
        }
        if (is_string($entrada['codigo'] ?? null)) {
            $entrada['codigo'] = strtoupper($entrada['codigo']);
        }
        $reglas = $tipo === 'rutas' ? [
            'codigo'=>['required','string','max:15','regex:/^[A-Z0-9-]+$/'],
            'origen'=>['required','string','max:60'],
            'destino'=>['required','string','max:60','different:origen'],
            'distancia'=>['required','numeric','decimal:0,2','gt:0','max:5000'],
            'duracion'=>['required','integer','between:1,4320'],
            'activa'=>['required','boolean'],
        ] : [
            'nombre'=>['required','string','max:80'],
            'licencia_vence'=>['required','date_format:Y-m-d'],
            'estado'=>['required',Rule::in(['DISPONIBLE','INACTIVO'])],
        ];
        $datos = Validator::make($entrada, $reglas + [
            'revision'=>$id === null ? ['exclude'] : ['required','integer','min:0'],
        ], [
            'required'=>'Completa este campo.',
            'string'=>'Escribe un texto válido.',
            'max'=>'Revisa la longitud o el valor del campo.',
            'integer'=>'Escribe un número entero.',
            'numeric'=>'Escribe un número válido.',
            'regex'=>'Usa letras, números o guiones.',
            'different'=>'El destino debe ser distinto del origen.',
            'gt'=>'El valor debe ser mayor que cero.',
            'decimal'=>'Usa como máximo dos decimales.',
            'between'=>'La duración debe estar entre 1 y 4.320 minutos.',
            'boolean'=>'Selecciona un estado válido.',
            'in'=>'Selecciona un estado válido.',
            'date_format'=>'Selecciona una fecha válida.',
        ])->validate();

        $revision = (int) ($datos['revision'] ?? 0);
        unset($datos['revision']);
        if ($tipo === 'rutas') {
            $datos['activa'] = (bool) $datos['activa'];
            $datos['distancia'] = (float) $datos['distancia'];
            $datos['duracion'] = (int) $datos['duracion'];
            if (mb_strtolower($datos['origen']) === mb_strtolower($datos['destino'])) {
                throw ValidationException::withMessages(['destino'=>'El destino debe ser distinto del origen.']);
            }
        }

        $item = $repositorio->modificar(function (array &$flota) use ($tipo, $id, $datos, $revision): array {
            $items = &$flota[$tipo];
            if ($tipo === 'rutas') {
                foreach ($items as $ruta) {
                    if ($ruta['id'] !== $id && $ruta['codigo'] === $datos['codigo']) {
                        throw ValidationException::withMessages(['codigo'=>'Este código de ruta ya existe.']);
                    }
                }
            }
            if ($id === null) {
                $item = ['id'=>max([0, ...array_column($items, 'id')]) + 1, 'revision'=>0] + $datos;
                $items[] = $item;
                return $item;
            }

            $posicion = array_search($id, array_column($items, 'id'), true);
            abort_if($posicion === false, 404, 'No encontramos este registro.');
            $actual = $items[$posicion];
            abort_if($revision !== ($actual['revision'] ?? 0), 409, 'El registro cambió. Recarga la página y vuelve a intentarlo.');
            $referencia = $tipo === 'rutas' ? 'ruta_id' : 'conductor_id';
            foreach ($flota['viajes'] as $viaje) {
                if ($viaje[$referencia] !== $id) continue;
                if ($tipo === 'rutas' && $datos['duracion'] !== (int) $actual['duracion']) {
                    throw ValidationException::withMessages(['duracion'=>'Esta ruta tiene historial. Crea una ruta con el nuevo tiempo para conservar sus intervalos.']);
                }
                if ($tipo === 'rutas' && ($datos['distancia'] != $actual['distancia'] || $datos['origen'] !== $actual['origen'] || $datos['destino'] !== $actual['destino'])) {
                    throw ValidationException::withMessages(['destino'=>'Esta ruta tiene historial. Crea una ruta nueva para cambiar su recorrido.']);
                }
                if (!in_array($viaje['estado'], ['PROGRAMADO', 'EN_CURSO'], true)) continue;
                if ($tipo === 'rutas' && !$datos['activa']) {
                    throw ValidationException::withMessages(['activa'=>'La ruta tiene viajes programados o en curso.']);
                }
                if ($tipo === 'conductores' && ($datos['estado'] === 'INACTIVO' || $datos['licencia_vence'] < substr($viaje['salida'], 0, 10))) {
                    throw ValidationException::withMessages(['estado'=>'El conductor tiene viajes vigentes. Revisa su disponibilidad y la fecha de licencia.']);
                }
            }
            if ($tipo === 'conductores' && $actual['estado'] === 'EN_VIAJE') {
                $datos['estado'] = 'EN_VIAJE';
            }
            return $items[$posicion] = array_replace($actual, $datos, ['revision'=>$revision + 1]);
        });

        return response()->json(['message'=>'Registro guardado.', 'item'=>$item], $id === null ? 201 : 200);
    }
}
