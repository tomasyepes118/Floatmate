/* NORTE > floatmate_norte. Instala/reemplaza el procedimiento, NO lo ejecuta.
   Recarga completa de staging y hechos; dimensiones con actualizacion tipo 1.
   No guarda versiones historicas de cambios: refleja la ultima carga exitosa.
   Cualquier error revierte la carga completa al ejecutarla en una transaccion.
*/
BEGIN;
CREATE OR REPLACE PROCEDURE dwh.sp_cargar()
LANGUAGE plpgsql AS $$
DECLARE t text; pk text; n bigint; inicio timestamptz := clock_timestamp();
BEGIN
 IF current_database() <> 'floatmate_norte' THEN
   RAISE EXCEPTION 'Ejecutar en NORTE > floatmate_norte';
 END IF;
 PERFORM pg_advisory_xact_lock(1008,2026);
 TRUNCATE dwh.stg_usuarios,dwh.stg_vehiculos,dwh.stg_conductores,dwh.stg_rutas,dwh.stg_viajes,dwh.stg_controles_salida,dwh.stg_abastecimientos,dwh.stg_mantenimientos,dwh.stg_incidentes;
 INSERT INTO dwh.stg_usuarios SELECT * FROM floatmate_global.usuarios;
 INSERT INTO dwh.stg_vehiculos SELECT * FROM floatmate_global.vehiculos;
 INSERT INTO dwh.stg_conductores SELECT * FROM floatmate_global.conductores;
 INSERT INTO dwh.stg_rutas SELECT * FROM floatmate_global.rutas;
 INSERT INTO dwh.stg_viajes SELECT * FROM floatmate_global.viajes;
 INSERT INTO dwh.stg_controles_salida SELECT * FROM floatmate_global.controles_salida;
 INSERT INTO dwh.stg_abastecimientos SELECT * FROM floatmate_global.abastecimientos;
 INSERT INTO dwh.stg_mantenimientos SELECT * FROM floatmate_federacion.mantenimientos_federados;
 INSERT INTO dwh.stg_incidentes SELECT * FROM floatmate_global.incidentes;

 -- Validar terminales, identidades vacias y duplicadas ANTES de reemplazar hechos.
 FOR t,pk IN SELECT * FROM (VALUES
 ('usuarios','usuario_id'),
 ('vehiculos','vehiculo_id'),
 ('conductores','conductor_id'),
 ('rutas','ruta_id'),
 ('viajes','viaje_id'),
 ('controles_salida','control_id'),
 ('abastecimientos','abastecimiento_id'),
 ('mantenimientos','registro_origen'),
 ('incidentes','incidente_id')) AS k(tabla,clave) LOOP
   EXECUTE format('SELECT count(*) FROM dwh.%I WHERE terminal_codigo IS NULL OR terminal_codigo NOT IN (''NOR'',''SUR'') OR %I IS NULL OR length(btrim(%I::text)) = 0', 'stg_'||t,pk,pk) INTO n;
   IF n > 0 THEN RAISE EXCEPTION 'Datos invalidos: % filas de % con terminal/identidad invalida',n,t; END IF;
   IF t='mantenimientos' THEN
     SELECT count(*) INTO n FROM (
       SELECT fuente,terminal_codigo,registro_origen FROM dwh.stg_mantenimientos
       GROUP BY fuente,terminal_codigo,registro_origen HAVING count(*)>1
     ) duplicados;
   ELSE
     EXECUTE format('SELECT count(*) FROM (SELECT terminal_codigo,%I FROM dwh.%I GROUP BY terminal_codigo,%I HAVING count(*)>1) d',pk,'stg_'||t,pk) INTO n;
   END IF;
   IF n>0 THEN RAISE EXCEPTION 'Hay identidades duplicadas en %',t; END IF;
 END LOOP;
 IF EXISTS (SELECT 1 FROM dwh.stg_mantenimientos WHERE
   fuente IS NULL OR fuente NOT IN ('POSTGRESQL','CSV_LOCAL') OR
   vehiculo_id IS NULL OR tipo IS NULL OR tipo NOT IN ('PREVENTIVO','CORRECTIVO') OR
   fecha_ingreso IS NULL OR (fecha_salida IS NOT NULL AND fecha_salida<fecha_ingreso) OR
   kilometraje IS NULL OR kilometraje<0 OR costo IS NULL OR costo<0 OR
   proveedor IS NULL OR btrim(proveedor)='' OR descripcion IS NULL OR btrim(descripcion)='' OR
   estado IS NULL OR estado NOT IN ('PROGRAMADO','EN_PROCESO','FINALIZADO')) THEN
   RAISE EXCEPTION 'Mantenimiento invalido en PostgreSQL o CSV: revise fechas, costo, tipo, estado y campos obligatorios';
 END IF;
 IF EXISTS (SELECT 1 FROM dwh.stg_viajes c LEFT JOIN dwh.stg_vehiculos p
   ON p.terminal_codigo=c.terminal_codigo AND p.vehiculo_id=c.vehiculo_id
   WHERE p.vehiculo_id IS NULL) THEN
   RAISE EXCEPTION 'Relacion invalida: viajes.vehiculo_id sin vehiculos en la misma terminal';
 END IF;
 IF EXISTS (SELECT 1 FROM dwh.stg_viajes c LEFT JOIN dwh.stg_conductores p
   ON p.terminal_codigo=c.terminal_codigo AND p.conductor_id=c.conductor_id
   WHERE p.conductor_id IS NULL) THEN
   RAISE EXCEPTION 'Relacion invalida: viajes.conductor_id sin conductores en la misma terminal';
 END IF;
 IF EXISTS (SELECT 1 FROM dwh.stg_viajes c LEFT JOIN dwh.stg_rutas p
   ON p.terminal_codigo=c.terminal_codigo AND p.ruta_id=c.ruta_id
   WHERE p.ruta_id IS NULL) THEN
   RAISE EXCEPTION 'Relacion invalida: viajes.ruta_id sin rutas en la misma terminal';
 END IF;
 IF EXISTS (SELECT 1 FROM dwh.stg_abastecimientos c LEFT JOIN dwh.stg_vehiculos p
   ON p.terminal_codigo=c.terminal_codigo AND p.vehiculo_id=c.vehiculo_id
   WHERE p.vehiculo_id IS NULL) THEN
   RAISE EXCEPTION 'Relacion invalida: abastecimientos.vehiculo_id sin vehiculos en la misma terminal';
 END IF;
 IF EXISTS (SELECT 1 FROM dwh.stg_abastecimientos c LEFT JOIN dwh.stg_usuarios p
   ON p.terminal_codigo=c.terminal_codigo AND p.usuario_id=c.usuario_id
   WHERE p.usuario_id IS NULL) THEN
   RAISE EXCEPTION 'Relacion invalida: abastecimientos.usuario_id sin usuarios en la misma terminal';
 END IF;
 IF EXISTS (SELECT 1 FROM dwh.stg_abastecimientos c LEFT JOIN dwh.stg_viajes p
   ON p.terminal_codigo=c.terminal_codigo AND p.viaje_id=c.viaje_id
   WHERE c.viaje_id IS NOT NULL AND p.viaje_id IS NULL) THEN
   RAISE EXCEPTION 'Relacion invalida: abastecimientos.viaje_id sin viajes en la misma terminal';
 END IF;
 IF EXISTS (SELECT 1 FROM dwh.stg_mantenimientos c LEFT JOIN dwh.stg_vehiculos p
   ON p.terminal_codigo=c.terminal_codigo AND p.vehiculo_id=c.vehiculo_id
   WHERE p.vehiculo_id IS NULL) THEN
   RAISE EXCEPTION 'Relacion invalida: mantenimientos.vehiculo_id sin vehiculos en la misma terminal';
 END IF;
 IF EXISTS (SELECT 1 FROM dwh.stg_mantenimientos c LEFT JOIN dwh.stg_usuarios p
   ON p.terminal_codigo=c.terminal_codigo AND p.usuario_id=c.usuario_id
   WHERE c.usuario_id IS NOT NULL AND p.usuario_id IS NULL) THEN
   RAISE EXCEPTION 'Relacion invalida: mantenimientos.usuario_id sin usuarios en la misma terminal';
 END IF;
 IF EXISTS (SELECT 1 FROM dwh.stg_controles_salida c LEFT JOIN dwh.stg_viajes p
   ON p.terminal_codigo=c.terminal_codigo AND p.viaje_id=c.viaje_id
   WHERE p.viaje_id IS NULL) THEN
   RAISE EXCEPTION 'Relacion invalida: controles_salida.viaje_id sin viajes en la misma terminal';
 END IF;
 IF EXISTS (SELECT 1 FROM dwh.stg_controles_salida c LEFT JOIN dwh.stg_usuarios p
   ON p.terminal_codigo=c.terminal_codigo AND p.usuario_id=c.usuario_id
   WHERE p.usuario_id IS NULL) THEN
   RAISE EXCEPTION 'Relacion invalida: controles_salida.usuario_id sin usuarios en la misma terminal';
 END IF;
 IF EXISTS (SELECT 1 FROM dwh.stg_incidentes c LEFT JOIN dwh.stg_viajes p
   ON p.terminal_codigo=c.terminal_codigo AND p.viaje_id=c.viaje_id
   WHERE p.viaje_id IS NULL) THEN
   RAISE EXCEPTION 'Relacion invalida: incidentes.viaje_id sin viajes en la misma terminal';
 END IF;
 IF EXISTS (SELECT 1 FROM dwh.stg_incidentes c LEFT JOIN dwh.stg_usuarios p
   ON p.terminal_codigo=c.terminal_codigo AND p.usuario_id=c.usuario_id
   WHERE p.usuario_id IS NULL) THEN
   RAISE EXCEPTION 'Relacion invalida: incidentes.usuario_id sin usuarios en la misma terminal';
 END IF;
 INSERT INTO dwh.dim_terminal VALUES ('NOR','Terminal Norte'),('SUR','Terminal Sur')
 ON CONFLICT (terminal_codigo) DO UPDATE SET nombre=EXCLUDED.nombre;
 INSERT INTO dwh.dim_usuario (terminal_codigo,usuario_id,documento,nombres,apellidos,rol,activo) SELECT terminal_codigo,usuario_id,documento,nombres,apellidos,rol,activo FROM dwh.stg_usuarios
 WHERE true ON CONFLICT (terminal_codigo,usuario_id) DO UPDATE SET documento=EXCLUDED.documento,nombres=EXCLUDED.nombres,apellidos=EXCLUDED.apellidos,rol=EXCLUDED.rol,activo=EXCLUDED.activo;
 INSERT INTO dwh.dim_vehiculo (terminal_codigo,vehiculo_id,placa,tipo,marca,modelo,capacidad_pasajeros) SELECT terminal_codigo,vehiculo_id,placa,tipo,marca,modelo,capacidad_pasajeros FROM dwh.stg_vehiculos
 WHERE true ON CONFLICT (terminal_codigo,vehiculo_id) DO UPDATE SET placa=EXCLUDED.placa,tipo=EXCLUDED.tipo,marca=EXCLUDED.marca,modelo=EXCLUDED.modelo,capacidad_pasajeros=EXCLUDED.capacidad_pasajeros;
 INSERT INTO dwh.dim_conductor (terminal_codigo,conductor_id,documento,nombres,apellidos,categoria_licencia) SELECT terminal_codigo,conductor_id,documento,nombres,apellidos,categoria_licencia FROM dwh.stg_conductores
 WHERE true ON CONFLICT (terminal_codigo,conductor_id) DO UPDATE SET documento=EXCLUDED.documento,nombres=EXCLUDED.nombres,apellidos=EXCLUDED.apellidos,categoria_licencia=EXCLUDED.categoria_licencia;
 INSERT INTO dwh.dim_ruta (terminal_codigo,ruta_id,codigo,nombre,origen,destino,tipo,distancia_km) SELECT terminal_codigo,ruta_id,codigo,nombre,origen,destino,tipo,distancia_km FROM dwh.stg_rutas
 WHERE true ON CONFLICT (terminal_codigo,ruta_id) DO UPDATE SET codigo=EXCLUDED.codigo,nombre=EXCLUDED.nombre,origen=EXCLUDED.origen,destino=EXCLUDED.destino,tipo=EXCLUDED.tipo,distancia_km=EXCLUDED.distancia_km;
 INSERT INTO dwh.dim_fecha
 SELECT f::date,extract(year FROM f)::int,extract(quarter FROM f)::int,
        extract(month FROM f)::int,extract(day FROM f)::int,extract(isodow FROM f)::int
 FROM (SELECT generate_series(min(fecha)::timestamp,max(fecha)::timestamp,interval '1 day') AS f FROM (
   SELECT (fecha_hora_programada AT TIME ZONE 'America/Bogota')::date AS fecha FROM dwh.stg_viajes
   UNION ALL SELECT (fecha_hora AT TIME ZONE 'America/Bogota')::date FROM dwh.stg_abastecimientos
   UNION ALL SELECT fecha_ingreso FROM dwh.stg_mantenimientos
   UNION ALL SELECT (fecha_hora_control AT TIME ZONE 'America/Bogota')::date FROM dwh.stg_controles_salida
   UNION ALL SELECT (fecha_hora AT TIME ZONE 'America/Bogota')::date FROM dwh.stg_incidentes
 ) fechas) calendario WHERE true ON CONFLICT (fecha) DO NOTHING;
 TRUNCATE dwh.fact_viaje,dwh.fact_abastecimiento,dwh.fact_mantenimiento,dwh.fact_control_salida,dwh.fact_incidente;
 INSERT INTO dwh.fact_viaje
 SELECT s.terminal_codigo,s.viaje_id,(s.fecha_hora_programada AT TIME ZONE 'America/Bogota')::date,
        v.vehiculo_sk,c.conductor_sk,r.ruta_sk,s.fecha_hora_programada,s.fecha_hora_salida,s.fecha_hora_llegada,
        s.estado,s.pasajeros,v.capacidad_pasajeros,r.distancia_km,
        extract(epoch FROM (s.fecha_hora_llegada-s.fecha_hora_salida))/60
 FROM dwh.stg_viajes s
 JOIN dwh.dim_vehiculo v ON v.terminal_codigo=s.terminal_codigo AND v.vehiculo_id=s.vehiculo_id
 JOIN dwh.dim_conductor c ON c.terminal_codigo=s.terminal_codigo AND c.conductor_id=s.conductor_id
 JOIN dwh.dim_ruta r ON r.terminal_codigo=s.terminal_codigo AND r.ruta_id=s.ruta_id;
 INSERT INTO dwh.fact_abastecimiento
 SELECT s.terminal_codigo,s.abastecimiento_id,(s.fecha_hora AT TIME ZONE 'America/Bogota')::date,
        v.vehiculo_sk,u.usuario_sk,s.viaje_id,s.litros,s.valor_litro,s.valor_total,s.kilometraje
 FROM dwh.stg_abastecimientos s
 JOIN dwh.dim_vehiculo v ON v.terminal_codigo=s.terminal_codigo AND v.vehiculo_id=s.vehiculo_id
 JOIN dwh.dim_usuario u ON u.terminal_codigo=s.terminal_codigo AND u.usuario_id=s.usuario_id;
 INSERT INTO dwh.fact_mantenimiento
 SELECT s.fuente,s.terminal_codigo,s.registro_origen,s.fecha_ingreso,v.vehiculo_sk,u.usuario_sk,
        s.tipo,s.estado,s.proveedor,s.fecha_salida,s.kilometraje,s.costo
 FROM dwh.stg_mantenimientos s
 JOIN dwh.dim_vehiculo v ON v.terminal_codigo=s.terminal_codigo AND v.vehiculo_id=s.vehiculo_id
 LEFT JOIN dwh.dim_usuario u ON u.terminal_codigo=s.terminal_codigo AND u.usuario_id=s.usuario_id;
 INSERT INTO dwh.fact_control_salida
 SELECT s.terminal_codigo,s.control_id,s.viaje_id,(s.fecha_hora_control AT TIME ZONE 'America/Bogota')::date,
        v.vehiculo_sk,u.usuario_sk,s.resultado,s.alcoholemia_mg_l
 FROM dwh.stg_controles_salida s
 JOIN dwh.stg_viajes j ON j.terminal_codigo=s.terminal_codigo AND j.viaje_id=s.viaje_id
 JOIN dwh.dim_vehiculo v ON v.terminal_codigo=j.terminal_codigo AND v.vehiculo_id=j.vehiculo_id
 JOIN dwh.dim_usuario u ON u.terminal_codigo=s.terminal_codigo AND u.usuario_id=s.usuario_id;
 INSERT INTO dwh.fact_incidente
 SELECT s.terminal_codigo,s.incidente_id,s.viaje_id,(s.fecha_hora AT TIME ZONE 'America/Bogota')::date,
        v.vehiculo_sk,u.usuario_sk,s.tipo,s.severidad,s.estado,s.tiene_evidencia
 FROM dwh.stg_incidentes s
 JOIN dwh.stg_viajes j ON j.terminal_codigo=s.terminal_codigo AND j.viaje_id=s.viaje_id
 JOIN dwh.dim_vehiculo v ON v.terminal_codigo=j.terminal_codigo AND v.vehiculo_id=j.vehiculo_id
 JOIN dwh.dim_usuario u ON u.terminal_codigo=s.terminal_codigo AND u.usuario_id=s.usuario_id;
 INSERT INTO dwh.etl_ejecucion(iniciado_en,finalizado_en,conteos)
 VALUES (inicio,clock_timestamp(),jsonb_build_object(
   'viajes',(SELECT count(*) FROM dwh.fact_viaje),
   'abastecimientos',(SELECT count(*) FROM dwh.fact_abastecimiento),
   'mantenimientos',(SELECT count(*) FROM dwh.fact_mantenimiento),
   'mantenimientos_csv',(SELECT count(*) FROM dwh.fact_mantenimiento WHERE fuente='CSV_LOCAL'),
   'controles_salida',(SELECT count(*) FROM dwh.fact_control_salida),
   'incidentes',(SELECT count(*) FROM dwh.fact_incidente)));
 RAISE NOTICE 'CARGA DWH COMPLETA: staging, dimensiones y hechos actualizados';
END $$;
COMMIT;
