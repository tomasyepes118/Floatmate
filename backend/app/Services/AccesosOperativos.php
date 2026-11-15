<?php

namespace App\Services;

class AccesosOperativos
{
    public function __construct(private RepositorioDemo $repositorio) {}

    public function buscar(string $usuario): ?array
    {
        $flota = $this->repositorio->leer();
        $cuenta = collect($flota['accesos'])->firstWhere('usuario', strtolower($usuario));
        if (!$cuenta || !$cuenta['activo']) return null;

        $perfil = $this->perfil($cuenta, $flota['conductores']);
        return $perfil ? $cuenta + ['perfil'=>$perfil] : null;
    }

    public function perfil(array $cuenta, array $conductores): ?array
    {
        if ($cuenta['rol'] === 'Operador') {
            return ['nombre'=>$cuenta['nombre'], 'rol'=>$cuenta['rol']];
        }
        $conductor = collect($conductores)->firstWhere('id', $cuenta['conductor_id']);
        return $conductor ? ['nombre'=>$conductor['nombre'], 'rol'=>'Conductor', 'conductor_id'=>$conductor['id']] : null;
    }
}
