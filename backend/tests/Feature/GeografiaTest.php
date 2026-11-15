<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class GeografiaTest extends TestCase
{
    public function test_el_catalogo_incluye_los_125_municipios_con_codigos_unicos(): void
    {
        $this->getJson('/api/municipios/antioquia')->assertUnauthorized();
        $this->withSession(['usuario_demo'=>config('demo.perfil')]);
        $municipios = $this->getJson('/api/municipios/antioquia')->assertOk()
            ->assertJsonCount(125, 'municipios')
            ->assertJsonFragment(['codigo'=>'05001','nombre'=>'Medellín'])
            ->json('municipios');
        $this->assertCount(125, array_unique(array_column($municipios, 'codigo')));
        $this->getJson('/api/catalogos')->assertJsonCount(125, 'municipios');
    }

    public function test_estima_el_trayecto_con_coordenadas_oficiales_y_reutiliza_el_resultado(): void
    {
        $this->withSession(['usuario_demo'=>config('demo.perfil')]);
        Http::preventStrayRequests();
        Http::fake(['*/route/v1/driving/-75.581775,6.246631;-75.377316,6.147148?*'=>Http::response([
            'code'=>'Ok','routes'=>[['distance'=>37832.1,'duration'=>3050.1]],
        ])]);
        $payload = ['origen'=>'05001', 'destino'=>'05615'];
        $this->postJson('/api/catalogos/rutas/estimar', $payload)
            ->assertOk()->assertExactJson(['distancia'=>37.83, 'duracion'=>51]);
        $this->postJson('/api/catalogos/rutas/estimar', $payload)
            ->assertOk()->assertExactJson(['distancia'=>37.83, 'duracion'=>51]);
        $this->postJson('/api/catalogos/rutas/estimar', ['origen'=>'05001','destino'=>'05001'])
            ->assertUnprocessable()->assertJsonValidationErrors('destino');
        Http::assertSentCount(1);
    }

    public function test_distingue_un_trayecto_sin_conexion_vial(): void
    {
        $this->withSession(['usuario_demo'=>config('demo.perfil')]);
        Http::fake(['*'=>Http::response(['code'=>'NoRoute'], 400)]);
        $this->postJson('/api/catalogos/rutas/estimar', ['origen'=>'05001','destino'=>'05615'])
            ->assertUnprocessable()->assertJsonPath('message', 'El mapa no encontró un trayecto por carretera entre estos puntos. Si conoces el recorrido, puedes ingresar los valores manualmente.');
    }
}
