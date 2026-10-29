<?php

return [
    'usuario' => env('DEMO_USERNAME', 'admin'),
    'clave_hash' => env('DEMO_PASSWORD_HASH', '$2y$12$0Imr.7YroQocVfcpWTBEV..vAio.hu6s78dbbOfgjPcTFdkKEZC0e'),
    'perfil' => ['nombre' => 'Tomas Yepes', 'rol' => 'Administrador'],
    'directorio' => env('DEMO_DATA_PATH', storage_path('app/demo')),
    'pruebas_navegador' => (bool) env('DEMO_E2E', false),
];
