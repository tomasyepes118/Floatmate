<?php

namespace App\Services;

class MunicipiosAntioquia
{
    public function todos(): array
    {
        return json_decode(file_get_contents(resource_path('data/municipios-antioquia.json')), true, 512, JSON_THROW_ON_ERROR);
    }
}
