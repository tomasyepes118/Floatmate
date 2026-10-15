/* Consultas seguras, solo de lectura, para demostrar cada concepto. */

-- 1. ESQUEMAS: demuestra que las tablas no estan en public.
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema IN ('floatmate', 'floatmate_remoto', 'floatmate_global')
ORDER BY table_schema, table_name;

-- 2. FDW: servidor federado y tablas extranjeras importadas.
SELECT s.srvname AS servidor_fdw,
       f.fdwname AS envoltorio,
       s.srvoptions AS opciones_conexion
FROM pg_foreign_server AS s
JOIN pg_foreign_data_wrapper AS f ON f.oid = s.srvfdw;

SELECT foreign_table_schema, foreign_table_name, foreign_server_name
FROM information_schema.foreign_tables
WHERE foreign_table_schema = 'floatmate_remoto'
ORDER BY foreign_table_name;

-- 3. CONSULTA REMOTA: datos que fisicamente viven en Terminal Sur.
SELECT vehiculo_id, placa, codigo_interno, tipo, estado
FROM floatmate_remoto.vehiculos
ORDER BY vehiculo_id;

-- 4. FRAGMENTACION HORIZONTAL: 15 NOR + 15 SUR.
SELECT terminal_codigo, nodo_origen, count(*) AS cantidad_vehiculos
FROM floatmate_global.vehiculos
GROUP BY terminal_codigo, nodo_origen
ORDER BY terminal_codigo;

-- 5. VISTA GLOBAL: el usuario consulta una sola vista y recibe ambos nodos.
SELECT viaje_id, terminal_codigo, nodo_origen, fecha_hora_programada,
       placa, conductor, ruta, origen, destino, pasajeros, control_salida
FROM floatmate_global.v_operacion_viajes
ORDER BY fecha_hora_programada, terminal_codigo;

-- 6. ANALISIS GLOBAL de combustible por terminal.
SELECT terminal_codigo,
       count(*) AS abastecimientos,
       round(sum(litros), 2) AS litros_totales,
       round(sum(valor_total), 2) AS costo_total,
       round(avg(valor_litro), 2) AS precio_promedio_litro
FROM floatmate_global.abastecimientos
GROUP BY terminal_codigo
ORDER BY terminal_codigo;

-- 7. Incidentes consolidados por severidad y terminal.
SELECT terminal_codigo, severidad, count(*) AS cantidad
FROM floatmate_global.incidentes
GROUP BY terminal_codigo, severidad
ORDER BY terminal_codigo, severidad;

-- 8. El plan VERBOSE permite mostrar que PostgreSQL usa un Foreign Scan.
EXPLAIN (VERBOSE, COSTS OFF)
SELECT viaje_id, terminal_codigo, estado
FROM floatmate_remoto.viajes
WHERE estado = 'FINALIZADO';
