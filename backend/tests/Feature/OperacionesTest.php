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

    public function test_editar_y_retirar_vehiculo_conserva_su_identidad_y_detecta_cambios_concurrentes(): void
    {
        $this->acceso();
        $edicion = $this->vehiculo([
            'placa'=>'KPT641', 'codigo'=>'BUS-NOR-005', 'kilometraje'=>31700,
            'proximo_mantenimiento'=>36000, 'estado'=>'FUERA_SERVICIO', 'revision'=>0,
        ]);
        $this->putJson('/api/vehiculos/5', array_replace($edicion, ['placa'=>'TPQ482']))
            ->assertUnprocessable()->assertJsonValidationErrors('placa');
        $this->putJson('/api/vehiculos/5', $edicion)->assertOk()
            ->assertJsonPath('vehiculo.id', 5)->assertJsonPath('vehiculo.revision', 1);
        $this->putJson('/api/vehiculos/5', $edicion)->assertConflict();
        $this->postJson('/api/viajes', $this->viaje())->assertUnprocessable()->assertJsonValidationErrors('vehiculo_id');
        $this->getJson('/api/resumen')->assertJsonPath('indicadores.0.valor', 5)->assertJsonPath('indicadores.1.valor', 2);
        $this->getJson('/api/viajes')->assertJsonPath('viajes.3.vehiculo_id', 5);
    }

    public function test_editar_vehiculo_protege_las_asignaciones_vigentes(): void
    {
        $this->acceso();
        $vehiculo = $this->vehiculo([
            'placa'=>'TPQ482', 'codigo'=>'BUS-NOR-001', 'kilometraje'=>28450,
            'proximo_mantenimiento'=>35000, 'revision'=>0,
        ]);
        foreach (['estado'=>'FUERA_SERVICIO', 'capacidad'=>19, 'kilometraje'=>28449, 'proximo_mantenimiento'=>28480] as $campo=>$valor) {
            $this->putJson('/api/vehiculos/1', array_replace($vehiculo, [$campo=>$valor]))
                ->assertUnprocessable()->assertJsonValidationErrors($campo);
        }
        $this->putJson('/api/vehiculos/2', array_replace($vehiculo, [
            'placa'=>'SXY916', 'codigo'=>'BUS-NOR-002', 'kilometraje'=>61400, 'proximo_mantenimiento'=>65000,
        ]))->assertUnprocessable()->assertJsonValidationErrors('estado');
        $this->putJson('/api/vehiculos/1', array_replace($vehiculo, ['marca'=>'Chevrolet NPR actualizado']))
            ->assertOk()->assertJsonPath('vehiculo.marca', 'Chevrolet NPR actualizado');
    }

    public function test_inicio_y_llegada_actualizan_vehiculo_conductor_y_resumen(): void
    {
        $this->acceso();
        $this->patchJson('/api/viajes/9001/estado', ['estado'=>'EN_CURSO'])
            ->assertUnprocessable()->assertJsonValidationErrors('estado');
        $this->postJson('/api/viajes/9001/control', ['numero_ticket'=>'sal-01', 'alcoholemia_mg_l'=>'0.000'])
            ->assertCreated()->assertJsonPath('viaje.control_salida.resultado', 'APROBADO');
        $this->patchJson('/api/viajes/9001/estado', ['estado'=>'EN_CURSO'])
            ->assertOk()->assertJsonPath('viaje.estado', 'EN_CURSO')->assertJsonStructure(['viaje'=>['salida_real']]);
        $this->getJson('/api/viajes')->assertJsonPath('vehiculos.0.estado', 'EN_RUTA')
            ->assertJsonPath('conductores.0.estado', 'EN_VIAJE');
        $this->getJson('/api/resumen')->assertJsonPath('indicadores.2.valor', 1);
        $this->patchJson('/api/viajes/9001/estado', ['estado'=>'CANCELADO'])
            ->assertUnprocessable()->assertJsonValidationErrors('estado');
        $this->patchJson('/api/viajes/9001/estado', ['estado'=>'FINALIZADO', 'kilometraje_llegada'=>28449])
            ->assertUnprocessable()->assertJsonValidationErrors('kilometraje_llegada');
        $this->patchJson('/api/viajes/9001/estado', ['estado'=>'FINALIZADO', 'kilometraje_llegada'=>35001])
            ->assertOk()->assertJsonPath('viaje.estado', 'FINALIZADO')->assertJsonStructure(['viaje'=>['salida_real', 'llegada_real']]);
        $this->getJson('/api/viajes')->assertJsonPath('vehiculos.0.estado', 'MANTENIMIENTO')
            ->assertJsonPath('vehiculos.0.kilometraje', 35001)->assertJsonPath('conductores.0.estado', 'DISPONIBLE');
        $this->patchJson('/api/viajes/9001/estado', ['estado'=>'FINALIZADO', 'kilometraje_llegada'=>35002])
            ->assertUnprocessable()->assertJsonValidationErrors('estado');
    }

    public function test_control_rechazado_se_conserva_y_cancelar_libera_el_horario(): void
    {
        $this->acceso();
        $this->postJson('/api/viajes/9001/control', ['numero_ticket'=>'SAL-02', 'alcoholemia_mg_l'=>'0.0001'])
            ->assertUnprocessable()->assertJsonValidationErrors('alcoholemia_mg_l');
        $this->postJson('/api/viajes/9001/control', ['numero_ticket'=>'SAL-02', 'alcoholemia_mg_l'=>'0.015'])
            ->assertCreated()->assertJsonPath('viaje.control_salida.resultado', 'RECHAZADO');
        $this->postJson('/api/viajes/9001/control', ['numero_ticket'=>'SAL-03', 'alcoholemia_mg_l'=>0])
            ->assertUnprocessable()->assertJsonValidationErrors('estado');
        $this->postJson('/api/viajes/9002/control', ['numero_ticket'=>'sal-02', 'alcoholemia_mg_l'=>0])
            ->assertUnprocessable()->assertJsonValidationErrors('numero_ticket');
        $this->patchJson('/api/viajes/9001/estado', ['estado'=>'EN_CURSO'])
            ->assertUnprocessable()->assertJsonValidationErrors('estado');
        $anterior = $this->getJson('/api/viajes')->json('viajes.0');
        $this->patchJson('/api/viajes/9001/estado', ['estado'=>'CANCELADO'])->assertOk()
            ->assertJsonPath('viaje.estado', 'CANCELADO')->assertJsonPath('viaje.control_salida.resultado', 'RECHAZADO');
        $this->postJson('/api/viajes', $anterior)->assertCreated()->assertJsonPath('viaje.estado', 'PROGRAMADO');
    }

    public function test_viaje_en_curso_del_segundo_avance_se_puede_finalizar(): void
    {
        $this->acceso();
        $this->patchJson('/api/viajes/9003/estado', ['estado'=>'FINALIZADO', 'kilometraje_llegada'=>61415])
            ->assertOk()->assertJsonPath('viaje.estado', 'FINALIZADO')->assertJsonStructure(['viaje'=>['llegada_real']]);
        $this->getJson('/api/viajes')->assertJsonPath('vehiculos.1.estado', 'DISPONIBLE')
            ->assertJsonPath('conductores.1.estado', 'DISPONIBLE');
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

    public function test_la_revision_explica_el_limite_y_sugiere_un_bus_sin_reservarlo(): void
    {
        $this->acceso();
        app(RepositorioDemo::class)->modificar(function (array &$datos): void {
            $datos['vehiculos'][0]['kilometraje'] = 34958;
            $datos['vehiculos'][4]['kilometraje'] = 34980;
            $datos['vehiculos'][4]['proximo_mantenimiento'] = 35000;
        });
        $viaje = $this->viaje();
        $this->postJson('/api/viajes/elegibilidad', $viaje)->assertOk()
            ->assertJsonPath('problemas.0.campo', 'vehiculo_id')
            ->assertJsonPath('kilometraje.disponible', 20)
            ->assertJsonPath('kilometraje.llegada', 35022)
            ->assertJsonFragment(['placa'=>'TPQ482']);
        $this->getJson('/api/viajes')->assertJsonCount(4, 'viajes');
        $this->postJson('/api/viajes', $viaje)->assertUnprocessable()->assertJsonValidationErrors('vehiculo_id');
        $alternativa = array_replace($viaje, ['vehiculo_id'=>1]);
        $this->postJson('/api/viajes/elegibilidad', $alternativa)->assertOk()
            ->assertJsonCount(0, 'problemas')->assertJsonPath('kilometraje.llegada', 35000);
        $this->postJson('/api/viajes', $alternativa)->assertCreated();
        $this->postJson('/api/viajes/elegibilidad', $alternativa)->assertOk()
            ->assertJsonCount(2, 'problemas')->assertJsonCount(0, 'alternativas');
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
