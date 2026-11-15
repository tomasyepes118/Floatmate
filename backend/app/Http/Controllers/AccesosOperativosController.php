<?php

namespace App\Http\Controllers;

use App\Services\AccesosOperativos;
use App\Services\RepositorioDemo;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class AccesosOperativosController extends Controller
{
    public function index(Request $request, RepositorioDemo $repositorio, AccesosOperativos $accesos): JsonResponse
    {
        $flota = $repositorio->leer();
        return response()->json([
            'usuario'=>$request->session()->get('usuario_demo'),
            'accesos'=>array_map(function (array $cuenta) use ($flota, $accesos): array {
                return [
                    'usuario'=>$cuenta['usuario'], 'rol'=>$cuenta['rol'], 'activo'=>$cuenta['activo'],
                    'conductor_id'=>$cuenta['conductor_id'] ?? null,
                    'nombre'=>$accesos->perfil($cuenta, $flota['conductores'])['nombre'] ?? 'Conductor no disponible',
                ];
            }, $flota['accesos']),
            'conductores'=>array_map(fn (array $conductor) => ['id'=>$conductor['id'], 'nombre'=>$conductor['nombre']], $flota['conductores']),
        ]);
    }

    public function crear(Request $request, RepositorioDemo $repositorio): JsonResponse
    {
        $datos = Validator::make($request->all(), [
            'usuario'=>['required', 'string', 'regex:/^[A-Za-z0-9][A-Za-z0-9._-]{2,59}$/D'],
            'rol'=>['required', Rule::in(['Operador', 'Conductor'])],
            'nombre'=>['exclude_unless:rol,Operador', 'required', 'string', 'max:80'],
            'conductor_id'=>['exclude_unless:rol,Conductor', 'required', 'integer', 'min:1'],
            'clave'=>$this->reglasClave(),
        ], [
            'usuario.*'=>'Usa de 3 a 60 caracteres. Empieza con una letra o un número y usa letras, números, puntos, guiones o guiones bajos.',
            'rol.*'=>'Selecciona Operador o Conductor.',
            'nombre.*'=>'Escribe el nombre del operador (máximo 80 caracteres).',
            'conductor_id.*'=>'Selecciona un conductor del catálogo.',
            'clave.*'=>'La contraseña debe tener entre 12 y 72 caracteres y ocupar como máximo 72 bytes.',
        ])->validate();

        $usuario = strtolower($datos['usuario']);
        $reservados = array_keys(array_filter(config('demo.cuentas'), fn ($cuenta) => !empty($cuenta['hash'])));
        $reservados[] = config('demo.usuario');
        $cuenta = [
            'usuario'=>$usuario, 'rol'=>$datos['rol'], 'activo'=>true, 'revision'=>0,
            'hash'=>Hash::make($datos['clave']),
        ];
        $cuenta += $datos['rol'] === 'Conductor' ? ['conductor_id'=>(int) $datos['conductor_id']] : ['nombre'=>$datos['nombre']];

        $repositorio->modificar(function (array &$flota) use ($usuario, $reservados, $cuenta): void {
            if (in_array($usuario, array_map('strtolower', $reservados), true) || in_array($usuario, array_column($flota['accesos'], 'usuario'), true)) {
                throw ValidationException::withMessages(['usuario'=>'Ya existe una cuenta con ese usuario.']);
            }
            if ($cuenta['rol'] === 'Conductor') {
                $id = $cuenta['conductor_id'];
                if (!in_array($id, array_column($flota['conductores'], 'id'), true)) {
                    throw ValidationException::withMessages(['conductor_id'=>'Selecciona un conductor del catálogo.']);
                }
                if (in_array($id, array_column($flota['accesos'], 'conductor_id'), true)) {
                    throw ValidationException::withMessages(['conductor_id'=>'Ese conductor ya tiene una cuenta.']);
                }
            }
            $flota['accesos'][] = $cuenta;
        });
        return response()->json(['message'=>'Cuenta creada.'], 201);
    }

    public function actualizar(Request $request, RepositorioDemo $repositorio, string $usuario): JsonResponse
    {
        $datos = Validator::make($request->all(), [
            'activo'=>['sometimes', 'required', 'boolean'],
            'clave'=>['sometimes', ...$this->reglasClave()],
        ], [
            'activo.*'=>'Selecciona un estado válido para la cuenta.',
            'clave.*'=>'La contraseña debe tener entre 12 y 72 caracteres y ocupar como máximo 72 bytes.',
        ])->validate();
        if (!$datos) {
            throw ValidationException::withMessages(['activo'=>'Selecciona el cambio que quieres guardar.']);
        }

        $hash = isset($datos['clave']) ? Hash::make($datos['clave']) : null;
        $repositorio->modificar(function (array &$flota) use ($usuario, $datos, $hash): void {
            $indice = array_search($usuario, array_column($flota['accesos'], 'usuario'), true);
            abort_if($indice === false, 404, 'No encontramos esa cuenta.');
            $cuenta = &$flota['accesos'][$indice];
            $activo = $datos['activo'] ?? $cuenta['activo'];
            if ($hash !== null || (bool) $activo !== $cuenta['activo']) {
                $cuenta['activo'] = (bool) $activo;
                $cuenta['hash'] = $hash ?? $cuenta['hash'];
                $cuenta['revision']++;
            }
        });
        return response()->json(['message'=>'Cuenta actualizada.']);
    }

    private function reglasClave(): array
    {
        return ['bail', 'required', 'string', 'min:12', 'max:72', function (string $campo, string $clave, callable $fallar): void {
            if (strlen($clave) > 72 || str_contains($clave, "\0")) {
                $fallar('La contraseña no puede superar 72 bytes ni incluir caracteres nulos.');
            }
        }];
    }
}
