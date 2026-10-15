/* NORTE > floatmate_norte, como postgres.
   PRIMERO copiar datos/mantenimientos_externos.csv al equipo Windows de NORTE:
   C:\FloatMate\csv\mantenimientos_externos.csv
   La cuenta Windows del servicio PostgreSQL necesita permiso de lectura.
   No es una ruta de tu computador cliente. CSV UTF-8, coma, punto decimal.
   Crear FOREIGN TABLE define el enlace: SELECT lee el archivo, no lo importa.
   Si el archivo ya se enlazo con otra ruta, usar ALTER ... OPTIONS (SET filename ...).
*/
BEGIN;
DO $$ BEGIN
  IF current_database() <> 'floatmate_norte' THEN
    RAISE EXCEPTION 'Ejecutar en NORTE > floatmate_norte';
  END IF;
END $$;
CREATE EXTENSION IF NOT EXISTS file_fdw;
CREATE SCHEMA IF NOT EXISTS floatmate_externo;
CREATE SERVER IF NOT EXISTS servidor_csv_local FOREIGN DATA WRAPPER file_fdw;
CREATE FOREIGN TABLE IF NOT EXISTS floatmate_externo.mantenimientos_csv (
  registro_csv text,
  terminal_codigo varchar(3),
  vehiculo_id bigint,
  tipo varchar(15),
  fecha_ingreso date,
  fecha_salida date,
  kilometraje numeric(12,2),
  costo numeric(12,2),
  proveedor text,
  descripcion text,
  estado varchar(15)
) SERVER servidor_csv_local
OPTIONS (filename 'C:/FloatMate/csv/mantenimientos_externos.csv',
         format 'csv', header 'true', delimiter ',', encoding 'UTF8');
COMMENT ON FOREIGN TABLE floatmate_externo.mantenimientos_csv IS
  'Lectura en vivo del CSV situado en el servidor NORTE; no es una copia local en PostgreSQL.';
-- Esta consulta debe leer el archivo ANTES de confirmar la instalacion.
SELECT * FROM floatmate_externo.mantenimientos_csv ORDER BY registro_csv;
COMMIT;
