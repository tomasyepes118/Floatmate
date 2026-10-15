/* 15 registros por cada una de las 9 tablas del nodo Sur. */

BEGIN;
SET search_path TO floatmate, pg_catalog;

INSERT INTO usuarios
    (usuario_id, terminal_codigo, documento, nombres, apellidos, correo, rol, activo, creado_en)
SELECT
    2000 + n, 'SUR', '10020' || lpad(n::text, 3, '0'),
    (ARRAY['Pablo','Raquel','Santiago','Tatiana','Ulises','Valeria','William','Ximena','Yair','Zulma','Adriana','Bernardo','Cecilia','Diego','Erika'])[n],
    (ARRAY['Quintero','Restrepo','Salazar','Tamayo','Usuga','Vargas','Wills','Yepes','Zea','Acevedo','Barrera','Correa','Duran','Echeverri','Fonseca'])[n],
    'usuario.sur' || lpad(n::text, 2, '0') || '@floatmate.edu.co',
    CASE WHEN n IN (1, 2) THEN 'ADMINISTRADOR' WHEN n <= 12 THEN 'OPERADOR' ELSE 'CONSULTA' END,
    true,
    timestamptz '2026-08-01 08:00:00-05' + (n - 1) * interval '1 hour'
FROM generate_series(1, 15) AS s(n);

INSERT INTO conductores
    (conductor_id, terminal_codigo, documento, nombres, apellidos, numero_licencia,
     categoria_licencia, licencia_vence, telefono, estado)
SELECT
    2000 + n, 'SUR', '20020' || lpad(n::text, 3, '0'),
    (ARRAY['Pedro','Rosa','Samuel','Teresa','Uriel','Viviana','Walter','Xiomara','Yeison','Zoraida','Alonso','Blanca','Cesar','Dolores','Elias'])[n],
    (ARRAY['Londoño','Montoya','Ocampo','Palacio','Rendon','Sierra','Tobon','Upegui','Velasquez','Agudelo','Botero','Cifuentes','Delgado','Enriquez','Forero'])[n],
    'LIC-SUR-' || lpad(n::text, 3, '0'),
    CASE WHEN n % 3 = 0 THEN 'C3' WHEN n % 2 = 0 THEN 'C2' ELSE 'C1' END,
    date '2028-06-30' + n,
    '301520' || lpad(n::text, 4, '0'),
    CASE WHEN n = 15 THEN 'INACTIVO' ELSE 'DISPONIBLE' END
FROM generate_series(1, 15) AS s(n);

INSERT INTO vehiculos
    (vehiculo_id, terminal_codigo, placa, codigo_interno, tipo, marca, modelo,
     capacidad_pasajeros, kilometraje, proximo_mantenimiento_km, estado)
SELECT
    2000 + n,
    'SUR',
    (ARRAY['FSA201','FSB202','FSC203','FSD204','FSE205','FSF206','FSG207','FSH208','FSI209','FSJ210','FSK211','FSL212','FSM213','FSN214','FSO215'])[n],
    'BUS-SUR-' || lpad(n::text, 3, '0'),
    CASE WHEN n % 3 = 0 THEN 'MICROBUS' WHEN n % 2 = 0 THEN 'BUS_INTERMUNICIPAL' ELSE 'BUS_URBANO' END,
    (ARRAY['Volvo','Mercedes-Benz','Hino','Isuzu','Scania'])[1 + ((n - 1) % 5)],
    (2011 + n)::smallint,
    (25 + n * 2)::smallint,
    (52000 + n * 1650)::numeric(12,2),
    (57000 + n * 1650)::numeric(12,2),
    CASE WHEN n = 13 THEN 'MANTENIMIENTO' ELSE 'DISPONIBLE' END
FROM generate_series(1, 15) AS s(n);

INSERT INTO rutas
    (ruta_id, terminal_codigo, codigo, nombre, origen, destino, tipo,
     distancia_km, duracion_minutos, activa)
SELECT
    2000 + n, 'SUR', 'R-SUR-' || lpad(n::text, 3, '0'),
    'Ruta Sur ' || lpad(n::text, 2, '0'),
    'Terminal Sur',
    (ARRAY['Envigado','Itagui','Sabaneta','La Estrella','Caldas','El Poblado','Guayabal','Belen','Laureles','Conquistadores','San Diego','Las Palmas','Buenos Aires','El Salvador','Loreto'])[n],
    CASE WHEN n <= 5 THEN 'INTERMUNICIPAL' ELSE 'URBANA' END,
    (7.25 + n * 2.10)::numeric(8,2),
    (28 + n * 5)::smallint,
    true
FROM generate_series(1, 15) AS s(n);

INSERT INTO viajes
    (viaje_id, terminal_codigo, vehiculo_id, conductor_id, ruta_id,
     fecha_hora_programada, fecha_hora_salida, fecha_hora_llegada,
     pasajeros, estado, observaciones)
SELECT
    2000 + n, 'SUR', 2000 + n, 2000 + n, 2000 + n,
    timestamptz '2026-09-01 06:00:00-05' + (n - 1) * interval '1 day',
    timestamptz '2026-09-01 06:05:00-05' + (n - 1) * interval '1 day',
    timestamptz '2026-09-01 07:30:00-05' + (n - 1) * interval '1 day',
    (13 + n)::smallint,
    'FINALIZADO',
    'Operacion normal del fragmento Sur'
FROM generate_series(1, 15) AS s(n);

INSERT INTO controles_salida
    (control_id, terminal_codigo, viaje_id, usuario_id, fecha_hora_control,
     alcoholemia_mg_l, resultado, numero_ticket, observaciones)
SELECT
    2000 + n, 'SUR', 2000 + n, 2000 + n,
    timestamptz '2026-09-01 05:30:00-05' + (n - 1) * interval '1 day',
    0.000, 'APROBADO', 'ALC-SUR-' || lpad(n::text, 4, '0'),
    'Identidad, licencia y prueba verificadas'
FROM generate_series(1, 15) AS s(n);

INSERT INTO abastecimientos
    (abastecimiento_id, terminal_codigo, vehiculo_id, viaje_id, usuario_id,
     fecha_hora, litros, valor_litro, valor_total, kilometraje,
     estacion_servicio, numero_factura)
SELECT
    2000 + n, 'SUR', 2000 + n, 2000 + n, 2000 + n,
    timestamptz '2026-09-01 08:00:00-05' + (n - 1) * interval '1 day',
    (52 + n)::numeric(8,2),
    (10250 + n * 10)::numeric(10,2),
    round((52 + n)::numeric * (10250 + n * 10)::numeric, 2),
    (53650 + n * 1650)::numeric(12,2),
    'EDS FloatMate Sur',
    'FAC-SUR-' || lpad(n::text, 4, '0')
FROM generate_series(1, 15) AS s(n);

INSERT INTO mantenimientos
    (mantenimiento_id, terminal_codigo, vehiculo_id, usuario_id, tipo,
     fecha_ingreso, fecha_salida, kilometraje, costo, proveedor,
     descripcion, estado)
SELECT
    2000 + n, 'SUR', 2000 + n, 2000 + n,
    CASE WHEN n % 4 = 0 THEN 'CORRECTIVO' ELSE 'PREVENTIVO' END,
    date '2026-08-16' + n,
    date '2026-08-17' + n,
    (52000 + n * 1650)::numeric(12,2),
    (375000 + n * 42000)::numeric(12,2),
    'Taller Sur ' || (1 + ((n - 1) % 3)),
    CASE WHEN n % 4 = 0 THEN 'Reparacion del sistema electrico'
         ELSE 'Lubricacion, filtros e inspeccion general' END,
    'FINALIZADO'
FROM generate_series(1, 15) AS s(n);

INSERT INTO incidentes
    (incidente_id, terminal_codigo, viaje_id, usuario_id, fecha_hora, tipo,
     severidad, descripcion, ubicacion, tiene_evidencia, estado)
SELECT
    2000 + n, 'SUR', 2000 + n, 2000 + n,
    timestamptz '2026-09-01 06:45:00-05' + (n - 1) * interval '1 day',
    (ARRAY['MECANICO','TRANSITO','SEGURIDAD','OPERATIVO'])[1 + ((n - 1) % 4)],
    (ARRAY['BAJA','MEDIA','ALTA'])[1 + ((n - 1) % 3)],
    'Novedad operativa documentada numero ' || n,
    'Corredor vial Sur, punto ' || n,
    (n % 2 = 1),
    CASE WHEN n <= 11 THEN 'CERRADO' ELSE 'EN_REVISION' END
FROM generate_series(1, 15) AS s(n);

SELECT setval(pg_get_serial_sequence('floatmate.usuarios', 'usuario_id'), 2015, true);
SELECT setval(pg_get_serial_sequence('floatmate.conductores', 'conductor_id'), 2015, true);
SELECT setval(pg_get_serial_sequence('floatmate.vehiculos', 'vehiculo_id'), 2015, true);
SELECT setval(pg_get_serial_sequence('floatmate.rutas', 'ruta_id'), 2015, true);
SELECT setval(pg_get_serial_sequence('floatmate.viajes', 'viaje_id'), 2015, true);
SELECT setval(pg_get_serial_sequence('floatmate.controles_salida', 'control_id'), 2015, true);
SELECT setval(pg_get_serial_sequence('floatmate.abastecimientos', 'abastecimiento_id'), 2015, true);
SELECT setval(pg_get_serial_sequence('floatmate.mantenimientos', 'mantenimiento_id'), 2015, true);
SELECT setval(pg_get_serial_sequence('floatmate.incidentes', 'incidente_id'), 2015, true);

COMMIT;
