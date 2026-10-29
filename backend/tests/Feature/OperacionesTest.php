<?php

namespace Tests\Feature;

use App\Services\RepositorioDemo;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class OperacionesTest extends TestCase
{
    private function acceso(): void
    {
        $this->withSession(['usuario_demo'=>config('demo.perfil')]);
    }

    private function vehiculo(array $cambios = []): array
    {
        return array_replace(['placa'=>'ABC123','codigo'=>'BUS-NOR-006','tipo'=>'BUS_URBANO','marca'=>'Chevrolet NPR','modelo'=>2026,'capacidad'=>30,'kilometraje'=>1000,'proximo_mantenimiento'=>6000,'estado'=>'DISPONIBLE'], $cambios);
    }

    private function viaje(array $cambios = []): array
    {
        return array_replace(['ruta_id'=>1,'vehiculo_id'=>5,'conductor_id'=>4,'salida'=>Carbon::now('America/Bogota')->addDays(3)->format('Y-m-d').'T10:00','pasajeros'=>13,'observaciones'=>'Viaje de prueba.'], $cambios);
    }

    public function test_consulta_de_vehiculos_y_catalogos(): void
    {
        $this->acceso();
        $this->getJson('/api/vehiculos')->assertOk()->assertJsonCount(5, 'vehiculos');
        $this->getJson('/api/viajes')->assertOk()->assertJsonCount(4, 'viajes')->assertJsonCount(4, 'rutas')->assertJsonCount(4, 'conductores');
    }

    public function test_registrar_vehiculo_normaliza_y_actualiza_el_resumen(): void
    {
        $this->acceso();
        $this->postJson('/api/vehiculos', $this->vehiculo(['placa'=>' abc123 ','codigo'=>'bus-nor-006']))
            ->assertCreated()->assertJsonPath('vehiculo.placa','ABC123')->assertJsonPath('vehiculo.codigo','BUS-NOR-006');
        $this->getJson('/api/vehiculos')->assertJsonCount(6,'vehiculos');
        $this->getJson('/api/resumen')->assertJsonPath('indicadores.0.valor',6)->assertJsonPath('indicadores.1.valor',4);
    }

    public function test_placa_duplicada_se_rechaza_sin_alterar_el_archivo(): void
    {
        $this->acceso();
        $this->postJson('/api/vehiculos', $this->vehiculo(['placa'=>'TPQ482']))->assertUnprocessable()->assertJsonValidationErrors('placa');
        $this->getJson('/api/vehiculos')->assertJsonCount(5,'vehiculos');
    }

    public function test_codigo_duplicado_se_rechaza(): void
    {
        $this->acceso();
        $this->postJson('/api/vehiculos', $this->vehiculo(['codigo'=>'BUS-NOR-001']))->assertUnprocessable()->assertJsonValidationErrors('codigo');
    }

    public function test_formato_capacidad_kilometraje_y_estado_se_validan_en_servidor(): void
    {
        $this->acceso();
        $this->postJson('/api/vehiculos', $this->vehiculo(['placa'=>'ABC12','capacidad'=>4,'kilometraje'=>-1,'estado'=>'OTRO']))
            ->assertUnprocessable()->assertJsonValidationErrors(['placa','capacidad','kilometraje','estado']);
    }

    public function test_el_mantenimiento_no_puede_quedar_atras_del_kilometraje(): void
    {
        $this->acceso();
        $this->postJson('/api/vehiculos', $this->vehiculo(['proximo_mantenimiento'=>500]))->assertUnprocessable()->assertJsonValidationErrors('proximo_mantenimiento');
    }

    public function test_registrar_viaje_actualiza_la_programacion_y_el_resumen(): void
    {
        $this->acceso();
        $this->postJson('/api/viajes', $this->viaje())->assertCreated()->assertJsonPath('viaje.estado','PROGRAMADO')->assertJsonPath('viaje.id',9005);
        $this->getJson('/api/viajes')->assertJsonCount(5,'viajes');
        $this->getJson('/api/resumen')->assertJsonPath('indicadores.2.valor',3);
    }

    public function test_la_capacidad_se_valida_aunque_se_omita_el_formulario(): void
    {
        $this->acceso();
        $this->postJson('/api/viajes', $this->viaje(['vehiculo_id'=>1,'pasajeros'=>33]))->assertUnprocessable()->assertJsonValidationErrors('pasajeros');
    }

    public function test_fecha_pasada_o_invalida_se_rechaza(): void
    {
        $this->acceso();
        $this->postJson('/api/viajes', $this->viaje(['salida'=>'2020-01-01T10:00']))->assertUnprocessable()->assertJsonValidationErrors('salida');
        $this->postJson('/api/viajes', $this->viaje(['salida'=>'2026-02-30T10:00']))->assertUnprocessable()->assertJsonValidationErrors('salida');
    }

    public function test_vehiculo_no_disponible_y_conductor_no_disponible_se_rechazan(): void
    {
        $this->acceso();
        $this->postJson('/api/viajes', $this->viaje(['vehiculo_id'=>3]))->assertUnprocessable()->assertJsonValidationErrors('vehiculo_id');
        $this->postJson('/api/viajes', $this->viaje(['conductor_id'=>2]))->assertUnprocessable()->assertJsonValidationErrors('conductor_id');
    }

    public function test_identificadores_inexistentes_se_rechazan(): void
    {
        $this->acceso();
        foreach (['ruta_id','vehiculo_id','conductor_id'] as $campo) {
            $this->postJson('/api/viajes', $this->viaje([$campo=>999999]))->assertUnprocessable()->assertJsonValidationErrors($campo);
        }
    }

    public function test_no_permite_solapamiento_del_mismo_bus(): void
    {
        $this->acceso();
        $this->postJson('/api/viajes', $this->viaje())->assertCreated();
        $salida = Carbon::parse($this->viaje()['salida'],'America/Bogota')->addMinutes(20)->format('Y-m-d\TH:i');
        $this->postJson('/api/viajes', $this->viaje(['conductor_id'=>3,'salida'=>$salida]))->assertUnprocessable()->assertJsonValidationErrors('salida');
    }

    public function test_no_permite_solapamiento_del_mismo_conductor_en_otro_bus(): void
    {
        $this->acceso();
        $this->postJson('/api/viajes', $this->viaje())->assertCreated();
        $this->postJson('/api/viajes', $this->viaje(['vehiculo_id'=>1]))->assertUnprocessable()->assertJsonValidationErrors('salida');
    }

    public function test_permite_programar_justo_despues_de_finalizar_el_intervalo(): void
    {
        $this->acceso();
        $this->postJson('/api/viajes', $this->viaje())->assertCreated();
        $salida = Carbon::parse($this->viaje()['salida'],'America/Bogota')->addMinutes(60)->format('Y-m-d\TH:i');
        $this->postJson('/api/viajes', $this->viaje(['salida'=>$salida]))->assertCreated();
    }

    public function test_ruta_inactiva_licencia_y_mantenimiento_se_revisan(): void
    {
        $this->acceso();
        app(RepositorioDemo::class)->modificar(function (array &$datos): void { $datos['rutas'][0]['activa']=false; });
        $this->postJson('/api/viajes', $this->viaje())->assertUnprocessable()->assertJsonValidationErrors('ruta_id');
        app(RepositorioDemo::class)->modificar(function (array &$datos): void { $datos['rutas'][0]['activa']=true; $datos['conductores'][3]['licencia_vence']='2020-01-01'; });
        $this->postJson('/api/viajes', $this->viaje())->assertUnprocessable()->assertJsonValidationErrors('conductor_id');
        app(RepositorioDemo::class)->modificar(function (array &$datos): void { $datos['conductores'][3]['licencia_vence']='2035-01-01'; $datos['vehiculos'][4]['proximo_mantenimiento']=31710; });
        $this->postJson('/api/viajes', $this->viaje())->assertUnprocessable()->assertJsonValidationErrors('vehiculo_id');
    }

    public function test_los_datos_persisten_al_cerrar_y_volver_a_ingresar(): void
    {
        $this->acceso();
        $this->postJson('/api/vehiculos', $this->vehiculo())->assertCreated();
        $this->postJson('/api/logout')->assertOk();
        $this->postJson('/api/login',['usuario'=>'admin','clave'=>'floatmate123'])->assertOk();
        $this->getJson('/api/vehiculos')->assertJsonCount(6,'vehiculos');
    }

    public function test_json_danado_no_se_reemplaza_por_datos_iniciales(): void
    {
        $this->acceso();
        app(RepositorioDemo::class)->leer();
        $archivo = config('demo.directorio').'/flota.json';
        file_put_contents($archivo,'contenido inválido');
        $this->getJson('/api/vehiculos')->assertStatus(500);
        $this->assertSame('contenido inválido',file_get_contents($archivo));
    }

    public function test_los_registros_no_consumen_el_limite_de_intentos_del_login(): void
    {
        $this->acceso();
        for ($intento=0; $intento<6; $intento++) {
            $this->postJson('/api/vehiculos', $this->vehiculo(['placa'=>'TPQ482']))->assertUnprocessable();
        }
        $this->postJson('/api/logout')->assertOk();
        $this->postJson('/api/login',['usuario'=>'admin','clave'=>'floatmate123'])->assertOk();
        $this->getJson('/api/resumen')->assertOk();
    }
}
