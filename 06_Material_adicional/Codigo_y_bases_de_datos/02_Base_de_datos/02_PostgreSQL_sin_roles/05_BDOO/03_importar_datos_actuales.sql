/* En la misma base que 01 y 02. Importa una instantanea de datos locales.
   No modifica ni elimina datos de floatmate. No sincroniza cambios posteriores.
   Los atributos propios de cada subclase sin equivalente en el modelo previo
   toman valores DEFAULT de demostracion: no son datos verificados de la flota.
   Reejecutar este archivo conserva los UUID y no duplica la carga. */
BEGIN;
DO $$
BEGIN
 PERFORM 1 FROM floatmate_objetos.instalacion WHERE modulo='BDOO' FOR UPDATE;
 IF (SELECT datos_importados_en FROM floatmate_objetos.instalacion WHERE modulo='BDOO') IS NOT NULL THEN
   RAISE NOTICE 'La instantanea ya fue importada; conserva sus OID y no duplica los datos.';
   RETURN;
 END IF;
 INSERT INTO floatmate_objetos.identidad_vehiculo(terminal_codigo,id_relacional,clase,placa)
 SELECT terminal_codigo,vehiculo_id,tipo::floatmate_objetos.clase_vehiculo,placa
 FROM floatmate.vehiculos;
 INSERT INTO floatmate_objetos.bus_urbano(oid,terminal_codigo,clase,placa,ficha,estado)
 SELECT i.oid,v.terminal_codigo,i.clase,v.placa,
   ROW(v.marca,v.modelo,v.capacidad_pasajeros,v.kilometraje,v.proximo_mantenimiento_km)::floatmate_objetos.t_ficha,
   v.estado::floatmate_objetos.estado_vehiculo
 FROM floatmate.vehiculos v JOIN floatmate_objetos.identidad_vehiculo i
 ON i.id_relacional=v.vehiculo_id AND i.terminal_codigo=v.terminal_codigo WHERE v.tipo='BUS_URBANO';
 INSERT INTO floatmate_objetos.bus_intermunicipal(oid,terminal_codigo,clase,placa,ficha,estado)
 SELECT i.oid,v.terminal_codigo,i.clase,v.placa,
   ROW(v.marca,v.modelo,v.capacidad_pasajeros,v.kilometraje,v.proximo_mantenimiento_km)::floatmate_objetos.t_ficha,
   v.estado::floatmate_objetos.estado_vehiculo
 FROM floatmate.vehiculos v JOIN floatmate_objetos.identidad_vehiculo i
 ON i.id_relacional=v.vehiculo_id AND i.terminal_codigo=v.terminal_codigo WHERE v.tipo='BUS_INTERMUNICIPAL';
 INSERT INTO floatmate_objetos.microbus(oid,terminal_codigo,clase,placa,ficha,estado)
 SELECT i.oid,v.terminal_codigo,i.clase,v.placa,
   ROW(v.marca,v.modelo,v.capacidad_pasajeros,v.kilometraje,v.proximo_mantenimiento_km)::floatmate_objetos.t_ficha,
   v.estado::floatmate_objetos.estado_vehiculo
 FROM floatmate.vehiculos v JOIN floatmate_objetos.identidad_vehiculo i
 ON i.id_relacional=v.vehiculo_id AND i.terminal_codigo=v.terminal_codigo WHERE v.tipo='MICROBUS';
 INSERT INTO floatmate_objetos.conductor(terminal_codigo,id_relacional,documento,nombre,contacto,licencia,estado)
 SELECT terminal_codigo,conductor_id,documento,concat_ws(' ',nombres,apellidos),
   floatmate_objetos.fn_contacto(telefono,NULL),
   ROW(numero_licencia,categoria_licencia,licencia_vence)::floatmate_objetos.t_licencia,estado
 FROM floatmate.conductores;
 INSERT INTO floatmate_objetos.ruta(terminal_codigo,id_relacional,nombre,origen,destino,distancia_km,paradas,activa)
 SELECT terminal_codigo,ruta_id,nombre,origen,destino,distancia_km,ARRAY[origen,destino],activa FROM floatmate.rutas;
 INSERT INTO floatmate_objetos.viaje(terminal_codigo,id_relacional,vehiculo_oid,conductor_oid,ruta_oid,
   fecha_programada,fecha_salida,fecha_llegada,pasajeros,estado,expediente)
 SELECT v.terminal_codigo,v.viaje_id,ve.oid,c.oid,r.oid,
   v.fecha_hora_programada,v.fecha_hora_salida,v.fecha_hora_llegada,v.pasajeros,v.estado::floatmate_objetos.estado_viaje,
   jsonb_strip_nulls(jsonb_build_object('observaciones',v.observaciones,'control_salida',cs.resultado,'ticket',cs.numero_ticket))
 FROM floatmate.viajes v
 JOIN floatmate_objetos.identidad_vehiculo ve ON ve.id_relacional=v.vehiculo_id AND ve.terminal_codigo=v.terminal_codigo
 JOIN floatmate_objetos.conductor c ON c.id_relacional=v.conductor_id AND c.terminal_codigo=v.terminal_codigo
 JOIN floatmate_objetos.ruta r ON r.id_relacional=v.ruta_id AND r.terminal_codigo=v.terminal_codigo
 LEFT JOIN floatmate.controles_salida cs ON cs.viaje_id=v.viaje_id;
 INSERT INTO floatmate_objetos.mantenimiento(terminal_codigo,id_relacional,vehiculo_oid,tipo,fecha_ingreso,costo,detalle)
 SELECT m.terminal_codigo,m.mantenimiento_id,i.oid,m.tipo,m.fecha_ingreso,m.costo,
   jsonb_build_object('descripcion',m.descripcion,'proveedor',m.proveedor,'estado',m.estado,
                     'kilometraje',m.kilometraje,'fecha_salida',m.fecha_salida)
 FROM floatmate.mantenimientos m JOIN floatmate_objetos.identidad_vehiculo i
 ON i.id_relacional=m.vehiculo_id AND i.terminal_codigo=m.terminal_codigo;
 UPDATE floatmate_objetos.instalacion SET datos_importados_en=CURRENT_TIMESTAMP WHERE modulo='BDOO';
END $$;
COMMIT;
SELECT 'Vehiculos: superclase con hijos' AS clase,count(*) FROM floatmate_objetos.vehiculo
UNION ALL SELECT 'Bus urbano',count(*) FROM floatmate_objetos.bus_urbano
UNION ALL SELECT 'Bus intermunicipal',count(*) FROM floatmate_objetos.bus_intermunicipal
UNION ALL SELECT 'Microbus',count(*) FROM floatmate_objetos.microbus
UNION ALL SELECT 'Conductores',count(*) FROM floatmate_objetos.conductor
UNION ALL SELECT 'Rutas',count(*) FROM floatmate_objetos.ruta
UNION ALL SELECT 'Viajes',count(*) FROM floatmate_objetos.viaje
UNION ALL SELECT 'Mantenimientos',count(*) FROM floatmate_objetos.mantenimiento;
