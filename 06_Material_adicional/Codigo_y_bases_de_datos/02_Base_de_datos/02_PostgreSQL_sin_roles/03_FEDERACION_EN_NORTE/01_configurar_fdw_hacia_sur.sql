/*
===============================================================================
 FLOATMATE - CONEXION DEL SERVIDOR NORTE HACIA EL SERVIDOR SUR
===============================================================================
 Ejecutar en: servidor NORTE / base floatmate_norte / usuario postgres.

 ANTES DE EJECUTAR reemplace solamente estos tres valores:
   HOST_DEL_SERVIDOR_SUR     Ejemplo: 127.0.0.1 o 192.168.1.20
   PUERTO_DEL_SERVIDOR_SUR   Ejemplo: 5433
   CLAVE_POSTGRES_SUR        La contraseña de postgres en el servidor Sur

 No se crea ningun rol adicional. FDW se conecta directamente como postgres.
*/

BEGIN;

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

DROP SCHEMA IF EXISTS floatmate_remoto CASCADE;
DROP SERVER IF EXISTS servidor_terminal_sur CASCADE;

CREATE SCHEMA floatmate_remoto;

CREATE SERVER servidor_terminal_sur
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (
        host 'HOST_DEL_SERVIDOR_SUR',
        port 'PUERTO_DEL_SERVIDOR_SUR',
        dbname 'floatmate_sur',
        fetch_size '1000',
        use_remote_estimate 'true'
    );

CREATE USER MAPPING FOR CURRENT_USER
    SERVER servidor_terminal_sur
    OPTIONS (
        user 'postgres',
        password 'CLAVE_POSTGRES_SUR'
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

COMMIT;

SELECT count(*) AS vehiculos_recibidos_desde_sur
FROM floatmate_remoto.vehiculos;
