<?php

namespace Tests\Feature;

use Tests\TestCase;

class AccesoTest extends TestCase
{
    public function test_el_resumen_requiere_sesion(): void
    {
        $this->getJson('/api/resumen')->assertUnauthorized();
        $this->getJson('/api/sesion')->assertUnauthorized();
    }

    public function test_credenciales_incorrectas_no_abren_una_sesion(): void
    {
        $this->postJson('/api/login', ['usuario' => 'admin', 'clave' => 'incorrecta'])
            ->assertUnprocessable()->assertJsonPath('message', 'Usuario o contraseña incorrectos. Intenta de nuevo.');
        $this->getJson('/api/resumen')->assertUnauthorized();
    }

    public function test_un_usuario_diferente_no_puede_usar_la_clave_demo(): void
    {
        $this->postJson('/api/login', ['usuario' => 'otro', 'clave' => 'floatmate123'])->assertUnprocessable();
    }

    public function test_los_campos_vacios_se_rechazan_en_espanol(): void
    {
        $this->postJson('/api/login', [])->assertUnprocessable()
            ->assertJsonPath('message', 'Completa el usuario y la contraseña.');
    }

    public function test_el_acceso_permite_consultar_el_resumen_sin_base_de_datos(): void
    {
        $this->postJson('/api/login', ['usuario' => 'admin', 'clave' => 'floatmate123'])->assertOk();
        $this->getJson('/api/sesion')->assertOk()->assertJsonPath('usuario.rol', 'Administrador');
        $this->getJson('/api/resumen')->assertOk()->assertJsonCount(4, 'indicadores')
            ->assertJsonPath('indicadores.0.valor', 5)->assertJsonPath('indicadores.1.valor', 3)
            ->assertJsonPath('indicadores.2.valor', 2)->assertJsonPath('indicadores.3.valor', 1)
            ->assertJsonCount(2, 'viajes')->assertJsonPath('viajes.0.placa', 'TPQ482');
    }

    public function test_salir_invalida_el_acceso_al_resumen(): void
    {
        $this->postJson('/api/login', ['usuario' => 'admin', 'clave' => 'floatmate123'])->assertOk();
        $this->postJson('/api/logout')->assertOk();
        $this->getJson('/api/resumen')->assertUnauthorized();
    }

    public function test_los_intentos_repetidos_se_limitan(): void
    {
        for ($intento = 0; $intento < 5; $intento++) {
            $this->postJson('/api/login', ['usuario' => 'admin', 'clave' => 'incorrecta'])->assertUnprocessable();
        }
        $this->postJson('/api/login', ['usuario' => 'admin', 'clave' => 'floatmate123'])->assertStatus(429);
    }

    public function test_los_modulos_de_operacion_requieren_sesion(): void
    {
        $this->getJson('/api/vehiculos')->assertUnauthorized();
        $this->getJson('/api/viajes')->assertUnauthorized();
        $this->postJson('/api/vehiculos', [])->assertUnauthorized();
        $this->postJson('/api/viajes', [])->assertUnauthorized();
    }
}
