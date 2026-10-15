/*
  Ejecutar en floatmate_sur como postgres DESPUES del modelo y los datos.
  Crea una cuenta remota de solo lectura para la federacion.
*/

DO $crear_usuario_fdw$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'floatmate_fdw') THEN
        CREATE ROLE floatmate_fdw LOGIN PASSWORD 'FloatMate_FDW_2026!';
    END IF;
END
$crear_usuario_fdw$;

ALTER ROLE floatmate_fdw WITH LOGIN PASSWORD 'FloatMate_FDW_2026!';
GRANT CONNECT ON DATABASE floatmate_sur TO floatmate_fdw;
GRANT USAGE ON SCHEMA floatmate TO floatmate_fdw;
GRANT SELECT ON ALL TABLES IN SCHEMA floatmate TO floatmate_fdw;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA floatmate TO floatmate_fdw;

ALTER DEFAULT PRIVILEGES FOR ROLE floatmate_admin IN SCHEMA floatmate
    GRANT SELECT ON TABLES TO floatmate_fdw;

COMMENT ON ROLE floatmate_fdw IS
  'Cuenta de solo lectura usada desde Terminal Norte mediante postgres_fdw.';
