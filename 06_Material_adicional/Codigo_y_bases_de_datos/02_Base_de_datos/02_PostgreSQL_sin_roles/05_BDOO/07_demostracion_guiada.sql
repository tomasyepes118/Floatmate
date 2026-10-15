/* DEMOSTRACION MANUAL EN PGADMIN, NO EJECUTAR TODAS LAS PARTES A LA VEZ.
   Seleccionar una seccion y pulsar F5. Hacerlo todo en la MISMA pestana Query Tool.
   La ultima seccion revierte los cambios. El error esperado de la seccion 5 esta capturado. */

-- SECCION 1: abrir una transaccion y elegir recursos existentes automaticamente.
BEGIN;
CREATE TEMP TABLE demo_bdoo_recursos ON COMMIT DROP AS
SELECT v.oid AS vehiculo,c.oid AS conductor,r.oid AS ruta,(v.ficha).kilometraje AS km
FROM floatmate_objetos.vehiculo v
JOIN floatmate_objetos.conductor c ON c.terminal_codigo=v.terminal_codigo
JOIN floatmate_objetos.ruta r ON r.terminal_codigo=v.terminal_codigo
WHERE v.estado='DISPONIBLE' AND c.estado='DISPONIBLE' AND r.activa
AND (c.licencia).vence >= (CURRENT_TIMESTAMP+interval '1 day')::date
ORDER BY v.placa,c.documento,r.nombre LIMIT 1;
SELECT * FROM demo_bdoo_recursos;

-- SECCION 2: invocar el metodo para crear un objeto viaje.
DO $$
DECLARE p record;
BEGIN
 SELECT * INTO p FROM demo_bdoo_recursos;
 IF NOT FOUND THEN RAISE EXCEPTION 'No hay recursos disponibles para la demostracion'; END IF;
 CALL floatmate_objetos.sp_programar_viaje(p.vehiculo,p.conductor,p.ruta,CURRENT_TIMESTAMP+interval '1 day',10::smallint);
END $$;
CREATE TEMP TABLE demo_bdoo_viaje ON COMMIT DROP AS
SELECT v.oid FROM floatmate_objetos.viaje v JOIN demo_bdoo_recursos d ON d.vehiculo=v.vehiculo_oid
WHERE v.id_relacional IS NULL AND v.fecha_programada=CURRENT_TIMESTAMP+interval '1 day';
SELECT v.oid,v.estado FROM floatmate_objetos.viaje v JOIN demo_bdoo_viaje d USING(oid);

-- SECCION 3: registrar control e iniciar. El metodo cambia tres objetos.
DO $$
DECLARE id uuid;
BEGIN
 SELECT oid INTO STRICT id FROM demo_bdoo_viaje;
 CALL floatmate_objetos.sp_aprobar_control(id,'TICKET-DEMO-BDOO');
 CALL floatmate_objetos.sp_iniciar_viaje(id,CURRENT_TIMESTAMP+interval '1 day');
END $$;
SELECT jsonb_pretty(floatmate_objetos.fn_viaje_json(oid)) FROM demo_bdoo_viaje;

-- SECCION 4: finalizar y comprobar que los OID originales permanecen.
DO $$
DECLARE id uuid; km numeric;
BEGIN
 SELECT oid INTO STRICT id FROM demo_bdoo_viaje;
 SELECT d.km+50 INTO km FROM demo_bdoo_recursos d;
 CALL floatmate_objetos.sp_cerrar_viaje(id,CURRENT_TIMESTAMP+interval '1 day 2 hours',km);
END $$;
SELECT v.oid,v.estado,(v.ficha).kilometraje FROM floatmate_objetos.vehiculo v
JOIN demo_bdoo_recursos d ON d.vehiculo=v.oid;
SELECT v.oid,v.estado FROM floatmate_objetos.viaje v JOIN demo_bdoo_viaje d USING(oid);
SELECT operacion,tabla,objeto_oid,anterior,nuevo FROM floatmate_objetos.auditoria
WHERE objeto_oid IN (SELECT oid FROM demo_bdoo_viaje) ORDER BY evento_id;

-- SECCION 5: demostrar que el OID no se puede modificar; el error queda capturado.
DO $$
BEGIN
 BEGIN
   UPDATE floatmate_objetos.viaje SET oid=gen_random_uuid() WHERE oid IN (SELECT oid FROM demo_bdoo_viaje);
 EXCEPTION WHEN raise_exception THEN RAISE NOTICE 'RECHAZO ESPERADO: %', SQLERRM;
 END;
END $$;

-- SECCION 6: revertir TODO el ensayo y salir de la transaccion.
ROLLBACK;
SELECT 'Demostracion finalizada: cambios revertidos y OID de la carga conservados.' AS resultado;
