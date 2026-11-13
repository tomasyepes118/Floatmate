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
        return response()->json(['usuario'=>$request->session()->get('usuario_demo'),'pruebas_navegador'=>config('demo.pruebas_navegador')]
            + array_intersect_key($datos, array_flip(['vehiculos', 'viajes', 'rutas', 'conductores'])));
    }

    public function guardarVehiculo(Request $request, RepositorioDemo $repositorio, ?int $id = null): JsonResponse
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
            'estado'=>['required',Rule::in($id === null
                ? ['DISPONIBLE','EN_RUTA','MANTENIMIENTO','FUERA_SERVICIO']
                : ['DISPONIBLE','MANTENIMIENTO','FUERA_SERVICIO'])],
            'revision'=>$id === null ? ['exclude'] : ['required','integer','min:0'],
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

        $revision = (int) ($datos['revision'] ?? 0);
        unset($datos['revision']);
        foreach (['modelo', 'capacidad'] as $campo) $datos[$campo] = (int) $datos[$campo];
        foreach (['kilometraje', 'proximo_mantenimiento'] as $campo) $datos[$campo] = (float) $datos[$campo];

        $vehiculo = $repositorio->modificar(function (array &$registro) use ($datos, $id, $revision): array {
            foreach ($registro['vehiculos'] as $existente) {
                if ($existente['id'] === $id) continue;
                if ($existente['placa'] === $datos['placa']) throw ValidationException::withMessages(['placa'=>'La placa ya está registrada. Revisa el dato.']);
                if ($existente['codigo'] === $datos['codigo']) throw ValidationException::withMessages(['codigo'=>'El código interno ya está registrado.']);
            }
            if ($id === null) {
                $nuevo = ['id'=>max([0, ...array_column($registro['vehiculos'], 'id')]) + 1] + $datos;
                $registro['vehiculos'][] = $nuevo;
                return $nuevo;
            }

            $indice = array_search($id, array_column($registro['vehiculos'], 'id'), true);
            abort_if($indice === false, 404, 'No encontramos ese vehículo.');
            $actual = $registro['vehiculos'][$indice];
            abort_if($revision !== ($actual['revision'] ?? 0), 409, 'El vehículo cambió en otra operación. Cierra el formulario y vuelve a abrirlo.');
            if ($datos['kilometraje'] < $actual['kilometraje']) {
                throw ValidationException::withMessages(['kilometraje'=>'El kilometraje no puede ser menor al último valor guardado.']);
            }

            foreach ($registro['viajes'] as $viaje) {
                if ($viaje['vehiculo_id'] !== $id) continue;
                if ($viaje['estado'] === 'EN_CURSO') {
                    throw ValidationException::withMessages(['estado'=>'Finaliza el viaje en curso antes de editar este vehículo.']);
                }
                if ($viaje['estado'] !== 'PROGRAMADO') continue;
                if ($datos['estado'] !== 'DISPONIBLE') {
                    throw ValidationException::withMessages(['estado'=>'Este vehículo tiene viajes programados. Cancélalos antes de retirarlo o pasarlo a mantenimiento.']);
                }
                if ($datos['capacidad'] < $viaje['pasajeros']) {
                    throw ValidationException::withMessages(['capacidad'=>'La capacidad debe cubrir los pasajeros de los viajes ya programados.']);
                }
                $ruta = collect($registro['rutas'])->firstWhere('id', $viaje['ruta_id']);
                if (round($datos['kilometraje'] + $ruta['distancia'], 2) > $datos['proximo_mantenimiento']) {
                    throw ValidationException::withMessages(['proximo_mantenimiento'=>'El vehículo debe poder completar cada ruta que tiene programada.']);
                }
            }

            return $registro['vehiculos'][$indice] = array_replace($actual, $datos, ['revision'=>$revision + 1]);
        });
        $mensaje = $id === null ? 'Vehículo registrado correctamente.' : 'Vehículo actualizado correctamente.';
        return response()->json(['message'=>$mensaje, 'vehiculo'=>$vehiculo], $id === null ? 201 : 200);
    }

    public function guardarViaje(Request $request, RepositorioDemo $repositorio): JsonResponse
    {
        $datos = $this->validarProgramacion($request);
        $viaje = $repositorio->modificar(function (array &$registro) use ($datos): array {
            $salida = $this->salidaFutura($datos['salida']);
            $this->validarAsignacion($registro, $datos, $salida);
            $nuevo = ['id'=>max([9000, ...array_column($registro['viajes'], 'id')]) + 1, 'estado'=>'PROGRAMADO', 'observaciones'=>trim($datos['observaciones'] ?? '')];
            foreach (['ruta_id','vehiculo_id','conductor_id','pasajeros'] as $campo) $nuevo[$campo] = (int)$datos[$campo];
            $nuevo['salida'] = $datos['salida'];
            $registro['viajes'][] = $nuevo;
            return $nuevo;
        });
        return response()->json(['message'=>'Viaje programado correctamente.', 'viaje'=>$viaje], 201);
    }

    public function revisarElegibilidad(Request $request, RepositorioDemo $repositorio): JsonResponse
    {
        $datos = $this->validarProgramacion($request);
        $salida = $this->salidaFutura($datos['salida']);
        $registro = $repositorio->leer();
        $evaluacion = $this->evaluarAsignacion($registro, $datos, $salida);
        $alternativas = [];
        if ($evaluacion['problemas']) {
            foreach ($registro['vehiculos'] as $vehiculo) {
                if ($vehiculo['id'] === (int) $datos['vehiculo_id'] || $vehiculo['estado'] !== 'DISPONIBLE') continue;
                $opcion = array_replace($datos, ['vehiculo_id'=>$vehiculo['id']]);
                $resultado = $this->evaluarAsignacion($registro, $opcion, $salida);
                if (!$resultado['problemas']) {
                    $alternativas[] = ['id'=>$vehiculo['id'], 'placa'=>$vehiculo['placa'], 'capacidad'=>$vehiculo['capacidad']];
                }
                if (count($alternativas) === 3) break;
            }
        }
        return response()->json($evaluacion + ['alternativas'=>$alternativas]);
    }

    private function validarProgramacion(Request $request): array
    {
        return Validator::make($request->all(), [
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

    }

    private function salidaFutura(string $fecha): Carbon
    {
        $salida = Carbon::createFromFormat('!Y-m-d\TH:i', $fecha, 'America/Bogota');
        if ($salida->lessThanOrEqualTo(Carbon::now('America/Bogota'))) {
            throw ValidationException::withMessages(['salida'=>'Selecciona una fecha y hora futuras.']);
        }
        return $salida;
    }

    public function registrarControl(Request $request, RepositorioDemo $repositorio, int $id): JsonResponse
    {
        $datos = Validator::make($request->all(), [
            'numero_ticket'=>['required', 'string', 'max:40'],
            'alcoholemia_mg_l'=>['required', 'numeric', 'decimal:0,3', 'between:0,99.999'],
        ], [
            'numero_ticket.required'=>'Escribe el número del ticket.',
            'numero_ticket.string'=>'Escribe un número de ticket válido.',
            'numero_ticket.max'=>'El ticket admite hasta 40 caracteres.',
            'alcoholemia_mg_l.*'=>'Ingresa un valor entre 0 y 99,999 mg/L con hasta tres decimales.',
        ])->validate();

        $viaje = $repositorio->modificar(function (array &$registro) use ($datos, $id): array {
            $indice = array_search($id, array_column($registro['viajes'], 'id'), true);
            abort_if($indice === false, 404, 'No encontramos ese viaje.');
            $viaje = &$registro['viajes'][$indice];
            if ($viaje['estado'] !== 'PROGRAMADO' || isset($viaje['control_salida'])) {
                throw ValidationException::withMessages(['estado'=>'El control se registra una sola vez y antes de iniciar el viaje.']);
            }

            $ticket = mb_strtoupper($datos['numero_ticket']);
            foreach ($registro['viajes'] as $existente) {
                if (($existente['control_salida']['numero_ticket'] ?? null) === $ticket) {
                    throw ValidationException::withMessages(['numero_ticket'=>'Este ticket ya está registrado.']);
                }
            }
            $alcoholemia = (float) $datos['alcoholemia_mg_l'];
            $viaje['control_salida'] = [
                'numero_ticket'=>$ticket,
                'alcoholemia_mg_l'=>$alcoholemia,
                'resultado'=>$alcoholemia === 0.0 ? 'APROBADO' : 'RECHAZADO',
                'registrado_en'=>Carbon::now('America/Bogota')->toIso8601String(),
            ];
            return $viaje;
        });

        return response()->json(['message'=>'Control de salida registrado.', 'viaje'=>$viaje], 201);
    }

    public function cambiarEstadoViaje(Request $request, RepositorioDemo $repositorio, int $id): JsonResponse
    {
        $datos = Validator::make($request->all(), [
            'estado'=>['required', Rule::in(['EN_CURSO', 'FINALIZADO', 'CANCELADO'])],
            'kilometraje_llegada'=>['exclude_unless:estado,FINALIZADO', 'required', 'numeric', 'between:0,9999999', 'decimal:0,2'],
        ], [
            'estado.*'=>'Selecciona un estado válido para el viaje.',
            'kilometraje_llegada.*'=>'Ingresa un kilometraje de llegada válido con hasta dos decimales.',
        ])->validate();

        $estado = $datos['estado'];
        $viaje = $repositorio->modificar(function (array &$registro) use ($datos, $estado, $id): array {
            $indice = array_search($id, array_column($registro['viajes'], 'id'), true);
            abort_if($indice === false, 404, 'No encontramos ese viaje.');
            $viaje = &$registro['viajes'][$indice];
            $origen = $estado === 'FINALIZADO' ? 'EN_CURSO' : 'PROGRAMADO';
            if ($viaje['estado'] !== $origen) {
                throw ValidationException::withMessages(['estado'=>'El estado actual del viaje no permite esta acción.']);
            }

            $ahora = Carbon::now('America/Bogota');
            if ($estado === 'CANCELADO') {
                $viaje['estado'] = $estado;
                $viaje['cancelado_en'] = $ahora->toIso8601String();
                return $viaje;
            }

            if ($estado === 'EN_CURSO') {
                if (($viaje['control_salida']['resultado'] ?? null) !== 'APROBADO') {
                    throw ValidationException::withMessages(['estado'=>'Registra un control de salida aprobado para iniciar el viaje.']);
                }
                $this->validarAsignacion($registro, $viaje, $ahora, $id);
            }

            $vehiculo = array_search($viaje['vehiculo_id'], array_column($registro['vehiculos'], 'id'), true);
            $conductor = array_search($viaje['conductor_id'], array_column($registro['conductores'], 'id'), true);
            abort_if($vehiculo === false || $conductor === false, 409, 'Revisa la asignación del vehículo y del conductor.');
            $bus = &$registro['vehiculos'][$vehiculo];
            $chofer = &$registro['conductores'][$conductor];

            if ($estado === 'EN_CURSO') {
                $bus['estado'] = 'EN_RUTA';
                $chofer['estado'] = 'EN_VIAJE';
                $viaje['salida_real'] = $ahora->toIso8601String();
            } else {
                $kilometraje = (float) $datos['kilometraje_llegada'];
                if ($kilometraje < $bus['kilometraje']) {
                    throw ValidationException::withMessages(['kilometraje_llegada'=>'El kilometraje de llegada no puede ser menor al último valor guardado.']);
                }
                $bus['kilometraje'] = $kilometraje;
                $bus['estado'] = $kilometraje >= $bus['proximo_mantenimiento'] ? 'MANTENIMIENTO' : 'DISPONIBLE';
                $chofer['estado'] = 'DISPONIBLE';
                $viaje['llegada_real'] = $ahora->toIso8601String();
                $viaje['kilometraje_llegada'] = $kilometraje;
            }
            $bus['revision'] = ($bus['revision'] ?? 0) + 1;
            $chofer['revision'] = ($chofer['revision'] ?? 0) + 1;
            $viaje['estado'] = $estado;
            return $viaje;
        });

        $mensaje = match ($estado) {
            'EN_CURSO' => 'Viaje iniciado correctamente.',
            'FINALIZADO' => 'Viaje finalizado correctamente.',
            'CANCELADO' => 'Viaje cancelado correctamente.',
        };
        return response()->json(['message'=>$mensaje, 'viaje'=>$viaje]);
    }

    private function validarAsignacion(array $registro, array $datos, Carbon $salida, ?int $viajeId = null): void
    {
        $problema = $this->evaluarAsignacion($registro, $datos, $salida, $viajeId)['problemas'][0] ?? null;
        if ($problema) {
            throw ValidationException::withMessages([$problema['campo']=>$problema['mensaje']]);
        }
    }

    private function evaluarAsignacion(array $registro, array $datos, Carbon $salida, ?int $viajeId = null): array
    {
        $ruta = collect($registro['rutas'])->firstWhere('id', (int) $datos['ruta_id']);
        $vehiculo = collect($registro['vehiculos'])->firstWhere('id', (int) $datos['vehiculo_id']);
        $conductor = collect($registro['conductores'])->firstWhere('id', (int) $datos['conductor_id']);
        $problemas = [];
        $registrar = function (string $campo, string $mensaje) use (&$problemas): void {
            $problemas[] = compact('campo', 'mensaje');
        };
        if (!$ruta || !$ruta['activa']) $registrar('ruta_id', 'Selecciona una ruta activa.');
        if (!$vehiculo || $vehiculo['estado'] !== 'DISPONIBLE') $registrar('vehiculo_id', 'Selecciona un vehículo disponible.');
        if (!$conductor || $conductor['estado'] !== 'DISPONIBLE') $registrar('conductor_id', 'Selecciona un conductor disponible.');
        if ($conductor && $conductor['licencia_vence'] < $salida->format('Y-m-d')) {
            $registrar('conductor_id', 'La licencia del conductor vence antes de este viaje.');
        }
        if ($vehiculo && (int) $datos['pasajeros'] > $vehiculo['capacidad']) {
            $registrar('pasajeros', 'Los pasajeros superan la capacidad del vehículo.');
        }
        $kilometraje = null;
        if ($ruta && $vehiculo) {
            $llegadaKm = round($vehiculo['kilometraje'] + $ruta['distancia'], 2);
            $kilometraje = [
                'distancia'=>$ruta['distancia'],
                'disponible'=>round($vehiculo['proximo_mantenimiento'] - $vehiculo['kilometraje'], 2),
                'llegada'=>$llegadaKm,
                'limite'=>$vehiculo['proximo_mantenimiento'],
            ];
            if ($llegadaKm > $vehiculo['proximo_mantenimiento']) {
                $registrar('vehiculo_id', 'El vehículo requiere mantenimiento antes de completar esta ruta.');
            }
        }
        if ($ruta && $ruta['activa']) {
            $this->revisarCruces($registro, $datos, $ruta, $salida, $viajeId, $registrar);
        }
        return ['problemas'=>$problemas, 'kilometraje'=>$kilometraje];
    }

    private function revisarCruces(array $registro, array $datos, array $ruta, Carbon $salida, ?int $viajeId, callable $registrar): void
    {
        $llegada = $salida->copy()->addMinutes($ruta['duracion']);
        $vehiculoOcupado = $conductorOcupado = false;
        foreach ($registro['viajes'] as $existente) {
            if ($existente['id'] === $viajeId || !in_array($existente['estado'], ['PROGRAMADO', 'EN_CURSO'], true)) continue;
            $mismoVehiculo = $existente['vehiculo_id'] === (int) $datos['vehiculo_id'];
            $mismoConductor = $existente['conductor_id'] === (int) $datos['conductor_id'];
            if (!$mismoVehiculo && !$mismoConductor) continue;
            $otraRuta = collect($registro['rutas'])->firstWhere('id', $existente['ruta_id']);
            $inicio = Carbon::parse($existente['salida_real'] ?? $existente['salida'], 'America/Bogota');
            if ($salida->lessThan($inicio->copy()->addMinutes($otraRuta['duracion'])) && $llegada->greaterThan($inicio)) {
                $vehiculoOcupado = $vehiculoOcupado || $mismoVehiculo;
                $conductorOcupado = $conductorOcupado || $mismoConductor;
            }
        }
        if ($vehiculoOcupado) $registrar('salida', 'El vehículo ya tiene un viaje en ese horario.');
        if ($conductorOcupado) $registrar('salida', 'El conductor ya tiene un viaje en ese horario.');
    }
}
