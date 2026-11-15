<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\File;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

class AccesosOperativosTest extends TestCase
{
    private const CLAVE = 'clave-fiable-de-ensayo';

    private function administrar(): void
    {
        $this->withSession(['usuario_demo'=>config('demo.perfil'), 'acceso_operativo'=>null]);
    }

    private function crearConductor(string $usuario, int $id): void
    {
        $this->postJson('/api/accesos', [
            'usuario'=>$usuario, 'rol'=>'Conductor', 'conductor_id'=>$id, 'clave'=>self::CLAVE,
        ])->assertCreated();
    }

    private function ingresar(string $usuario, string $clave = self::CLAVE): TestResponse
    {
        return $this->postJson('/api/login', compact('usuario', 'clave'));
    }

    public function test_el_administrador_crea_accesos_y_el_operador_tiene_permisos_de_despacho(): void
    {
        $this->getJson('/api/accesos')->assertUnauthorized();
        $this->administrar();
        $datos = ['usuario'=>'Despacho.Mañana', 'rol'=>'Operador', 'nombre'=>'Despacho de la mañana', 'clave'=>self::CLAVE];
        $this->postJson('/api/accesos', $datos)->assertUnprocessable()->assertJsonValidationErrors('usuario');
        $datos['usuario'] = 'Despacho.1';
        $this->postJson('/api/accesos', $datos)->assertCreated();
        $this->postJson('/api/accesos', array_replace($datos, ['usuario'=>'despacho.1']))->assertUnprocessable()->assertJsonValidationErrors('usuario');
        $this->postJson('/api/accesos', array_replace($datos, ['usuario'=>'admin']))->assertUnprocessable()->assertJsonValidationErrors('usuario');
        $this->postJson('/api/accesos', array_replace($datos, ['usuario'=>'otra', 'clave'=>str_repeat('🚌', 20)]))->assertUnprocessable()->assertJsonValidationErrors('clave');
        $this->crearConductor('carlos', 1);
        $this->postJson('/api/accesos', ['usuario'=>'duplicado','rol'=>'Conductor','conductor_id'=>1,'clave'=>self::CLAVE])
            ->assertUnprocessable()->assertJsonValidationErrors('conductor_id');
        $this->postJson('/api/accesos', ['usuario'=>'inexistente','rol'=>'Conductor','conductor_id'=>99,'clave'=>self::CLAVE])
            ->assertUnprocessable()->assertJsonValidationErrors('conductor_id');
        $this->getJson('/api/accesos')->assertOk()->assertJsonCount(2, 'accesos')->assertJsonMissingPath('accesos.0.hash');
        $this->assertStringNotContainsString(self::CLAVE, File::get(config('demo.directorio').'/flota.json'));

        $this->ingresar('DESPACHO.1')->assertOk()->assertJsonPath('usuario.rol', 'Operador');
        $this->getJson('/api/resumen')->assertOk();
        $this->getJson('/api/viajes')->assertOk();
        $this->getJson('/api/registros')->assertOk();
        $this->postJson('/api/viajes/9001/control', ['numero_ticket'=>'OPERADOR-9001', 'alcoholemia_mg_l'=>0])->assertCreated();
        $this->getJson('/api/accesos')->assertForbidden();
        $this->postJson('/api/accesos', $datos)->assertForbidden();
        $this->getJson('/api/mis-viajes')->assertForbidden();
        $this->postJson('/api/vehiculos', [])->assertForbidden();
    }

    public function test_el_conductor_solo_ve_y_confirma_sus_asignaciones(): void
    {
        $this->administrar();
        $this->crearConductor('carlos', 1);
        $this->ingresar('carlos')->assertOk()->assertJsonPath('usuario.rol', 'Conductor');
        $this->getJson('/api/mis-viajes')->assertOk()->assertJsonCount(1, 'viajes')
            ->assertJsonPath('viajes.0.id', 9001)->assertJsonPath('viajes.0.placa', 'TPQ482');
        foreach (['resumen','viajes','vehiculos','registros','registros/combustible/csv','catalogos','accesos'] as $ruta) {
            $this->getJson('/api/'.$ruta)->assertForbidden();
        }
        $this->postJson('/api/viajes/9001/control', ['numero_ticket'=>'FUERA-DE-ROL', 'alcoholemia_mg_l'=>0])->assertForbidden();
        $this->patchJson('/api/viajes/9001/estado', ['estado'=>'EN_CURSO'])->assertForbidden();
        $this->postJson('/api/mis-viajes/9002/confirmar', [])->assertNotFound();
        $this->patchJson('/api/mis-viajes/9003/llegada', ['kilometraje_llegada'=>65000])->assertNotFound();
        $this->postJson('/api/mis-viajes/9003/incidentes', ['gravedad'=>'BAJA','detalle'=>'Otro conductor'])->assertNotFound();
        $this->patchJson('/api/mis-viajes/9001/llegada', ['kilometraje_llegada'=>35000, 'estado'=>'EN_CURSO'])->assertUnprocessable();
        $this->postJson('/api/mis-viajes/9001/incidentes', ['gravedad'=>'BAJA','detalle'=>'Todavía programado'])->assertUnprocessable();

        $confirmado = $this->postJson('/api/mis-viajes/9001/confirmar', [])->assertOk()->json('confirmado_en');
        $this->postJson('/api/mis-viajes/9001/confirmar', [])->assertOk()->assertJsonPath('confirmado_en', $confirmado);
        $this->getJson('/api/mis-viajes')->assertOk()->assertJsonPath('viajes.0.confirmado_en', $confirmado);
        $this->administrar();
        $this->getJson('/api/viajes')->assertOk()->assertJsonPath('viajes.0.confirmado_por_conductor_en', $confirmado);
    }

    public function test_el_conductor_reporta_la_llegada_e_incidentes_del_viaje_propio(): void
    {
        $this->administrar();
        $this->crearConductor('laura', 2);
        $this->ingresar('laura')->assertOk();
        $this->postJson('/api/mis-viajes/9003/incidentes', [
            'gravedad'=>'MEDIA', 'detalle'=>'Demora informada por Laura', 'viaje_id'=>9004,
        ])->assertCreated()->assertJsonPath('item.viaje_id', 9003)->assertJsonPath('item.registrado_por', 'Laura Gómez');
        $this->patchJson('/api/mis-viajes/9003/llegada', ['kilometraje_llegada'=>1])->assertUnprocessable()->assertJsonValidationErrors('kilometraje_llegada');
        $this->patchJson('/api/mis-viajes/9003/llegada', ['kilometraje_llegada'=>65000])->assertOk()->assertJsonMissingPath('viaje');
        $this->getJson('/api/mis-viajes')->assertOk()->assertJsonPath('viajes.0.estado', 'FINALIZADO')->assertJsonPath('viajes.0.kilometraje_llegada', 65000);
        $this->patchJson('/api/mis-viajes/9003/llegada', ['kilometraje_llegada'=>65050])->assertUnprocessable();
        $this->administrar();
        $this->getJson('/api/vehiculos')->assertOk()->assertJsonPath('vehiculos.1.estado', 'MANTENIMIENTO');
        $this->getJson('/api/viajes')->assertOk()->assertJsonPath('conductores.1.estado', 'DISPONIBLE');
        $this->getJson('/api/registros')->assertOk()->assertJsonPath('incidentes.0.detalle', 'Demora informada por Laura');
    }

    public function test_desactivar_o_cambiar_clave_revoca_las_sesiones_anteriores(): void
    {
        $this->administrar();
        $this->crearConductor('carlos', 1);
        $perfil = $this->ingresar('carlos')->assertOk()->json('usuario');
        $this->administrar();
        $this->patchJson('/api/accesos/carlos', ['activo'=>false])->assertOk();
        $this->withSession(['usuario_demo'=>$perfil, 'acceso_operativo'=>['usuario'=>'carlos','revision'=>0]]);
        $this->getJson('/api/mis-viajes')->assertUnauthorized();
        $this->ingresar('carlos')->assertUnprocessable();
        $this->administrar();
        $this->patchJson('/api/accesos/carlos', ['activo'=>true])->assertOk();
        $this->ingresar('carlos')->assertOk();
        $this->administrar();
        $this->patchJson('/api/accesos/carlos', ['clave'=>'nueva-clave-de-ensayo'])->assertOk();
        $this->withSession(['usuario_demo'=>$perfil, 'acceso_operativo'=>['usuario'=>'carlos','revision'=>2]]);
        $this->getJson('/api/mis-viajes')->assertUnauthorized();
        $this->ingresar('carlos')->assertUnprocessable();
        $this->ingresar('carlos', 'nueva-clave-de-ensayo')->assertOk();
    }
}
