<?php

namespace Tests\Feature;

use App\Services\PrecioAcpmCreg;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class PrecioAcpmTest extends TestCase
{
    private const RUTA = '/api/registros/combustible/acpm';

    public function test_consulta_la_referencia_vigente_y_convierte_el_galon_a_litros(): void
    {
        $this->travelTo(Carbon::parse('2026-11-15 23:58', 'America/Bogota'));
        Http::fake([PrecioAcpmCreg::FUENTE=>Http::response($this->publicacion('1 de noviembre del 2026', '11.641'))]);

        $this->getJson(self::RUTA)->assertUnauthorized();
        $this->withSession(['usuario_demo'=>['nombre'=>'Consulta', 'rol'=>'Consulta']])->getJson(self::RUTA)->assertForbidden();
        $this->withSession(['usuario_demo'=>config('demo.perfil')]);
        $this->getJson(self::RUTA)->assertOk()->assertExactJson([
            'combustible'=>'ACPM', 'ciudad'=>'Medellín', 'moneda'=>'COP',
            'precio_galon'=>11641, 'precio_litro'=>3075.23,
            'vigente_desde'=>'2026-11-01', 'consultado_el'=>'2026-11-15', 'fuente'=>PrecioAcpmCreg::FUENTE,
        ]);
        $this->getJson(self::RUTA)->assertOk();
        Http::assertSentCount(1);

        $this->travel(3)->minutes();
        $this->getJson(self::RUTA)->assertOk()->assertJsonPath('consultado_el', '2026-11-16');
        Http::assertSentCount(2);
        $this->travelBack();
    }

    public function test_no_ofrece_un_precio_de_vigencia_futura_o_sin_columna_acpm(): void
    {
        $this->travelTo(Carbon::parse('2026-11-15 09:00', 'America/Bogota'));
        Http::fake([PrecioAcpmCreg::FUENTE=>Http::sequence()
            ->push($this->publicacion('1 de diciembre del 2026', '11.641'))
            ->push(str_replace('ACPM ($/gal)', 'Gasolina extra ($/gal)', $this->publicacion('1 de noviembre del 2026', '11.641')))]);
        $this->withSession(['usuario_demo'=>config('demo.perfil')]);
        $this->getJson(self::RUTA)->assertServiceUnavailable()->assertJsonMissingPath('precio_galon');
        $this->travel(2)->minutes();
        $this->getJson(self::RUTA)->assertServiceUnavailable()->assertJsonMissingPath('precio_galon');
        $this->travelBack();
    }

    private function publicacion(string $fecha, string $precio): string
    {
        return <<<HTML
            <meta charset="utf-8">
            <h2>1. Precios de los combustibles vigentes</h2>
            <p>Información oficial</p>
            <table>
              <caption><h3>Precios vigentes a partir del $fecha (13 ciudades principales)</h3></caption>
              <tr><th>No.</th><th>Ciudad</th><th>Gasolina MC (\$/gal)</th><th>ACPM (\$/gal)</th></tr>
              <tr><td>1</td><td>Bogotá</td><td>16.331</td><td>11.616</td></tr>
              <tr><td>2</td><td><strong>Medell&iacute;n</strong></td><td>16.251</td><td>$precio</td></tr>
            </table>
            HTML;
    }
}
