/* PRIMERO: abrir Query Tool en Norte > floatmate_norte.
   Tambien sirve en Sur > floatmate_sur si desea instalar el modulo alli.
   Solo consulta. No crea bases, usuarios ni roles. */
SELECT current_database() AS base_actual, current_user AS usuario,
       current_setting('port') AS puerto, version() AS version;
DO $$
DECLARE t text;
BEGIN
  IF current_database() NOT IN ('floatmate_norte', 'floatmate_sur') THEN
    RAISE EXCEPTION 'Abra Query Tool sobre floatmate_norte o floatmate_sur; base actual: %', current_database();
  END IF;
  FOREACH t IN ARRAY ARRAY['vehiculos','conductores','rutas','viajes','mantenimientos','controles_salida'] LOOP
    IF to_regclass('floatmate.' || t) IS NULL THEN
      RAISE EXCEPTION 'Falta floatmate.%. Termine primero el modelo y los datos de la actividad BDD.', t;
    END IF;
  END LOOP;
  RAISE NOTICE 'Base correcta. Siga con 01_modelo_objetos.sql.';
END $$;
SELECT 'vehiculos' AS tabla, count(*) AS registros FROM floatmate.vehiculos
UNION ALL SELECT 'conductores', count(*) FROM floatmate.conductores
UNION ALL SELECT 'rutas', count(*) FROM floatmate.rutas
UNION ALL SELECT 'viajes', count(*) FROM floatmate.viajes
UNION ALL SELECT 'mantenimientos', count(*) FROM floatmate.mantenimientos;
