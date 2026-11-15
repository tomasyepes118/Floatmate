<?php

namespace App\Services;

use Carbon\Exceptions\InvalidFormatException;
use Dom\Element;
use Dom\HTMLDocument;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class PrecioAcpmCreg
{
    public const FUENTE = 'https://creg.gov.co/publicaciones/15565/precios-de-combustibles-liquidos/';
    private const LITROS_POR_GALON = 3.785411784;

    public function consultar(): ?array
    {
        $hoy = Carbon::today('America/Bogota')->toDateString();
        $clave = 'precio-acpm:creg:medellin:'.$hoy;
        $guardado = Cache::get($clave);
        if ($guardado !== null) {
            return $guardado ?: null;
        }

        try {
            $respuesta = Http::accept('text/html')->connectTimeout(3)->timeout(7)->get(self::FUENTE);
            $precio = $respuesta->successful() ? $this->leerReferencia($respuesta->body(), $hoy) : null;
        } catch (ConnectionException) {
            $precio = null;
        }

        Cache::put($clave, $precio ?? false, $precio ? 3600 : 60);
        return $precio;
    }

    private function leerReferencia(string $html, string $hoy): ?array
    {
        if (trim($html) === '') {
            return null;
        }

        $documento = HTMLDocument::createFromString($html, LIBXML_NOERROR);
        foreach ($documento->querySelectorAll('h2') as $titulo) {
            if (str_ends_with($this->texto($titulo), 'PRECIOS DE LOS COMBUSTIBLES VIGENTES')) {
                return $this->leerTablaVigente($titulo, $hoy);
            }
        }
        return null;
    }

    private function leerTablaVigente(Element $titulo, string $hoy): ?array
    {
        $tabla = $titulo->nextElementSibling;
        while ($tabla && !in_array($tabla->localName, ['table', 'h2'], true)) {
            $tabla = $tabla->nextElementSibling;
        }
        if ($tabla?->localName !== 'table' || !preg_match(
            '/^PRECIOS VIGENTES A PARTIR DEL? (\d{1,2}) DE ([A-Z]+) DEL? (\d{4})\b/',
            $this->texto($tabla->querySelector('caption')), $fecha
        )) {
            return null;
        }

        try {
            $vigencia = Carbon::createFromLocaleFormat('!j F Y', 'es', "$fecha[1] $fecha[2] $fecha[3]", 'America/Bogota');
        } catch (InvalidFormatException) {
            return null;
        }
        if (!$vigencia || $vigencia->format('j') !== (string) (int) $fecha[1] || $vigencia->toDateString() > $hoy) {
            return null;
        }

        $cabeceras = array_map($this->texto(...), iterator_to_array($tabla->querySelectorAll('tr:first-child th'), false));
        $ciudad = array_search('CIUDAD', $cabeceras, true);
        $acpm = array_search('ACPM ($/GAL)', $cabeceras, true);
        if ($ciudad === false || $acpm === false) {
            return null;
        }

        foreach ($tabla->querySelectorAll('tr') as $fila) {
            $celdas = $fila->querySelectorAll('td');
            if ($this->texto($celdas->item($ciudad)) !== 'MEDELLIN') {
                continue;
            }
            $valor = $this->texto($celdas->item($acpm));
            if (!preg_match('/^\$?\s*(\d{1,3}(?:\.\d{3})+|\d+)(?:,\d{1,2})?$/D', $valor)) {
                return null;
            }
            $precio = (float) str_replace(['$', '.', ','], ['', '', '.'], $valor);
            if ($precio <= 0 || !is_finite($precio)) {
                return null;
            }

            return [
                'combustible'=>'ACPM', 'ciudad'=>'Medellín', 'moneda'=>'COP',
                'precio_galon'=>$precio, 'precio_litro'=>round($precio / self::LITROS_POR_GALON, 2),
                'vigente_desde'=>$vigencia->toDateString(), 'consultado_el'=>$hoy, 'fuente'=>self::FUENTE,
            ];
        }
        return null;
    }

    private function texto(?Element $elemento): string
    {
        return strtoupper(Str::ascii(Str::squish($elemento?->textContent ?? '')));
    }
}
