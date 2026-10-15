/* NORTE > floatmate_norte. Todas las consultas leen solo tablas fisicas dwh.*.
   No necesitan conexion a SUR ni al CSV despues de una carga exitosa.
   Resultados reflejan el momento de la ultima carga ETL. */

-- 1. Viajes finalizados, pasajeros y ocupacion ponderada por terminal/mes.
SELECT f.anio,f.mes,t.nombre AS terminal,count(*) AS viajes_finalizados,
       sum(h.pasajeros) AS pasajeros,
       round(100.0*sum(h.pasajeros)/nullif(sum(h.capacidad),0),2) AS ocupacion_pct,
       round(avg(h.duracion_real_minutos),2) AS duracion_promedio_minutos
FROM dwh.fact_viaje h JOIN dwh.dim_fecha f USING(fecha)
JOIN dwh.dim_terminal t USING(terminal_codigo)
WHERE h.estado='FINALIZADO'
GROUP BY f.anio,f.mes,t.nombre ORDER BY f.anio,f.mes,t.nombre;

-- 2. Costos mensuales de combustible y mantenimiento (evita multiplicar filas
--    uniendo hechos entre si). No representa costos totales de la empresa.
WITH costos AS (
 SELECT fecha,terminal_codigo,'COMBUSTIBLE' AS concepto,costo_cop FROM dwh.fact_abastecimiento
 UNION ALL
 SELECT fecha,terminal_codigo,'MANTENIMIENTO',costo_cop FROM dwh.fact_mantenimiento
)
SELECT f.anio,f.mes,t.nombre AS terminal,c.concepto,sum(c.costo_cop) AS costo_cop
FROM costos c JOIN dwh.dim_fecha f USING(fecha)
JOIN dwh.dim_terminal t USING(terminal_codigo)
GROUP BY f.anio,f.mes,t.nombre,c.concepto ORDER BY f.anio,f.mes,t.nombre,c.concepto;

-- 3. Procedencia de mantenimientos: PostgreSQL vs archivo de talleres.
SELECT h.fuente,t.nombre AS terminal,h.tipo,count(*) AS mantenimientos,
       sum(h.costo_cop) AS costo_cop
FROM dwh.fact_mantenimiento h JOIN dwh.dim_terminal t USING(terminal_codigo)
GROUP BY h.fuente,t.nombre,h.tipo ORDER BY h.fuente,t.nombre,h.tipo;

-- 4. Pasajeros transportados por ruta (solo viajes finalizados).
SELECT r.terminal_codigo,r.codigo,r.nombre,count(*) AS viajes,sum(h.pasajeros) AS pasajeros
FROM dwh.fact_viaje h JOIN dwh.dim_ruta r USING(ruta_sk)
WHERE h.estado='FINALIZADO'
GROUP BY r.terminal_codigo,r.codigo,r.nombre ORDER BY pasajeros DESC,r.codigo;

-- 5. Litros y costo por vehiculo. No llamar rendimiento km/l a un abastecimiento
--    sin un intervalo de kilometraje asociado y una metodologia de medicion.
SELECT v.terminal_codigo,v.placa,sum(h.litros) AS litros,
       sum(h.costo_cop) AS costo_cop,
       round(sum(h.costo_cop)/nullif(sum(h.litros),0),2) AS precio_promedio_litro_cop
FROM dwh.fact_abastecimiento h JOIN dwh.dim_vehiculo v USING(vehiculo_sk)
GROUP BY v.terminal_codigo,v.placa ORDER BY costo_cop DESC;

-- 6. Incidentes por tipo/severidad y controles por resultado.
SELECT terminal_codigo,tipo,severidad,count(*) AS incidentes
FROM dwh.fact_incidente GROUP BY terminal_codigo,tipo,severidad
ORDER BY terminal_codigo,tipo,severidad;
SELECT terminal_codigo,resultado,count(*) AS controles
FROM dwh.fact_control_salida GROUP BY terminal_codigo,resultado ORDER BY terminal_codigo,resultado;

-- 7. Momento y cantidades de la ultima carga exitosa.
SELECT * FROM dwh.etl_ejecucion ORDER BY ejecucion_id DESC LIMIT 1;
