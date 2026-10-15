/* EJEMPLO ADICIONAL DE CREACION / CONSTRUCCION DE UN OBJETO NUEVO.
   Ejecutar completo en Norte > floatmate_norte. Termina con ROLLBACK.
   Usa placa de demostracion: si ZZZ998 ya existe, cambiela por una libre.
   Para guardar un objeto real se confirmaria la transaccion con COMMIT,
   despues de proporcionar sus datos reales y revisar el resultado. */
BEGIN;
DO $$
DECLARE id uuid;
BEGIN
 INSERT INTO floatmate_objetos.identidad_vehiculo(terminal_codigo,clase,placa)
 VALUES('NOR','BUS_URBANO','ZZZ998') RETURNING oid INTO id;
 INSERT INTO floatmate_objetos.bus_urbano(oid,terminal_codigo,placa,ficha,estado,equipamiento,puertas,accesible)
 VALUES(id,'NOR','ZZZ998',
   ROW('Marca de demostracion',2024::smallint,40::smallint,1000::numeric,10000::numeric)::floatmate_objetos.t_ficha,
   'DISPONIBLE',ARRAY['BOTIQUIN','EXTINTOR','GPS'],2,true);
 RAISE NOTICE 'Objeto creado temporalmente: UUID %',id;
END $$;
-- Debe incluir la nueva instancia, sus atributos y su comportamiento.
SELECT b.oid,b.placa,(b.ficha).capacidad,b.equipamiento,
 floatmate_objetos.fn_describir(b) AS descripcion,floatmate_objetos.fn_costo(b,10::numeric) AS costo
FROM floatmate_objetos.bus_urbano b WHERE placa='ZZZ998';
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK;
SELECT 'Objeto de demostracion revertido. La carga inicial se conserva.' AS resultado;
