/* 15 registros por cada una de las 9 tablas del nodo Norte. */

BEGIN;
SET search_path TO floatmate, pg_catalog;

INSERT INTO usuarios
    (usuario_id, terminal_codigo, documento, nombres, apellidos, correo, rol, activo, creado_en)
SELECT
    1000 + n,
    'NOR',
    '10010' || lpad(n::text, 3, '0'),
    (ARRAY['Ana','Brayan','Camila','Daniel','Elena','Felipe','Gabriela','Hector','Isabel','Juan','Karen','Luis','Maria','Nicolas','Olga'])[n],
    (ARRAY['Alvarez','Benitez','Cardona','Diaz','Escobar','Franco','Gomez','Herrera','Ibarra','Jimenez','Lopez','Martinez','Navarro','Ortiz','Perez'])[n],
    'usuario.norte' || lpad(n::text, 2, '0') || '@floatmate.edu.co',
    CASE WHEN n IN (1, 2) THEN 'ADMINISTRADOR'
         WHEN n <= 12 THEN 'OPERADOR'
         ELSE 'CONSULTA' END,
    true,
    timestamptz '2026-08-01 08:00:00-05' + (n - 1) * interval '1 hour'
FROM generate_series(1, 15) AS s(n);

INSERT INTO conductores
    (conductor_id, terminal_codigo, documento, nombres, apellidos, numero_licencia,
     categoria_licencia, licencia_vence, telefono, estado)
SELECT
    1000 + n,
    'NOR',
    '20010' || lpad(n::text, 3, '0'),
    (ARRAY['Andres','Beatriz','Carlos','Diana','Esteban','Fernanda','Giovanni','Helena','Ivan','Juliana','Kevin','Laura','Miguel','Natalia','Oscar'])[n],
    (ARRAY['Rios','Suarez','Torres','Uribe','Valencia','Zapata','Arias','Bustos','Cano','Duque','Estrada','Florez','Gil','Henao','Jaramillo'])[n],
    'LIC-NOR-' || lpad(n::text, 3, '0'),
    CASE WHEN n % 3 = 0 THEN 'C3' WHEN n % 2 = 0 THEN 'C2' ELSE 'C1' END,
    date '2027-12-31' + n,
    '300510' || lpad(n::text, 4, '0'),
    CASE WHEN n = 15 THEN 'INACTIVO' ELSE 'DISPONIBLE' END
FROM generate_series(1, 15) AS s(n);

INSERT INTO vehiculos
    (vehiculo_id, terminal_codigo, placa, codigo_interno, tipo, marca, modelo,
     capacidad_pasajeros, kilometraje, proximo_mantenimiento_km, estado)
SELECT
    1000 + n,
    'NOR',
    (ARRAY['FTA101','FTB102','FTC103','FTD104','FTE105','FTF106','FTG107','FTH108','FTI109','FTJ110','FTK111','FTL112','FTM113','FTN114','FTO115'])[n],
    'BUS-NOR-' || lpad(n::text, 3, '0'),
    CASE WHEN n % 3 = 0 THEN 'MICROBUS'
         WHEN n % 2 = 0 THEN 'BUS_INTERMUNICIPAL'
         ELSE 'BUS_URBANO' END,
    (ARRAY['Chevrolet','Mercedes-Benz','Hino','Volkswagen','Scania'])[1 + ((n - 1) % 5)],
    (2012 + n)::smallint,
    (24 + n * 2)::smallint,
    (45000 + n * 1750)::numeric(12,2),
    (50000 + n * 1750)::numeric(12,2),
    CASE WHEN n = 14 THEN 'MANTENIMIENTO' ELSE 'DISPONIBLE' END
FROM generate_series(1, 15) AS s(n);

INSERT INTO rutas
    (ruta_id, terminal_codigo, codigo, nombre, origen, destino, tipo,
     distancia_km, duracion_minutos, activa)
SELECT
    1000 + n,
    'NOR',
    'R-NOR-' || lpad(n::text, 3, '0'),
    'Ruta Norte ' || lpad(n::text, 2, '0'),
    'Terminal Norte',
    (ARRAY['Bello','Copacabana','Girardota','Barbosa','Caribe','Castilla','Robledo','Aranjuez','Manrique','Prado','Centro','Buenos Aires','Boston','La America','San Javier'])[n],
    CASE WHEN n <= 5 THEN 'INTERMUNICIPAL' ELSE 'URBANA' END,
    (8.50 + n * 2.35)::numeric(8,2),
    (30 + n * 5)::smallint,
    true
FROM generate_series(1, 15) AS s(n);

INSERT INTO viajes
    (viaje_id, terminal_codigo, vehiculo_id, conductor_id, ruta_id,
     fecha_hora_programada, fecha_hora_salida, fecha_hora_llegada,
     pasajeros, estado, observaciones)
SELECT
    1000 + n,
    'NOR',
    1000 + n,
    1000 + n,
    1000 + n,
    timestamptz '2026-09-01 05:00:00-05' + (n - 1) * interval '1 day',
    timestamptz '2026-09-01 05:05:00-05' + (n - 1) * interval '1 day',
    timestamptz '2026-09-01 06:35:00-05' + (n - 1) * interval '1 day',
    (12 + n)::smallint,
    'FINALIZADO',
    'Operacion normal del fragmento Norte'
FROM generate_series(1, 15) AS s(n);

INSERT INTO controles_salida
    (control_id, terminal_codigo, viaje_id, usuario_id, fecha_hora_control,
     alcoholemia_mg_l, resultado, numero_ticket, observaciones)
SELECT
    1000 + n,
    'NOR',
    1000 + n,
    1000 + n,
    timestamptz '2026-09-01 04:30:00-05' + (n - 1) * interval '1 day',
    0.000,
    'APROBADO',
    'ALC-NOR-' || lpad(n::text, 4, '0'),
    'Identidad, licencia y prueba verificadas'
FROM generate_series(1, 15) AS s(n);

INSERT INTO abastecimientos
    (abastecimiento_id, terminal_codigo, vehiculo_id, viaje_id, usuario_id,
     fecha_hora, litros, valor_litro, valor_total, kilometraje,
     estacion_servicio, numero_factura)
SELECT
    1000 + n,
    'NOR',
    1000 + n,
    1000 + n,
    1000 + n,
    timestamptz '2026-09-01 07:00:00-05' + (n - 1) * interval '1 day',
    (50 + n)::numeric(8,2),
    (10300 + n * 10)::numeric(10,2),
    round((50 + n)::numeric * (10300 + n * 10)::numeric, 2),
    (46750 + n * 1750)::numeric(12,2),
    'EDS FloatMate Norte',
    'FAC-NOR-' || lpad(n::text, 4, '0')
FROM generate_series(1, 15) AS s(n);

INSERT INTO mantenimientos
    (mantenimiento_id, terminal_codigo, vehiculo_id, usuario_id, tipo,
     fecha_ingreso, fecha_salida, kilometraje, costo, proveedor,
     descripcion, estado)
SELECT
    1000 + n,
    'NOR',
    1000 + n,
    1000 + n,
    CASE WHEN n % 4 = 0 THEN 'CORRECTIVO' ELSE 'PREVENTIVO' END,
    date '2026-08-01' + n,
    date '2026-08-02' + n,
    (45000 + n * 1750)::numeric(12,2),
    (350000 + n * 45000)::numeric(12,2),
    'Taller Norte ' || (1 + ((n - 1) % 3)),
    CASE WHEN n % 4 = 0 THEN 'Correccion del sistema de frenos'
         ELSE 'Cambio de aceite, filtros e inspeccion general' END,
    'FINALIZADO'
FROM generate_series(1, 15) AS s(n);

INSERT INTO incidentes
    (incidente_id, terminal_codigo, viaje_id, usuario_id, fecha_hora, tipo,
     severidad, descripcion, ubicacion, tiene_evidencia, estado)
SELECT
    1000 + n,
    'NOR',
    1000 + n,
    1000 + n,
    timestamptz '2026-09-01 05:45:00-05' + (n - 1) * interval '1 day',
    (ARRAY['MECANICO','TRANSITO','SEGURIDAD','OPERATIVO'])[1 + ((n - 1) % 4)],
    (ARRAY['BAJA','MEDIA','ALTA'])[1 + ((n - 1) % 3)],
    'Novedad operativa documentada numero ' || n,
    'Corredor vial Norte, punto ' || n,
    (n % 2 = 0),
    CASE WHEN n <= 12 THEN 'CERRADO' ELSE 'EN_REVISION' END
FROM generate_series(1, 15) AS s(n);

SELECT setval(pg_get_serial_sequence('floatmate.usuarios', 'usuario_id'), 1015, true);
SELECT setval(pg_get_serial_sequence('floatmate.conductores', 'conductor_id'), 1015, true);
SELECT setval(pg_get_serial_sequence('floatmate.vehiculos', 'vehiculo_id'), 1015, true);
SELECT setval(pg_get_serial_sequence('floatmate.rutas', 'ruta_id'), 1015, true);
SELECT setval(pg_get_serial_sequence('floatmate.viajes', 'viaje_id'), 1015, true);
SELECT setval(pg_get_serial_sequence('floatmate.controles_salida', 'control_id'), 1015, true);
SELECT setval(pg_get_serial_sequence('floatmate.abastecimientos', 'abastecimiento_id'), 1015, true);
SELECT setval(pg_get_serial_sequence('floatmate.mantenimientos', 'mantenimiento_id'), 1015, true);
SELECT setval(pg_get_serial_sequence('floatmate.incidentes', 'incidente_id'), 1015, true);

COMMIT;
