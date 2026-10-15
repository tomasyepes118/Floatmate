/*
  Ejecutar en floatmate_norte como postgres DESPUES de configurar el FDW.
  Cada vista reconstruye la entidad logica completa con UNION ALL:
  fragmento local NOR + fragmento remoto SUR.
*/

BEGIN;

CREATE SCHEMA IF NOT EXISTS floatmate_global;
COMMENT ON SCHEMA floatmate_global IS
  'Vista global transparente de los fragmentos Norte y Sur.';

CREATE OR REPLACE VIEW floatmate_global.usuarios AS
SELECT u.usuario_id, u.terminal_codigo, u.documento, u.nombres, u.apellidos,
       u.correo, u.rol, u.activo, u.creado_en, 'NODO_NORTE_LOCAL'::text AS nodo_origen
FROM floatmate.usuarios AS u
UNION ALL
SELECT u.usuario_id, u.terminal_codigo, u.documento, u.nombres, u.apellidos,
       u.correo, u.rol, u.activo, u.creado_en, 'NODO_SUR_REMOTO'::text AS nodo_origen
FROM floatmate_remoto.usuarios AS u;

CREATE OR REPLACE VIEW floatmate_global.conductores AS
SELECT c.conductor_id, c.terminal_codigo, c.documento, c.nombres, c.apellidos,
       c.numero_licencia, c.categoria_licencia, c.licencia_vence, c.telefono,
       c.estado, 'NODO_NORTE_LOCAL'::text AS nodo_origen
FROM floatmate.conductores AS c
UNION ALL
SELECT c.conductor_id, c.terminal_codigo, c.documento, c.nombres, c.apellidos,
       c.numero_licencia, c.categoria_licencia, c.licencia_vence, c.telefono,
       c.estado, 'NODO_SUR_REMOTO'::text AS nodo_origen
FROM floatmate_remoto.conductores AS c;

CREATE OR REPLACE VIEW floatmate_global.vehiculos AS
SELECT v.vehiculo_id, v.terminal_codigo, v.placa, v.codigo_interno, v.tipo,
       v.marca, v.modelo, v.capacidad_pasajeros, v.kilometraje,
       v.proximo_mantenimiento_km, v.estado, 'NODO_NORTE_LOCAL'::text AS nodo_origen
FROM floatmate.vehiculos AS v
UNION ALL
SELECT v.vehiculo_id, v.terminal_codigo, v.placa, v.codigo_interno, v.tipo,
       v.marca, v.modelo, v.capacidad_pasajeros, v.kilometraje,
       v.proximo_mantenimiento_km, v.estado, 'NODO_SUR_REMOTO'::text AS nodo_origen
FROM floatmate_remoto.vehiculos AS v;

CREATE OR REPLACE VIEW floatmate_global.rutas AS
SELECT r.ruta_id, r.terminal_codigo, r.codigo, r.nombre, r.origen, r.destino,
       r.tipo, r.distancia_km, r.duracion_minutos, r.activa,
       'NODO_NORTE_LOCAL'::text AS nodo_origen
FROM floatmate.rutas AS r
UNION ALL
SELECT r.ruta_id, r.terminal_codigo, r.codigo, r.nombre, r.origen, r.destino,
       r.tipo, r.distancia_km, r.duracion_minutos, r.activa,
       'NODO_SUR_REMOTO'::text AS nodo_origen
FROM floatmate_remoto.rutas AS r;

CREATE OR REPLACE VIEW floatmate_global.viajes AS
SELECT v.viaje_id, v.terminal_codigo, v.vehiculo_id, v.conductor_id, v.ruta_id,
       v.fecha_hora_programada, v.fecha_hora_salida, v.fecha_hora_llegada,
       v.pasajeros, v.estado, v.observaciones, 'NODO_NORTE_LOCAL'::text AS nodo_origen
FROM floatmate.viajes AS v
UNION ALL
SELECT v.viaje_id, v.terminal_codigo, v.vehiculo_id, v.conductor_id, v.ruta_id,
       v.fecha_hora_programada, v.fecha_hora_salida, v.fecha_hora_llegada,
       v.pasajeros, v.estado, v.observaciones, 'NODO_SUR_REMOTO'::text AS nodo_origen
FROM floatmate_remoto.viajes AS v;

CREATE OR REPLACE VIEW floatmate_global.controles_salida AS
SELECT c.control_id, c.terminal_codigo, c.viaje_id, c.usuario_id,
       c.fecha_hora_control, c.alcoholemia_mg_l, c.resultado, c.numero_ticket,
       c.observaciones, 'NODO_NORTE_LOCAL'::text AS nodo_origen
FROM floatmate.controles_salida AS c
UNION ALL
SELECT c.control_id, c.terminal_codigo, c.viaje_id, c.usuario_id,
       c.fecha_hora_control, c.alcoholemia_mg_l, c.resultado, c.numero_ticket,
       c.observaciones, 'NODO_SUR_REMOTO'::text AS nodo_origen
FROM floatmate_remoto.controles_salida AS c;

CREATE OR REPLACE VIEW floatmate_global.abastecimientos AS
SELECT a.abastecimiento_id, a.terminal_codigo, a.vehiculo_id, a.viaje_id,
       a.usuario_id, a.fecha_hora, a.litros, a.valor_litro, a.valor_total,
       a.kilometraje, a.estacion_servicio, a.numero_factura,
       'NODO_NORTE_LOCAL'::text AS nodo_origen
FROM floatmate.abastecimientos AS a
UNION ALL
SELECT a.abastecimiento_id, a.terminal_codigo, a.vehiculo_id, a.viaje_id,
       a.usuario_id, a.fecha_hora, a.litros, a.valor_litro, a.valor_total,
       a.kilometraje, a.estacion_servicio, a.numero_factura,
       'NODO_SUR_REMOTO'::text AS nodo_origen
FROM floatmate_remoto.abastecimientos AS a;

CREATE OR REPLACE VIEW floatmate_global.mantenimientos AS
SELECT m.mantenimiento_id, m.terminal_codigo, m.vehiculo_id, m.usuario_id,
       m.tipo, m.fecha_ingreso, m.fecha_salida, m.kilometraje, m.costo,
       m.proveedor, m.descripcion, m.estado, 'NODO_NORTE_LOCAL'::text AS nodo_origen
FROM floatmate.mantenimientos AS m
UNION ALL
SELECT m.mantenimiento_id, m.terminal_codigo, m.vehiculo_id, m.usuario_id,
       m.tipo, m.fecha_ingreso, m.fecha_salida, m.kilometraje, m.costo,
       m.proveedor, m.descripcion, m.estado, 'NODO_SUR_REMOTO'::text AS nodo_origen
FROM floatmate_remoto.mantenimientos AS m;

CREATE OR REPLACE VIEW floatmate_global.incidentes AS
SELECT i.incidente_id, i.terminal_codigo, i.viaje_id, i.usuario_id,
       i.fecha_hora, i.tipo, i.severidad, i.descripcion, i.ubicacion,
       i.tiene_evidencia, i.estado, 'NODO_NORTE_LOCAL'::text AS nodo_origen
FROM floatmate.incidentes AS i
UNION ALL
SELECT i.incidente_id, i.terminal_codigo, i.viaje_id, i.usuario_id,
       i.fecha_hora, i.tipo, i.severidad, i.descripcion, i.ubicacion,
       i.tiene_evidencia, i.estado, 'NODO_SUR_REMOTO'::text AS nodo_origen
FROM floatmate_remoto.incidentes AS i;

CREATE OR REPLACE VIEW floatmate_global.v_operacion_viajes AS
SELECT
    vi.viaje_id,
    vi.terminal_codigo,
    vi.nodo_origen,
    vi.fecha_hora_programada,
    ve.placa,
    ve.codigo_interno AS vehiculo,
    co.documento AS documento_conductor,
    concat_ws(' ', co.nombres, co.apellidos) AS conductor,
    ru.codigo AS codigo_ruta,
    ru.nombre AS ruta,
    ru.origen,
    ru.destino,
    vi.pasajeros,
    vi.estado,
    cs.resultado AS control_salida,
    cs.numero_ticket
FROM floatmate_global.viajes AS vi
JOIN floatmate_global.vehiculos AS ve ON ve.vehiculo_id = vi.vehiculo_id
JOIN floatmate_global.conductores AS co ON co.conductor_id = vi.conductor_id
JOIN floatmate_global.rutas AS ru ON ru.ruta_id = vi.ruta_id
LEFT JOIN floatmate_global.controles_salida AS cs ON cs.viaje_id = vi.viaje_id;

COMMIT;
