<?php

return [
    'default'=>'pgsql',
    'connections'=>[
        'pgsql'=>[
            'driver'=>'pgsql',
            'host'=>env('DB_HOST', '127.0.0.1'),
            'port'=>env('DB_PORT', '5432'),
            'database'=>env('DB_DATABASE', 'floatmate'),
            'username'=>env('DB_USERNAME', 'floatmate'),
            'password'=>env('DB_PASSWORD', ''),
            'charset'=>'utf8',
            'prefix'=>'',
            'search_path'=>'public',
            'sslmode'=>env('DB_SSLMODE', 'prefer'),
        ],
    ],
    'migrations'=>['table'=>'migrations', 'update_date_on_publish'=>true],
];
