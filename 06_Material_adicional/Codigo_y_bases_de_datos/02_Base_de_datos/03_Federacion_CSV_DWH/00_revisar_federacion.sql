/* NORTE > floatmate_norte. Solo lectura: no reconfigura ni borra FDW. */
SELECT current_database() AS base, current_user AS usuario,
       inet_server_addr() AS servidor, current_setting('port') AS puerto;
DO $$
DECLARE t text; n bigint;
BEGIN
  IF current_database() <> 'floatmate_norte' THEN
    RAISE EXCEPTION 'Ejecutar en NORTE > floatmate_norte, no en postgres ni SUR';
  END IF;
  FOREACH t IN ARRAY ARRAY['usuarios','conductores','vehiculos','rutas','viajes',
      'controles_salida','abastecimientos','mantenimientos','incidentes'] LOOP
    IF to_regclass('floatmate.' || t) IS NULL
       OR to_regclass('floatmate_remoto.' || t) IS NULL
       OR to_regclass('floatmate_global.' || t) IS NULL THEN
      RAISE EXCEPTION 'Falta la entidad % en local, remoto o global. Termine primero la federacion NORTE-SUR.', t;
    END IF;
    EXECUTE format('SELECT count(*) FROM floatmate_global.%I',t) INTO n;
    RAISE NOTICE '%: % filas globales; consulta NORTE-SUR correcta',t,n;
  END LOOP;
END $$;
SELECT s.srvname, w.fdwname
FROM pg_foreign_server s JOIN pg_foreign_data_wrapper w ON w.oid=s.srvfdw;
SELECT terminal_codigo, count(*) AS vehiculos
FROM floatmate_global.vehiculos GROUP BY terminal_codigo ORDER BY terminal_codigo;
