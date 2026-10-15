/* NORTE > floatmate_norte. Vista virtual: no almacena las filas del CSV. */
BEGIN;
CREATE SCHEMA IF NOT EXISTS floatmate_federacion;
CREATE OR REPLACE VIEW floatmate_federacion.mantenimientos_federados AS
SELECT 'POSTGRESQL'::text AS fuente, m.mantenimiento_id::text AS registro_origen,
       m.terminal_codigo, m.vehiculo_id, m.usuario_id,
       m.tipo, m.fecha_ingreso, m.fecha_salida, m.kilometraje,
       m.costo, m.proveedor::text, m.descripcion::text, m.estado
FROM floatmate_global.mantenimientos m
UNION ALL
SELECT 'CSV_LOCAL'::text, c.registro_csv, c.terminal_codigo, c.vehiculo_id,
       NULL::bigint AS usuario_id, c.tipo, c.fecha_ingreso, c.fecha_salida,
       c.kilometraje, c.costo, c.proveedor, c.descripcion, c.estado
FROM floatmate_externo.mantenimientos_csv c;
COMMENT ON VIEW floatmate_federacion.mantenimientos_federados IS
  'Federacion de mantenimientos de NORTE, SUR y CSV. Clave: fuente + terminal + registro_origen.';
COMMIT;
SELECT fuente, terminal_codigo, count(*) AS registros, sum(costo) AS costo_cop
FROM floatmate_federacion.mantenimientos_federados
GROUP BY fuente, terminal_codigo ORDER BY fuente, terminal_codigo;
