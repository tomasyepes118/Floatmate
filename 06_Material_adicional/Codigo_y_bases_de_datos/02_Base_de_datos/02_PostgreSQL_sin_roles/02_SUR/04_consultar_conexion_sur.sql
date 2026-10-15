/* Ejecute en cualquier base del servidor SUR como postgres. */
SELECT
    current_user AS usuario_sur,
    current_database() AS base_actual,
    coalesce(inet_server_addr()::text, '127.0.0.1') AS host_sur,
    current_setting('port') AS puerto_sur,
    version() AS version_postgresql;

/* Comprueba que la base Sur ya existe. */
SELECT datname
FROM pg_database
WHERE datname = 'floatmate_sur';
