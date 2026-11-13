<?php

return [
    'usuario' => env('DEMO_USERNAME', 'admin'),
    'clave_hash' => env('DEMO_PASSWORD_HASH', '$2y$12$0Imr.7YroQocVfcpWTBEV..vAio.hu6s78dbbOfgjPcTFdkKEZC0e'),
    'perfil' => ['nombre' => 'Tomas Yepes', 'rol' => 'Administrador'],
    'cuentas' => [
        'operador'=>['hash'=>env('DEMO_OPERADOR_HASH'), 'perfil'=>['nombre'=>'Operador de flota','rol'=>'Operador']],
        'consulta'=>['hash'=>env('DEMO_CONSULTA_HASH'), 'perfil'=>['nombre'=>'Consulta de flota','rol'=>'Consulta']],
    ],
    'directorio' => env('DEMO_DATA_PATH', storage_path('app/demo')),
    'almacen' => env('FLOTA_STORAGE', 'json'),
    'pruebas_navegador' => (bool) env('DEMO_E2E', false),
];
