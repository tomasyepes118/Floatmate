<?php

namespace App\Http\Controllers;

use App\Services\RepositorioDemo;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\StreamedResponse;

class RegistrosController extends Controller
{
    public const TIPOS = ['combustible', 'mantenimientos', 'incidentes'];

    public function index(Request $request, RepositorioDemo $repositorio): JsonResponse
    {
        return response()->json(['usuario'=>$request->session()->get('usuario_demo')] + $this->consulta($repositorio->leer()));
    }

    public function guardar(Request $request, RepositorioDemo $repositorio, string $tipo): JsonResponse
    {
        $reglas = [
            'fecha'=>['required','date_format:Y-m-d','before_or_equal:'.Carbon::today('America/Bogota')->toDateString()],
            'detalle'=>['required','string','max:500'],
        ];
        if ($tipo === 'incidentes') {
            $reglas += [
                'viaje_id'=>['required','integer'],
                'gravedad'=>['required',Rule::in(['BAJA','MEDIA','ALTA'])],
            ];
        } else {
            $reglas['vehiculo_id'] = ['required','integer'];
            $reglas += $tipo === 'combustible' ? [
                'litros'=>['required','numeric','decimal:0,2','gt:0','max:2000'],
                'precio_litro'=>['required','numeric','decimal:0,2','gt:0','max:1000000'],
            ] : [
                'kilometraje'=>['required','numeric','decimal:0,2','between:0,9999999'],
                'proximo_mantenimiento'=>['required','numeric','decimal:0,2','gt:kilometraje','max:9999999'],
            ];
        }
        $datos = Validator::make($request->all(), $reglas, [
            'required'=>'Completa este campo.',
            'date_format'=>'Selecciona una fecha válida.',
            'before_or_equal'=>'La fecha del registro debe ser hoy o anterior.',
            'string'=>'Escribe un texto válido.',
            'integer'=>'Selecciona una opción válida.',
            'in'=>'Selecciona una opción válida.',
            'numeric'=>'Escribe un número válido.',
            'max'=>'Revisa el tamaño o valor del campo.',
            'decimal'=>'Usa como máximo dos decimales.',
            'between'=>'El kilometraje debe estar entre 0 y 9.999.999.',
            'gt'=>'Escribe un valor mayor que cero.',
            'proximo_mantenimiento.gt'=>'El próximo mantenimiento debe ser posterior al kilometraje del servicio.',
        ])->validate();

        $item = $repositorio->modificar(function (array &$flota) use ($tipo, $datos, $request): array {
            $nuevo = $datos;
            $nuevo['id'] = max([0, ...array_column($flota[$tipo], 'id')]) + 1;
            $nuevo['registrado_por'] = $request->session()->get('usuario_demo.nombre');
            if ($tipo === 'incidentes') {
                $viaje = collect($flota['viajes'])->firstWhere('id', (int) $datos['viaje_id']);
                if (!$viaje || !in_array($viaje['estado'], ['EN_CURSO','FINALIZADO'], true)) {
                    throw ValidationException::withMessages(['viaje_id'=>'Selecciona un viaje en curso o finalizado.']);
                }
                if ($datos['fecha'] < substr($viaje['salida_real'] ?? $viaje['salida'], 0, 10)) {
                    throw ValidationException::withMessages(['fecha'=>'La fecha del incidente no puede ser anterior a la salida del viaje.']);
                }
                $nuevo['viaje_id'] = $viaje['id'];
                $nuevo['vehiculo_id'] = $viaje['vehiculo_id'];
            } else {
                $indice = array_search((int) $datos['vehiculo_id'], array_column($flota['vehiculos'], 'id'), true);
                if ($indice === false) {
                    throw ValidationException::withMessages(['vehiculo_id'=>'Selecciona un vehículo del inventario.']);
                }
                $bus = &$flota['vehiculos'][$indice];
                $nuevo['vehiculo_id'] = $bus['id'];
                if ($tipo === 'combustible') {
                    $nuevo['litros'] = (float) $datos['litros'];
                    $nuevo['precio_litro'] = (float) $datos['precio_litro'];
                    $nuevo['total'] = round($nuevo['litros'] * $nuevo['precio_litro'], 2);
                } else {
                    $this->aplicarMantenimiento($flota, $bus, $nuevo);
                }
            }
            $flota[$tipo][] = $nuevo;
            return $nuevo;
        });
        return response()->json(['message'=>'Registro guardado.', 'item'=>$item], 201);
    }

    private function aplicarMantenimiento(array $flota, array &$bus, array &$registro): void
    {
        if ($bus['estado'] === 'EN_RUTA') {
            throw ValidationException::withMessages(['vehiculo_id'=>'Finaliza el viaje en curso antes de registrar el servicio.']);
        }
        $registro['kilometraje'] = (float) $registro['kilometraje'];
        $registro['proximo_mantenimiento'] = (float) $registro['proximo_mantenimiento'];
        if ($registro['kilometraje'] < $bus['kilometraje']) {
            throw ValidationException::withMessages(['kilometraje'=>'El kilometraje del servicio no puede ser menor al actual.']);
        }
        $ultimo = collect($flota['mantenimientos'])->where('vehiculo_id', $bus['id'])->max('fecha');
        if ($ultimo && $registro['fecha'] < $ultimo) {
            throw ValidationException::withMessages(['fecha'=>'La fecha no puede ser anterior al último mantenimiento registrado.']);
        }
        $rutas = collect($flota['rutas'])->keyBy('id');
        foreach ($flota['viajes'] as $viaje) {
            if ($viaje['vehiculo_id'] === $bus['id'] && $viaje['estado'] === 'PROGRAMADO'
                && round($registro['kilometraje'] + $rutas[$viaje['ruta_id']]['distancia'], 2) > $registro['proximo_mantenimiento']) {
                throw ValidationException::withMessages(['proximo_mantenimiento'=>'El vehículo debe poder completar cada ruta programada.']);
            }
        }
        $bus['kilometraje'] = $registro['kilometraje'];
        $bus['proximo_mantenimiento'] = $registro['proximo_mantenimiento'];
        $bus['revision'] = ($bus['revision'] ?? 0) + 1;
        if ($bus['estado'] === 'MANTENIMIENTO') {
            $bus['estado'] = 'DISPONIBLE';
        }
    }

    public function exportar(RepositorioDemo $repositorio, string $tipo): StreamedResponse
    {
        $registros = $this->consulta($repositorio->leer())[$tipo];
        $campos = match ($tipo) {
            'combustible'=>['id','fecha','placa','litros','precio_litro','total','detalle','registrado_por'],
            'mantenimientos'=>['id','fecha','placa','kilometraje','proximo_mantenimiento','detalle','registrado_por'],
            'incidentes'=>['id','fecha','placa','viaje_id','gravedad','detalle','registrado_por'],
        };
        return response()->streamDownload(function () use ($campos, $registros): void {
            $salida = fopen('php://output', 'wb');
            fwrite($salida, "\xEF\xBB\xBF");
            fputcsv($salida, $campos, ';', '"', '');
            foreach ($registros as $registro) {
                $fila = array_map(static function (string $campo) use ($registro): mixed {
                    $valor = $registro[$campo];
                    return is_string($valor) && preg_match('/^\s*[=+@\-]|^[\t\r\n]/u', $valor) ? "'".$valor : $valor;
                }, $campos);
                fputcsv($salida, $fila, ';', '"', '');
            }
            fclose($salida);
        }, "floatmate-${tipo}.csv", ['Content-Type'=>'text/csv; charset=UTF-8']);
    }

    private function consulta(array $datos): array
    {
        $placas = array_column($datos['vehiculos'], 'placa', 'id');
        $resultado = array_intersect_key($datos, array_flip(['vehiculos','viajes']));
        foreach (self::TIPOS as $tipo) {
            $resultado[$tipo] = array_map(
                fn (array $registro): array => $registro + ['placa'=>$placas[$registro['vehiculo_id']] ?? ''],
                array_reverse($datos[$tipo]),
            );
        }
        return $resultado;
    }
}
