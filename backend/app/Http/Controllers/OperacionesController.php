<?php

namespace App\Http\Controllers;

use App\Services\RepositorioDemo;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class OperacionesController extends Controller
{
    public function vehiculos(Request $request, RepositorioDemo $repositorio): JsonResponse
    {
        return response()->json(['usuario'=>$request->session()->get('usuario_demo'), 'vehiculos'=>$repositorio->leer()['vehiculos']]);
    }

    public function viajes(Request $request, RepositorioDemo $repositorio): JsonResponse
    {
        $datos = $repositorio->leer();
        return response()->json(['usuario'=>$request->session()->get('usuario_demo'),'pruebas_navegador'=>config('demo.pruebas_navegador')] + $datos);
    }

    public function guardarVehiculo(Request $request, RepositorioDemo $repositorio): JsonResponse
    {
        $entrada = $request->all();
        foreach (['placa','codigo','marca'] as $campo) {
            if (is_string($entrada[$campo] ?? null)) $entrada[$campo] = trim($entrada[$campo]);
        }
        foreach (['placa','codigo'] as $campo) {
            if (is_string($entrada[$campo] ?? null)) $entrada[$campo] = strtoupper($entrada[$campo]);
        }
        $datos = Validator::make($entrada, [
            'placa'=>['required','string','regex:/^[A-Z]{3}[0-9]{3}$/'],
            'codigo'=>['required','string','max:15','regex:/^[A-Z0-9-]+$/'],
            'tipo'=>['required',Rule::in(['BUS_URBANO','BUS_INTERMUNICIPAL','MICROBUS'])],
            'marca'=>['required','string','max:40'],
            'modelo'=>['required','integer','between:2000,2035'],
            'capacidad'=>['required','integer','between:10,80'],
            'kilometraje'=>['required','numeric','min:0','max:9999999','decimal:0,2'],
            'proximo_mantenimiento'=>['required','numeric','gte:kilometraje','max:9999999','decimal:0,2'],
            'estado'=>['required',Rule::in(['DISPONIBLE','EN_RUTA','MANTENIMIENTO','FUERA_SERVICIO'])],
        ], [
            'required'=>'Completa el campo :attribute.', 'string'=>'Revisa el campo :attribute.',
            'placa.regex'=>'La placa debe tener tres letras y tres números, por ejemplo ABC123.',
            'codigo.regex'=>'El código interno solo admite letras, números y guiones.',
            'integer'=>'El campo :attribute debe ser un número entero.',
            'numeric'=>'El campo :attribute debe ser un número válido.',
            'modelo.between'=>'El modelo debe estar entre 2000 y 2035.',
            'capacidad.between'=>'La capacidad debe estar entre 10 y 80 pasajeros.',
            'min'=>'El campo :attribute no puede ser negativo.',
            'max'=>'Revisa el tamaño o valor del campo :attribute.',
            'in'=>'Selecciona una opción válida para :attribute.',
            'decimal'=>'El campo :attribute admite hasta dos decimales.',
            'proximo_mantenimiento.gte'=>'El próximo mantenimiento no puede ser menor al kilometraje actual.',
        ], ['codigo'=>'código interno','tipo'=>'tipo','modelo'=>'modelo','capacidad'=>'capacidad','kilometraje'=>'kilometraje','proximo_mantenimiento'=>'próximo mantenimiento'])->validate();

        $vehiculo = $repositorio->modificar(function (array &$registro) use ($datos): array {
            foreach ($registro['vehiculos'] as $existente) {
                if ($existente['placa'] === $datos['placa']) throw ValidationException::withMessages(['placa'=>'La placa ya está registrada. Revisa el dato.']);
                if ($existente['codigo'] === $datos['codigo']) throw ValidationException::withMessages(['codigo'=>'El código interno ya está registrado.']);
            }
            $nuevo = ['id'=>max(array_column($registro['vehiculos'], 'id')) + 1] + $datos;
            foreach (['modelo','capacidad'] as $campo) $nuevo[$campo] = (int)$nuevo[$campo];
            foreach (['kilometraje','proximo_mantenimiento'] as $campo) $nuevo[$campo] = (float)$nuevo[$campo];
            $registro['vehiculos'][] = $nuevo;
            return $nuevo;
        });
        return response()->json(['message'=>'Vehículo registrado correctamente.', 'vehiculo'=>$vehiculo], 201);
    }

    public function guardarViaje(Request $request, RepositorioDemo $repositorio): JsonResponse
    {
        $datos = Validator::make($request->all(), [
            'ruta_id'=>['required','integer'], 'vehiculo_id'=>['required','integer'], 'conductor_id'=>['required','integer'],
            'salida'=>['required','date_format:Y-m-d\TH:i'], 'pasajeros'=>['required','integer','min:1','max:80'],
            'observaciones'=>['nullable','string','max:250'],
        ], [
            'required'=>'Completa el campo :attribute.', 'integer'=>'Selecciona o escribe un valor válido para :attribute.',
            'salida.date_format'=>'Escribe una fecha y hora válidas.', 'pasajeros.min'=>'Debe viajar al menos un pasajero.',
            'pasajeros.max'=>'La cantidad de pasajeros no puede superar 80.',
            'observaciones.max'=>'Las observaciones admiten hasta 250 caracteres.',
            'observaciones.string'=>'Revisa las observaciones.',
        ], ['ruta_id'=>'ruta','vehiculo_id'=>'vehículo','conductor_id'=>'conductor','salida'=>'fecha de salida','pasajeros'=>'pasajeros'])->validate();

        $viaje = $repositorio->modificar(function (array &$registro) use ($datos): array {
            $ruta = collect($registro['rutas'])->firstWhere('id', (int)$datos['ruta_id']);
            $vehiculo = collect($registro['vehiculos'])->firstWhere('id', (int)$datos['vehiculo_id']);
            $conductor = collect($registro['conductores'])->firstWhere('id', (int)$datos['conductor_id']);
            if (!$ruta || !$ruta['activa']) throw ValidationException::withMessages(['ruta_id'=>'Selecciona una ruta activa.']);
            if (!$vehiculo || $vehiculo['estado'] !== 'DISPONIBLE') throw ValidationException::withMessages(['vehiculo_id'=>'Selecciona un vehículo disponible.']);
            if (!$conductor || $conductor['estado'] !== 'DISPONIBLE') throw ValidationException::withMessages(['conductor_id'=>'Selecciona un conductor disponible.']);
            $salida = Carbon::createFromFormat('!Y-m-d\TH:i', $datos['salida'], 'America/Bogota');
            if ($salida->lessThanOrEqualTo(Carbon::now('America/Bogota'))) throw ValidationException::withMessages(['salida'=>'Selecciona una fecha y hora futuras.']);
            if ($conductor['licencia_vence'] < $salida->format('Y-m-d')) throw ValidationException::withMessages(['conductor_id'=>'La licencia del conductor vence antes de este viaje.']);
            if ((int)$datos['pasajeros'] > $vehiculo['capacidad']) throw ValidationException::withMessages(['pasajeros'=>'Los pasajeros superan la capacidad del vehículo.']);
            if ($vehiculo['kilometraje'] + $ruta['distancia'] > $vehiculo['proximo_mantenimiento']) throw ValidationException::withMessages(['vehiculo_id'=>'El vehículo requiere mantenimiento antes de completar esta ruta.']);
            $llegada = $salida->copy()->addMinutes($ruta['duracion']);
            foreach ($registro['viajes'] as $existente) {
                if (!in_array($existente['estado'], ['PROGRAMADO','EN_CURSO'], true)) continue;
                if ($existente['vehiculo_id'] !== (int)$datos['vehiculo_id'] && $existente['conductor_id'] !== (int)$datos['conductor_id']) continue;
                $otraRuta = collect($registro['rutas'])->firstWhere('id', $existente['ruta_id']);
                $inicio = Carbon::createFromFormat('!Y-m-d\TH:i', $existente['salida'], 'America/Bogota');
                if ($salida->lessThan($inicio->copy()->addMinutes($otraRuta['duracion'])) && $llegada->greaterThan($inicio)) {
                    throw ValidationException::withMessages(['salida'=>'El vehículo o el conductor ya tienen un viaje en ese horario.']);
                }
            }
            $nuevo = ['id'=>max(array_column($registro['viajes'], 'id')) + 1, 'estado'=>'PROGRAMADO', 'observaciones'=>trim($datos['observaciones'] ?? '')];
            foreach (['ruta_id','vehiculo_id','conductor_id','pasajeros'] as $campo) $nuevo[$campo] = (int)$datos[$campo];
            $nuevo['salida'] = $datos['salida'];
            $registro['viajes'][] = $nuevo;
            return $nuevo;
        });
        return response()->json(['message'=>'Viaje programado correctamente.', 'viaje'=>$viaje], 201);
    }
}
