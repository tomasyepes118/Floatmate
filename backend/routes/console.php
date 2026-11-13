<?php

use App\Services\RepositorioDemo;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Str;

Artisan::command('flota:importar {archivo}', function (RepositorioDemo $repositorio): int {
    try {
        if ($repositorio->importarPostgres($this->argument('archivo'))) {
            $this->info('Datos de FloatMate importados.');
            return 0;
        }
        $this->error('La base ya tiene datos de FloatMate.');
    } catch (Throwable $error) {
        report($error);
        $this->error('No se pudo importar. Revisa el archivo, la conexión y la migración.');
    }
    return 1;
})->purpose('Importa una copia JSON a una base PostgreSQL vacía.');

Artisan::command('flota:preparar-demo {--vacia : Comenzar con todos los registros vacíos}', function (RepositorioDemo $repositorio): int {
    $vacia = $this->option('vacia');
    $directorio = storage_path('app/ensayos/'.($vacia ? 'recorrido-' : 'pitch-').Str::uuid());
    config(['demo.almacen'=>'json', 'demo.directorio'=>$directorio]);
    $repositorio->modificar(function (array &$datos) use ($vacia): void {
        if ($vacia) {
            $datos = array_fill_keys(array_keys($datos), []);
            return;
        }
        // V-9002 permite mostrar el rechazo y V-9001 llega al umbral después de 42 km.
        $datos['vehiculos'][0]['kilometraje'] = 34958;
        // KPT641 permite comparar un bus al que solo le quedan 20 km.
        $datos['vehiculos'][4]['kilometraje'] = 34980;
        $datos['vehiculos'][4]['proximo_mantenimiento'] = 35000;
    });
    $this->line($directorio);
    return 0;
})->purpose('Prepara una copia aislada para el pitch o para empezar con la flota vacía.');
