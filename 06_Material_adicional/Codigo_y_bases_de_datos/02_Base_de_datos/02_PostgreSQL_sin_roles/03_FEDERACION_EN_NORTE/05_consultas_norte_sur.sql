/*
===============================================================================
 FLOATMATE - CONSULTAS DISTRIBUIDAS ENTRE NORTE Y SUR
===============================================================================
 Ejecutar exclusivamente desde:
   Servidor: Norte
   Base:     floatmate_norte
   Usuario:  postgres

 Todas las consultas son de lectura. No modifican datos.
*/

/* 1. Confirmar que estamos en el nodo coordinador Norte. */
SELECT
    current_database() AS base_actual,
    current_user AS usuario_actual,
    current_setting('port') AS puerto_norte;

/* 2. Mostrar el servidor FDW configurado. */
SELECT
    s.srvname AS servidor_remoto,
    f.fdwname AS tecnologia,
    s.srvoptions AS opciones_conexion
FROM pg_foreign_server AS s
JOIN pg_foreign_data_wrapper AS f ON f.oid = s.srvfdw
WHERE s.srvname = 'servidor_terminal_sur';

/* 3. Mostrar las tablas de Sur importadas en Norte. */
SELECT
    foreign_table_schema AS esquema_local,
    foreign_table_name AS tabla_remota,
    foreign_server_name AS servidor
FROM information_schema.foreign_tables
WHERE foreign_table_schema = 'floatmate_remoto'
ORDER BY foreign_table_name;

/* 4. Consultar directamente vehiculos que viven fisicamente en Sur. */
SELECT
    vehiculo_id,
    terminal_codigo,
    placa,
    codigo_interno,
    tipo,
    marca,
    modelo,
    capacidad_pasajeros,
    estado
FROM floatmate_remoto.vehiculos
ORDER BY vehiculo_id;

/* 5. Comparar cantidad de vehiculos locales y remotos. */
SELECT 'NORTE_LOCAL' AS origen, count(*) AS cantidad
FROM floatmate.vehiculos
UNION ALL
SELECT 'SUR_REMOTO' AS origen, count(*) AS cantidad
FROM floatmate_remoto.vehiculos;

/* 6. Reconstruir manualmente la relacion logica completa. */
SELECT vehiculo_id, terminal_codigo, placa, tipo, estado, 'NORTE_LOCAL' AS nodo
FROM floatmate.vehiculos
UNION ALL
SELECT vehiculo_id, terminal_codigo, placa, tipo, estado, 'SUR_REMOTO' AS nodo
FROM floatmate_remoto.vehiculos
ORDER BY vehiculo_id;

/* 7. Consultar la vista global ya construida. */
SELECT
    vehiculo_id,
    terminal_codigo,
    nodo_origen,
    placa,
    codigo_interno,
    tipo,
    estado
FROM floatmate_global.vehiculos
ORDER BY terminal_codigo, vehiculo_id;

/* 8. Relacionar viajes, vehiculos, conductores y rutas del nodo Sur. */
SELECT
    vi.viaje_id,
    vi.fecha_hora_programada,
    vi.estado AS estado_viaje,
    ve.placa,
    ve.codigo_interno AS vehiculo,
    concat_ws(' ', co.nombres, co.apellidos) AS conductor,
    ru.nombre AS ruta,
    ru.origen,
    ru.destino,
    vi.pasajeros
FROM floatmate_remoto.viajes AS vi
JOIN floatmate_remoto.vehiculos AS ve
  ON ve.vehiculo_id = vi.vehiculo_id
JOIN floatmate_remoto.conductores AS co
  ON co.conductor_id = vi.conductor_id
JOIN floatmate_remoto.rutas AS ru
  ON ru.ruta_id = vi.ruta_id
ORDER BY vi.fecha_hora_programada;

/* 9. Consultar viajes de ambas terminales desde una sola vista. */
SELECT
    viaje_id,
    terminal_codigo,
    nodo_origen,
    fecha_hora_programada,
    placa,
    conductor,
    ruta,
    origen,
    destino,
    pasajeros,
    estado,
    control_salida
FROM floatmate_global.v_operacion_viajes
ORDER BY fecha_hora_programada, terminal_codigo;

/* 10. Total de viajes y pasajeros por terminal. */
SELECT
    terminal_codigo,
    count(*) AS total_viajes,
    sum(pasajeros) AS total_pasajeros,
    round(avg(pasajeros), 2) AS promedio_pasajeros
FROM floatmate_global.viajes
GROUP BY terminal_codigo
ORDER BY terminal_codigo;

/* 11. Comparar consumo y costo de combustible entre Norte y Sur. */
SELECT
    terminal_codigo,
    count(*) AS abastecimientos,
    round(sum(litros), 2) AS litros_totales,
    round(sum(valor_total), 2) AS costo_total,
    round(avg(valor_litro), 2) AS valor_promedio_litro
FROM floatmate_global.abastecimientos
GROUP BY terminal_codigo
ORDER BY terminal_codigo;

/* 12. Incidentes registrados en los dos nodos. */
SELECT
    terminal_codigo,
    severidad,
    estado,
    count(*) AS cantidad
FROM floatmate_global.incidentes
GROUP BY terminal_codigo, severidad, estado
ORDER BY terminal_codigo, severidad, estado;

/* 13. Vehiculos que requieren mantenimiento primero, sin importar el nodo. */
SELECT
    terminal_codigo,
    placa,
    codigo_interno,
    kilometraje,
    proximo_mantenimiento_km,
    greatest(proximo_mantenimiento_km - kilometraje, 0) AS km_restantes
FROM floatmate_global.vehiculos
ORDER BY km_restantes, terminal_codigo, vehiculo_id;

/* 14. Controles de salida del nodo Sur consultados desde Norte. */
SELECT
    cs.control_id,
    cs.viaje_id,
    cs.fecha_hora_control,
    cs.resultado,
    cs.numero_ticket,
    concat_ws(' ', u.nombres, u.apellidos) AS operador
FROM floatmate_remoto.controles_salida AS cs
JOIN floatmate_remoto.usuarios AS u
  ON u.usuario_id = cs.usuario_id
ORDER BY cs.fecha_hora_control;

/* 15. Probar que las nueve vistas globales tienen 15 NOR + 15 SUR. */
SELECT 'vehiculos' AS entidad, terminal_codigo, count(*) AS cantidad
FROM floatmate_global.vehiculos GROUP BY terminal_codigo
UNION ALL
SELECT 'conductores', terminal_codigo, count(*)
FROM floatmate_global.conductores GROUP BY terminal_codigo
UNION ALL
SELECT 'rutas', terminal_codigo, count(*)
FROM floatmate_global.rutas GROUP BY terminal_codigo
UNION ALL
SELECT 'viajes', terminal_codigo, count(*)
FROM floatmate_global.viajes GROUP BY terminal_codigo
UNION ALL
SELECT 'usuarios', terminal_codigo, count(*)
FROM floatmate_global.usuarios GROUP BY terminal_codigo
ORDER BY entidad, terminal_codigo;

/* 16. Evidencia tecnica: debe aparecer un nodo Foreign Scan. */
EXPLAIN (VERBOSE, COSTS OFF)
SELECT viaje_id, terminal_codigo, estado
FROM floatmate_remoto.viajes
WHERE estado = 'FINALIZADO';

/* 17. Consulta distribuida con CTE para comparar indicadores. */
WITH norte AS (
    SELECT count(*) AS viajes, sum(pasajeros) AS pasajeros
    FROM floatmate.viajes
), sur AS (
    SELECT count(*) AS viajes, sum(pasajeros) AS pasajeros
    FROM floatmate_remoto.viajes
)
SELECT
    norte.viajes AS viajes_norte,
    sur.viajes AS viajes_sur,
    norte.viajes + sur.viajes AS viajes_totales,
    norte.pasajeros AS pasajeros_norte,
    sur.pasajeros AS pasajeros_sur,
    norte.pasajeros + sur.pasajeros AS pasajeros_totales
FROM norte CROSS JOIN sur;
