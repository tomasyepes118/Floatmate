/* NORTE > floatmate_norte. Comprueba la ultima copia sin consultar SUR ni CSV. */
DO $$
DECLARE origen text; hecho text; n_origen bigint; n_hecho bigint;
BEGIN
 IF NOT EXISTS (SELECT 1 FROM dwh.etl_ejecucion) THEN
   RAISE EXCEPTION 'No hay cargas exitosas. Ejecute 05_ejecutar_carga.sql';
 END IF;
 FOR origen,hecho IN SELECT * FROM (VALUES
   ('viajes','fact_viaje'),('abastecimientos','fact_abastecimiento'),
   ('mantenimientos','fact_mantenimiento'),('controles_salida','fact_control_salida'),
   ('incidentes','fact_incidente')) AS pares(origen,hecho) LOOP
   EXECUTE format('SELECT count(*) FROM dwh.%I','stg_'||origen) INTO n_origen;
   EXECUTE format('SELECT count(*) FROM dwh.%I',hecho) INTO n_hecho;
   IF n_origen<>n_hecho THEN
     RAISE EXCEPTION '%: staging % distinto de hechos %',hecho,n_origen,n_hecho;
   END IF;
 END LOOP;
 IF (SELECT coalesce(sum(pasajeros),0) FROM dwh.stg_viajes)
    <> (SELECT coalesce(sum(pasajeros),0) FROM dwh.fact_viaje) OR
    (SELECT coalesce(sum(valor_total),0) FROM dwh.stg_abastecimientos)
    <> (SELECT coalesce(sum(costo_cop),0) FROM dwh.fact_abastecimiento) OR
    (SELECT coalesce(sum(costo),0) FROM dwh.stg_mantenimientos)
    <> (SELECT coalesce(sum(costo_cop),0) FROM dwh.fact_mantenimiento) THEN
   RAISE EXCEPTION 'No coinciden los pasajeros o los costos entre fuentes copiadas y hechos';
 END IF;
 IF EXISTS (SELECT 1 FROM dwh.stg_vehiculos s LEFT JOIN dwh.dim_vehiculo d
   USING (terminal_codigo,vehiculo_id) WHERE d.vehiculo_sk IS NULL) OR
    EXISTS (SELECT 1 FROM dwh.stg_conductores s LEFT JOIN dwh.dim_conductor d
   USING (terminal_codigo,conductor_id) WHERE d.conductor_sk IS NULL) OR
    EXISTS (SELECT 1 FROM dwh.stg_rutas s LEFT JOIN dwh.dim_ruta d
   USING (terminal_codigo,ruta_id) WHERE d.ruta_sk IS NULL) OR
    EXISTS (SELECT 1 FROM dwh.stg_usuarios s LEFT JOIN dwh.dim_usuario d
   USING (terminal_codigo,usuario_id) WHERE d.usuario_sk IS NULL) THEN
   RAISE EXCEPTION 'Faltan registros de dimension';
 END IF;
 RAISE NOTICE 'VALIDACION DWH COMPLETA: cantidades, dimensiones, pasajeros y costos correctos';
END $$;
SELECT 'viajes' AS entidad,count(*) AS registros FROM dwh.fact_viaje
UNION ALL SELECT 'abastecimientos',count(*) FROM dwh.fact_abastecimiento
UNION ALL SELECT 'mantenimientos',count(*) FROM dwh.fact_mantenimiento
UNION ALL SELECT 'controles_salida',count(*) FROM dwh.fact_control_salida
UNION ALL SELECT 'incidentes',count(*) FROM dwh.fact_incidente;
SELECT fuente, terminal_codigo,count(*) AS registros,sum(costo_cop) AS costo_cop
FROM dwh.fact_mantenimiento GROUP BY fuente,terminal_codigo ORDER BY fuente,terminal_codigo;
