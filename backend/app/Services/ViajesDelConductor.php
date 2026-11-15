<?php

namespace App\Services;

class ViajesDelConductor
{
    public static function autorizar(?array $viaje, int $conductorId): void
    {
        abort_unless($viaje && $viaje['conductor_id'] === $conductorId, 404, 'No encontramos ese viaje.');
    }
}
