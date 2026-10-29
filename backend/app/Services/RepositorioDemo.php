<?php

namespace App\Services;

use Closure;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\File;
use RuntimeException;

/** Archivo local de demostración. Las escrituras se serializan y reemplazan de forma atómica. */
class RepositorioDemo
{
    public function leer(): array
    {
        return $this->modificar(fn (array &$datos) => $datos);
    }

    public function modificar(Closure $operacion): mixed
    {
        $directorio = config('demo.directorio');
        File::ensureDirectoryExists($directorio);
        $bloqueo = fopen($directorio.'/flota.lock', 'c');
        if (!$bloqueo || !flock($bloqueo, LOCK_EX)) {
            if ($bloqueo) fclose($bloqueo);
            throw new RuntimeException('No se pudo abrir el archivo de demostración.');
        }
        try {
            $archivo = $directorio.'/flota.json';
            $existia = is_file($archivo);
            $datos = $existia ? json_decode(File::get($archivo), true, 512, JSON_THROW_ON_ERROR) : $this->iniciales();
            if (!isset($datos['vehiculos'], $datos['viajes'], $datos['rutas'], $datos['conductores'])) {
                throw new RuntimeException('El archivo de demostración no tiene la estructura esperada.');
            }
            $antes = $datos;
            $resultado = $operacion($datos);
            if (!$existia || $antes !== $datos) {
                File::replace($archivo, json_encode($datos, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR));
            }
            return $resultado;
        } finally {
            flock($bloqueo, LOCK_UN);
            fclose($bloqueo);
        }
    }

    private function iniciales(): array
    {
        $manana = Carbon::tomorrow('America/Bogota');
        return [
            'vehiculos' => [
                ['id'=>1,'placa'=>'TPQ482','codigo'=>'BUS-NOR-001','tipo'=>'BUS_URBANO','marca'=>'Chevrolet NPR','modelo'=>2024,'capacidad'=>32,'kilometraje'=>28450,'proximo_mantenimiento'=>35000,'estado'=>'DISPONIBLE'],
                ['id'=>2,'placa'=>'SXY916','codigo'=>'BUS-NOR-002','tipo'=>'BUS_INTERMUNICIPAL','marca'=>'Mercedes-Benz LO','modelo'=>2023,'capacidad'=>40,'kilometraje'=>61400,'proximo_mantenimiento'=>65000,'estado'=>'EN_RUTA'],
                ['id'=>3,'placa'=>'WLM305','codigo'=>'BUS-NOR-003','tipo'=>'BUS_INTERMUNICIPAL','marca'=>'Hino FC','modelo'=>2022,'capacidad'=>35,'kilometraje'=>89300,'proximo_mantenimiento'=>90000,'estado'=>'MANTENIMIENTO'],
                ['id'=>4,'placa'=>'JRC728','codigo'=>'BUS-NOR-004','tipo'=>'BUS_URBANO','marca'=>'Chevrolet NQR','modelo'=>2025,'capacidad'=>38,'kilometraje'=>12300,'proximo_mantenimiento'=>18000,'estado'=>'DISPONIBLE'],
                ['id'=>5,'placa'=>'KPT641','codigo'=>'BUS-NOR-005','tipo'=>'BUS_INTERMUNICIPAL','marca'=>'Mercedes-Benz LO','modelo'=>2024,'capacidad'=>40,'kilometraje'=>31700,'proximo_mantenimiento'=>36000,'estado'=>'DISPONIBLE'],
            ],
            'conductores' => [
                ['id'=>1,'nombre'=>'Carlos Restrepo','estado'=>'DISPONIBLE','licencia_vence'=>'2027-10-18'],
                ['id'=>2,'nombre'=>'Laura Gómez','estado'=>'EN_VIAJE','licencia_vence'=>'2028-05-20'],
                ['id'=>3,'nombre'=>'Andrés Ruiz','estado'=>'DISPONIBLE','licencia_vence'=>'2028-08-15'],
                ['id'=>4,'nombre'=>'Daniel López','estado'=>'DISPONIBLE','licencia_vence'=>'2028-11-30'],
            ],
            'rutas' => [
                ['id'=>1,'codigo'=>'R-NOR-001','origen'=>'Medellín','destino'=>'Rionegro','distancia'=>42,'duracion'=>60,'activa'=>true],
                ['id'=>2,'codigo'=>'R-NOR-002','origen'=>'Bello','destino'=>'Medellín','distancia'=>15,'duracion'=>40,'activa'=>true],
                ['id'=>3,'codigo'=>'R-NOR-003','origen'=>'Medellín','destino'=>'Guatapé','distancia'=>80,'duracion'=>120,'activa'=>true],
                ['id'=>4,'codigo'=>'R-NOR-004','origen'=>'Rionegro','destino'=>'Medellín','distancia'=>42,'duracion'=>60,'activa'=>true],
            ],
            'viajes' => [
                ['id'=>9001,'ruta_id'=>1,'vehiculo_id'=>1,'conductor_id'=>1,'salida'=>$manana->format('Y-m-d').'T07:30','pasajeros'=>20,'observaciones'=>'','estado'=>'PROGRAMADO'],
                ['id'=>9002,'ruta_id'=>3,'vehiculo_id'=>4,'conductor_id'=>3,'salida'=>$manana->copy()->addDay()->format('Y-m-d').'T08:00','pasajeros'=>25,'observaciones'=>'','estado'=>'PROGRAMADO'],
                ['id'=>9003,'ruta_id'=>2,'vehiculo_id'=>2,'conductor_id'=>2,'salida'=>Carbon::yesterday('America/Bogota')->format('Y-m-d').'T10:00','pasajeros'=>24,'observaciones'=>'Ejemplo de viaje en curso.','estado'=>'EN_CURSO'],
                ['id'=>9004,'ruta_id'=>4,'vehiculo_id'=>5,'conductor_id'=>4,'salida'=>Carbon::yesterday('America/Bogota')->format('Y-m-d').'T17:00','pasajeros'=>18,'observaciones'=>'','estado'=>'FINALIZADO'],
            ],
        ];
    }
}
