/*
  FLOATMATE - FEDERACION LOCAL DESDE NORTE HACIA SUR

  Ejecutar en floatmate_norte como postgres.
  Esta version esta lista para dos bases en el mismo PostgreSQL local.
  Solo cambie 5432 si su instalacion usa un puerto diferente.

  La clave coincide con 02_nodo_sur/03_usuario_fdw_sur.sql.
*/

BEGIN;

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

DROP SCHEMA IF EXISTS floatmate_remoto CASCADE;
DROP SERVER IF EXISTS servidor_terminal_sur CASCADE;

CREATE SCHEMA floatmate_remoto;
COMMENT ON SCHEMA floatmate_remoto IS
  'Tablas foraneas: acceso en tiempo real al fragmento de Terminal Sur.';

CREATE SERVER servidor_terminal_sur
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (
        host '127.0.0.1',
        port '5432',
        dbname 'floatmate_sur',
        fetch_size '1000',
        use_remote_estimate 'true',
        updatable 'false'
    );

CREATE USER MAPPING FOR CURRENT_USER
    SERVER servidor_terminal_sur
    OPTIONS (
        user 'floatmate_fdw',
        password 'FloatMate_FDW_2026!'
    );

CREATE USER MAPPING FOR floatmate_admin
    SERVER servidor_terminal_sur
    OPTIONS (
        user 'floatmate_fdw',
        password 'FloatMate_FDW_2026!'
    );

IMPORT FOREIGN SCHEMA floatmate
    LIMIT TO (
        usuarios,
        conductores,
        vehiculos,
        rutas,
        viajes,
        controles_salida,
        abastecimientos,
        mantenimientos,
        incidentes
    )
    FROM SERVER servidor_terminal_sur
    INTO floatmate_remoto;

GRANT USAGE ON FOREIGN SERVER servidor_terminal_sur TO floatmate_admin;
GRANT USAGE ON SCHEMA floatmate_remoto TO floatmate_admin;
GRANT SELECT ON ALL TABLES IN SCHEMA floatmate_remoto TO floatmate_admin;

COMMIT;

-- Esta consulta debe devolver 15 filas remotas si la conexion quedo correcta.
SELECT count(*) AS vehiculos_recibidos_desde_sur
FROM floatmate_remoto.vehiculos;
