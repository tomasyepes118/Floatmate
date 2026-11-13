<?php

namespace Tests\Feature;

use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AvanceFinalTest extends TestCase
{
    private function ingresar(string $usuario = 'admin', string $clave = 'floatmate123'): void
    {
        $this->postJson('/api/login', compact('usuario', 'clave'))->assertOk();
    }

    public function test_los_roles_se_aplican_en_el_servidor(): void
    {
        $this->getJson('/api/registros')->assertUnauthorized();
        $this->getJson('/api/registros/combustible/csv')->assertUnauthorized();
        $this->getJson('/api/catalogos')->assertUnauthorized();
        config(['demo.cuentas.operador.hash'=>Hash::make('operador-prueba'), 'demo.cuentas.consulta.hash'=>Hash::make('consulta-prueba')]);
        $this->ingresar('consulta', 'consulta-prueba');
        $this->getJson('/api/resumen')->assertOk()->assertJsonPath('usuario.rol', 'Consulta');
        $this->get('/api/registros/combustible/csv')->assertOk();
        $this->getJson('/api/viajes')->assertForbidden();
        $this->postJson('/api/registros/combustible', [])->assertForbidden();
        $this->postJson('/api/logout')->assertOk();
        $this->ingresar('operador', 'operador-prueba');
        $this->getJson('/api/viajes')->assertOk();
        $this->postJson('/api/viajes', [])->assertUnprocessable();
        $this->postJson('/api/vehiculos', [])->assertForbidden();
        $this->postJson('/api/catalogos/rutas', [])->assertForbidden();
    }

    public function test_rutas_y_conductores_se_guardan_y_respetan_viajes_vigentes(): void
    {
        $this->ingresar();
        $ruta = ['codigo'=>'r-05','origen'=>'Bello','destino'=>'Envigado','distancia'=>27.5,'duracion'=>50,'activa'=>'1'];
        $id = $this->postJson('/api/catalogos/rutas', $ruta)->assertCreated()->assertJsonPath('item.codigo', 'R-05')->json('item.id');
        $this->postJson('/api/catalogos/rutas', $ruta)->assertUnprocessable()->assertJsonValidationErrors('codigo');
        $this->putJson("/api/catalogos/rutas/$id", array_replace($ruta, ['activa'=>'0', 'revision'=>0]))->assertOk()->assertJsonPath('item.activa', false);
        $this->putJson("/api/catalogos/rutas/$id", $ruta + ['revision'=>0])->assertConflict();
        $this->putJson('/api/catalogos/rutas/1', ['codigo'=>'R-NOR-001','origen'=>'Medellín','destino'=>'Rionegro','distancia'=>42,'duracion'=>60,'activa'=>'0','revision'=>0])
            ->assertUnprocessable()->assertJsonValidationErrors('activa');
        $this->postJson('/api/catalogos/conductores', ['nombre'=>'Conductora de prueba','licencia_vence'=>'2029-01-01','estado'=>'DISPONIBLE'])->assertCreated();
        $this->putJson('/api/catalogos/conductores/1', ['nombre'=>'Carlos Restrepo','licencia_vence'=>'2027-10-18','estado'=>'INACTIVO','revision'=>0])
            ->assertUnprocessable()->assertJsonValidationErrors('estado');
        $this->getJson('/api/viajes')->assertOk()->assertJsonCount(5, 'rutas')->assertJsonCount(5, 'conductores');
    }

    public function test_registros_actualizan_inventario_resumen_y_csv(): void
    {
        $this->ingresar();
        $fecha = Carbon::today('America/Bogota')->toDateString();
        $base = ['fecha'=>$fecha, 'detalle'=>'Servicio de prueba'];
        $combustible = ['vehiculo_id'=>1, 'litros'=>'20.25', 'precio_litro'=>10000, 'detalle'=>'=Registro'];
        $this->postJson('/api/registros/combustible', $combustible + $base)->assertCreated()->assertJsonPath('item.total', 202500);
        $this->postJson('/api/registros/combustible', array_replace($combustible, ['litros'=>0]) + $base)->assertUnprocessable()->assertJsonValidationErrors('litros');
        $csv = $this->get('/api/registros/combustible/csv')->assertOk()->assertDownload('floatmate-combustible.csv')->streamedContent();
        $this->assertStringContainsString('202500', $csv);
        $this->assertStringContainsString("'=Registro", $csv);
        $this->postJson('/api/registros/mantenimientos', ['vehiculo_id'=>2,'kilometraje'=>61400,'proximo_mantenimiento'=>70000] + $base)
            ->assertUnprocessable()->assertJsonValidationErrors('vehiculo_id');
        $this->postJson('/api/registros/mantenimientos', ['vehiculo_id'=>3,'kilometraje'=>89300,'proximo_mantenimiento'=>95000] + $base)->assertCreated();
        $this->getJson('/api/vehiculos')->assertOk()->assertJsonPath('vehiculos.2.estado', 'DISPONIBLE')->assertJsonPath('vehiculos.2.proximo_mantenimiento', 95000);
        $this->postJson('/api/registros/incidentes', ['viaje_id'=>9001, 'gravedad'=>'BAJA'] + $base)->assertUnprocessable()->assertJsonValidationErrors('viaje_id');
        $this->postJson('/api/registros/incidentes', ['viaje_id'=>9004, 'gravedad'=>'BAJA'] + $base)->assertCreated()->assertJsonPath('item.vehiculo_id', 5);
        $this->getJson('/api/resumen')->assertOk()->assertJsonPath('actividad.costo', 202500)->assertJsonPath('actividad.mantenimientos', 1)->assertJsonPath('actividad.incidentes', 1);
        $this->getJson('/api/registros')->assertOk()->assertJsonPath('mantenimientos.0.placa', 'WLM305');
    }

    public function test_conserva_datos_del_tercer_avance_al_agregar_colecciones(): void
    {
        $archivo = config('demo.directorio').'/flota.json';
        $this->ingresar();
        $this->getJson('/api/viajes')->assertOk();
        $anterior = json_decode(File::get($archivo), true, 512, JSON_THROW_ON_ERROR);
        unset($anterior['combustible'], $anterior['mantenimientos'], $anterior['incidentes']);
        $anterior['vehiculos'][0]['marca'] = 'Registro existente';
        File::put($archivo, json_encode($anterior, JSON_THROW_ON_ERROR));
        $this->getJson('/api/registros')->assertOk()->assertJsonCount(0, 'combustible')->assertJsonPath('vehiculos.0.marca', 'Registro existente');
        $this->assertCount(4, json_decode(File::get($archivo), true, 512, JSON_THROW_ON_ERROR)['viajes']);
    }
}
