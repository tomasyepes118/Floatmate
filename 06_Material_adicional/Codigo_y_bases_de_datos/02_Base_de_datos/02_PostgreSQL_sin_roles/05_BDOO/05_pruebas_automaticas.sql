/* Ejecutar COMPLETO. Todas las modificaciones de demostracion terminan en ROLLBACK.
   Los errores esperados se capturan; el archivo debe finalizar correctamente.
   Leer pestaña Messages: RESULTADO: todas las pruebas BDOO superadas.
   Las secuencias de auditoria pueden dejar saltos aunque se haga ROLLBACK: es normal. */
BEGIN;
DO $$
DECLARE v floatmate_objetos.vehiculo; c floatmate_objetos.conductor; r floatmate_objetos.ruta;
 id uuid; anterior uuid; km numeric; n bigint; rechazo boolean; ticket text; f floatmate_objetos.t_ficha;
BEGIN
 IF (SELECT datos_importados_en FROM floatmate_objetos.instalacion WHERE modulo='BDOO') IS NULL THEN
   RAISE EXCEPTION 'Primero ejecute 03_importar_datos_actuales.sql';
 END IF;
 SELECT count(*) INTO n FROM ONLY floatmate_objetos.vehiculo;
 IF n <> 0 THEN RAISE EXCEPTION 'El padre abstracto debe estar vacio'; END IF;
 IF (SELECT count(*) FROM floatmate_objetos.vehiculo) <> (SELECT count(*) FROM floatmate_objetos.identidad_vehiculo) THEN
   RAISE EXCEPTION 'Falla de identidad o herencia';
 END IF;
 IF EXISTS(SELECT oid FROM floatmate_objetos.vehiculo GROUP BY oid HAVING count(*)<>1) THEN
   RAISE EXCEPTION 'OID duplicado entre subclases';
 END IF;
 IF (SELECT count(*) FROM floatmate_objetos.vehiculo) < (SELECT count(*) FROM floatmate.vehiculos)
 OR (SELECT count(*) FROM floatmate_objetos.conductor) < (SELECT count(*) FROM floatmate.conductores)
 OR (SELECT count(*) FROM floatmate_objetos.ruta) < (SELECT count(*) FROM floatmate.rutas)
 OR (SELECT count(*) FROM floatmate_objetos.viaje) < (SELECT count(*) FROM floatmate.viajes)
 OR (SELECT count(*) FROM floatmate_objetos.mantenimiento) < (SELECT count(*) FROM floatmate.mantenimientos) THEN
   RAISE EXCEPTION 'La instantanea no contiene todos los registros de origen o el origen cambio despues de la carga';
 END IF;
 IF EXISTS(SELECT 1 FROM floatmate_objetos.bus_urbano b WHERE floatmate_objetos.fn_costo(b,10::numeric)<>14000)
 OR EXISTS(SELECT 1 FROM floatmate_objetos.bus_intermunicipal b WHERE floatmate_objetos.fn_costo(b,10::numeric)
   <> CASE WHEN b.aire_acondicionado THEN 24000 ELSE 22000 END)
 OR EXISTS(SELECT 1 FROM floatmate_objetos.microbus b WHERE floatmate_objetos.fn_costo(b,10::numeric)<>10000) THEN
   RAISE EXCEPTION 'Fallo en los metodos sobrecargados';
 END IF;
 SELECT b.* INTO v FROM floatmate_objetos.vehiculo b WHERE b.estado='DISPONIBLE' ORDER BY placa LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'Se requiere al menos un vehiculo DISPONIBLE para la demostracion'; END IF;
 SELECT b.* INTO c FROM floatmate_objetos.conductor b
 WHERE b.estado='DISPONIBLE' AND b.terminal_codigo=v.terminal_codigo
   AND (b.licencia).vence >= CURRENT_DATE ORDER BY documento LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'Se requiere conductor disponible con licencia vigente'; END IF;
 SELECT b.* INTO r FROM floatmate_objetos.ruta b WHERE b.activa AND b.terminal_codigo=v.terminal_codigo ORDER BY nombre LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'Se requiere ruta activa'; END IF;

 rechazo:=false;
 BEGIN UPDATE floatmate_objetos.vehiculo SET oid=gen_random_uuid() WHERE oid=v.oid;
 EXCEPTION WHEN raise_exception THEN rechazo:=true; END;
 IF NOT rechazo THEN RAISE EXCEPTION 'No se protegio el OID'; END IF;
 RAISE NOTICE 'OK: identidad inmutable';

 rechazo:=false;
 BEGIN PERFORM ROW('Marca',2020::smallint,0::smallint,0::numeric,5000::numeric)::floatmate_objetos.t_ficha::floatmate_objetos.d_ficha;
 EXCEPTION WHEN check_violation THEN rechazo:=true; END;
 IF NOT rechazo THEN RAISE EXCEPTION 'No se valido el tipo compuesto'; END IF;
 RAISE NOTICE 'OK: dominio rechaza capacidad invalida';

 rechazo:=false;
 BEGIN INSERT INTO floatmate_objetos.vehiculo SELECT v.*;
 EXCEPTION WHEN raise_exception THEN rechazo:=true; END;
 IF NOT rechazo THEN RAISE EXCEPTION 'Se permitio instanciar el padre'; END IF;
 RAISE NOTICE 'OK: superclase abstracta';

 rechazo:=false;
 BEGIN
   INSERT INTO floatmate_objetos.identidad_vehiculo(terminal_codigo,clase,placa)
   VALUES(v.terminal_codigo,v.clase,'ZZZ999');
   SET CONSTRAINTS ALL IMMEDIATE;
 EXCEPTION WHEN raise_exception THEN rechazo:=true; END;
 IF NOT rechazo THEN RAISE EXCEPTION 'Se permitio una identidad sin objeto'; END IF;
 SET CONSTRAINTS ALL DEFERRED;
 RAISE NOTICE 'OK: identidad requiere instancia';

 rechazo:=false;
 BEGIN
  CALL floatmate_objetos.sp_programar_viaje(v.oid,c.oid,r.oid,CURRENT_TIMESTAMP+interval '10 years',81::smallint);
 EXCEPTION WHEN raise_exception THEN rechazo:=true; END;
 IF NOT rechazo THEN RAISE EXCEPTION 'No se bloqueo el sobrecupo'; END IF;
 RAISE NOTICE 'OK: sobrecupo rechazado';

 CALL floatmate_objetos.sp_programar_viaje(v.oid,c.oid,r.oid,CURRENT_TIMESTAMP+interval '1 day',10::smallint);
 SELECT b.oid INTO id FROM floatmate_objetos.viaje b WHERE b.id_relacional IS NULL
 AND b.vehiculo_oid=v.oid AND b.fecha_programada=CURRENT_TIMESTAMP+interval '1 day';
 IF id IS NULL THEN RAISE EXCEPTION 'No se creo el objeto viaje'; END IF;

 rechazo:=false;
 BEGIN CALL floatmate_objetos.sp_iniciar_viaje(id,CURRENT_TIMESTAMP+interval '1 day');
 EXCEPTION WHEN raise_exception THEN rechazo:=true; END;
 IF NOT rechazo THEN RAISE EXCEPTION 'Se inicio sin control'; END IF;
 RAISE NOTICE 'OK: inicio sin control rechazado';

 CALL floatmate_objetos.sp_aprobar_control(id,'DEMO-BDOO-001');
 CALL floatmate_objetos.sp_iniciar_viaje(id,CURRENT_TIMESTAMP+interval '1 day');
 IF NOT EXISTS(SELECT 1 FROM floatmate_objetos.vehiculo b WHERE b.oid=v.oid AND b.estado='EN_RUTA') THEN
   RAISE EXCEPTION 'No se actualizo el vehiculo';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM floatmate_objetos.conductor b WHERE b.oid=c.oid AND b.estado='EN_VIAJE') THEN
   RAISE EXCEPTION 'No se actualizo el conductor';
 END IF;
 IF floatmate_objetos.fn_viaje_json(id)->'vehiculo'->>'oid' IS DISTINCT FROM v.oid::text THEN
   RAISE EXCEPTION 'Falla en la navegacion de objetos JSON';
 END IF;
 km:=(v.ficha).kilometraje+50;
 CALL floatmate_objetos.sp_cerrar_viaje(id,CURRENT_TIMESTAMP+interval '1 day 2 hours',km);
 IF NOT EXISTS(SELECT 1 FROM floatmate_objetos.viaje b WHERE b.oid=id AND b.estado='FINALIZADO')
 OR NOT EXISTS(SELECT 1 FROM floatmate_objetos.vehiculo b WHERE b.oid=v.oid AND b.estado='DISPONIBLE' AND (b.ficha).kilometraje=km)
 OR NOT EXISTS(SELECT 1 FROM floatmate_objetos.conductor b WHERE b.oid=c.oid AND b.estado='DISPONIBLE') THEN
   RAISE EXCEPTION 'Fallo de cierre del viaje';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM floatmate_objetos.auditoria a WHERE a.objeto_oid=v.oid AND a.operacion='UPDATE' AND a.anterior IS NOT NULL AND a.nuevo IS NOT NULL) THEN
   RAISE EXCEPTION 'No se registro auditoria';
 END IF;
 SET CONSTRAINTS ALL IMMEDIATE;
 RAISE NOTICE 'OK: programacion, control, inicio, cierre, JSON, auditoria y OID estable';
 RAISE NOTICE 'RESULTADO: todas las pruebas BDOO superadas. Ahora se hace ROLLBACK.';
END $$;
ROLLBACK;
SELECT 'Pruebas terminadas. Los datos de demostracion fueron revertidos.' AS resultado;
