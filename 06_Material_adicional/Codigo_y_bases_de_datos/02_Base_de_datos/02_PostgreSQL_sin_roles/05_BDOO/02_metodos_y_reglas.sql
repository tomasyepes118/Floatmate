/* Ejecutar completo en la MISMA base donde ejecuto 01.
   Se puede volver a ejecutar: reemplaza funciones y triggers del modulo. */
BEGIN;
CREATE OR REPLACE FUNCTION floatmate_objetos.fn_contacto(p_telefono text, p_correo text DEFAULT NULL)
RETURNS floatmate_objetos.d_contacto LANGUAGE sql IMMUTABLE
SET search_path TO pg_catalog AS $$
 SELECT ROW(p_telefono,p_correo)::floatmate_objetos.t_contacto::floatmate_objetos.d_contacto;
$$;

CREATE OR REPLACE FUNCTION floatmate_objetos.fn_km_restantes(p_ficha floatmate_objetos.t_ficha)
RETURNS numeric LANGUAGE sql IMMUTABLE STRICT SET search_path TO pg_catalog AS $$
 SELECT greatest((p_ficha).proximo_mantenimiento_km - (p_ficha).kilometraje, 0);
$$;

/* Sobrecarga: mismo nombre, diferentes tipos de objeto de entrada.
   Son funciones externas sobre tipos de fila, no metodos miembros de una clase. */
CREATE OR REPLACE FUNCTION floatmate_objetos.fn_describir(p_obj floatmate_objetos.bus_urbano)
RETURNS text LANGUAGE sql IMMUTABLE STRICT SET search_path TO pg_catalog AS $$
 SELECT format('Bus urbano %s: %s puertas; accesible: %s', (p_obj).placa, (p_obj).puertas, (p_obj).accesible);
$$;
CREATE OR REPLACE FUNCTION floatmate_objetos.fn_describir(p_obj floatmate_objetos.bus_intermunicipal)
RETURNS text LANGUAGE sql IMMUTABLE STRICT SET search_path TO pg_catalog AS $$
 SELECT format('Bus intermunicipal %s: bodega %s m3; aire: %s', (p_obj).placa, (p_obj).bodega_m3, (p_obj).aire_acondicionado);
$$;
CREATE OR REPLACE FUNCTION floatmate_objetos.fn_describir(p_obj floatmate_objetos.microbus)
RETURNS text LANGUAGE sql IMMUTABLE STRICT SET search_path TO pg_catalog AS $$
 SELECT format('Microbus %s: servicio especial: %s', (p_obj).placa, (p_obj).servicio_especial);
$$;
/* Tarifas ficticias COP/km para demostrar comportamiento por clase; no tarifas comerciales. */
CREATE OR REPLACE FUNCTION floatmate_objetos.fn_costo(p_obj floatmate_objetos.bus_urbano, p_km numeric)
RETURNS numeric LANGUAGE plpgsql IMMUTABLE STRICT SET search_path TO pg_catalog AS $$
BEGIN
 IF p_km <= 0 THEN RAISE EXCEPTION 'La distancia debe ser positiva'; END IF;
 RETURN round(p_km * 1400,2);
END $$;
CREATE OR REPLACE FUNCTION floatmate_objetos.fn_costo(p_obj floatmate_objetos.bus_intermunicipal, p_km numeric)
RETURNS numeric LANGUAGE plpgsql IMMUTABLE STRICT SET search_path TO pg_catalog AS $$
BEGIN
 IF p_km <= 0 THEN RAISE EXCEPTION 'La distancia debe ser positiva'; END IF;
 RETURN round(p_km * (2200 + CASE WHEN (p_obj).aire_acondicionado THEN 200 ELSE 0 END),2);
END $$;
CREATE OR REPLACE FUNCTION floatmate_objetos.fn_costo(p_obj floatmate_objetos.microbus, p_km numeric)
RETURNS numeric LANGUAGE plpgsql IMMUTABLE STRICT SET search_path TO pg_catalog AS $$
BEGIN
 IF p_km <= 0 THEN RAISE EXCEPTION 'La distancia debe ser positiva'; END IF;
 RETURN round(p_km * 1000,2);
END $$;

CREATE OR REPLACE FUNCTION floatmate_objetos.fn_vehiculo_json(p_oid uuid)
RETURNS jsonb LANGUAGE sql STABLE STRICT SET search_path TO pg_catalog AS $$
 SELECT to_jsonb(b) || jsonb_build_object('clase_fisica','bus_urbano', 'descripcion',floatmate_objetos.fn_describir(b))
 FROM floatmate_objetos.bus_urbano b WHERE b.oid=p_oid
 UNION ALL
 SELECT to_jsonb(b) || jsonb_build_object('clase_fisica','bus_intermunicipal', 'descripcion',floatmate_objetos.fn_describir(b))
 FROM floatmate_objetos.bus_intermunicipal b WHERE b.oid=p_oid
 UNION ALL
 SELECT to_jsonb(b) || jsonb_build_object('clase_fisica','microbus', 'descripcion',floatmate_objetos.fn_describir(b))
 FROM floatmate_objetos.microbus b WHERE b.oid=p_oid;
$$;
CREATE OR REPLACE FUNCTION floatmate_objetos.fn_viaje_json(p_oid uuid)
RETURNS jsonb LANGUAGE sql STABLE STRICT SET search_path TO pg_catalog AS $$
 SELECT to_jsonb(v) || jsonb_build_object(
   'vehiculo',floatmate_objetos.fn_vehiculo_json(v.vehiculo_oid),
   'conductor',to_jsonb(c),'ruta',to_jsonb(r))
 FROM floatmate_objetos.viaje v
 JOIN floatmate_objetos.conductor c ON c.oid=v.conductor_oid
 JOIN floatmate_objetos.ruta r ON r.oid=v.ruta_oid WHERE v.oid=p_oid;
$$;
CREATE OR REPLACE VIEW floatmate_objetos.v_flota AS
 SELECT v.oid,v.terminal_codigo,v.clase,v.placa,v.estado,
   (v.ficha).marca AS marca,(v.ficha).capacidad AS capacidad,
   (v.ficha).kilometraje AS kilometraje,
   floatmate_objetos.fn_km_restantes(v.ficha::floatmate_objetos.t_ficha) AS km_para_mantenimiento,
   v.tableoid::regclass::text AS clase_fisica
 FROM floatmate_objetos.vehiculo v;
CREATE OR REPLACE VIEW floatmate_objetos.v_comportamiento AS
 SELECT b.oid,b.placa,b.clase,floatmate_objetos.fn_describir(b) AS descripcion,
        floatmate_objetos.fn_costo(b,10::numeric) AS costo_demo_10_km FROM floatmate_objetos.bus_urbano b
 UNION ALL
 SELECT b.oid,b.placa,b.clase,floatmate_objetos.fn_describir(b),floatmate_objetos.fn_costo(b,10::numeric)
 FROM floatmate_objetos.bus_intermunicipal b
 UNION ALL
 SELECT b.oid,b.placa,b.clase,floatmate_objetos.fn_describir(b),floatmate_objetos.fn_costo(b,10::numeric)
 FROM floatmate_objetos.microbus b;

/* OID y correspondencia con la fuente son inmutables. */
CREATE OR REPLACE FUNCTION floatmate_objetos.fn_trg_identidad_inmutable()
RETURNS trigger LANGUAGE plpgsql SET search_path TO pg_catalog AS $$
BEGIN
 IF NEW.oid IS DISTINCT FROM OLD.oid THEN
   RAISE EXCEPTION 'El OID es inmutable: no puede cambiar la identidad del objeto';
 END IF;
 IF to_jsonb(NEW)->'id_relacional' IS DISTINCT FROM to_jsonb(OLD)->'id_relacional'
    OR NEW.terminal_codigo IS DISTINCT FROM OLD.terminal_codigo
    OR to_jsonb(NEW)->'clase' IS DISTINCT FROM to_jsonb(OLD)->'clase' THEN
   RAISE EXCEPTION 'No puede cambiar la terminal, clase o referencia de origen del objeto';
 END IF;
 RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION floatmate_objetos.fn_trg_padre_abstracto()
RETURNS trigger LANGUAGE plpgsql SET search_path TO pg_catalog AS $$
BEGIN
 RAISE EXCEPTION 'Vehiculo es la superclase abstracta: inserte en bus_urbano, bus_intermunicipal o microbus';
END $$;
DROP TRIGGER IF EXISTS tr_padre_abstracto ON floatmate_objetos.vehiculo;
CREATE TRIGGER tr_padre_abstracto BEFORE INSERT ON floatmate_objetos.vehiculo
 FOR EACH ROW EXECUTE FUNCTION floatmate_objetos.fn_trg_padre_abstracto();

/* Al COMMIT cada identidad debe tener exactamente una instancia de una subclase.
   Esta regla resuelve el problema de referenciar hijos de INHERITS. */
CREATE OR REPLACE FUNCTION floatmate_objetos.fn_trg_instancia_completa()
RETURNS trigger LANGUAGE plpgsql SET search_path TO pg_catalog AS $$
DECLARE id uuid; n bigint;
BEGIN
 id := CASE WHEN TG_OP='DELETE' THEN OLD.oid ELSE NEW.oid END;
 IF EXISTS(SELECT 1 FROM floatmate_objetos.identidad_vehiculo i WHERE i.oid=id) THEN
   SELECT count(*) INTO n FROM floatmate_objetos.vehiculo v WHERE v.oid=id;
   IF n <> 1 THEN RAISE EXCEPTION 'La identidad % debe tener exactamente una instancia; tiene %',id,n; END IF;
 END IF;
 RETURN NULL;
END $$;
CREATE OR REPLACE FUNCTION floatmate_objetos.fn_trg_auditar()
RETURNS trigger LANGUAGE plpgsql SET search_path TO pg_catalog AS $$
BEGIN
 INSERT INTO floatmate_objetos.auditoria(tabla,operacion,objeto_oid,anterior,nuevo)
 VALUES(TG_TABLE_NAME,TG_OP,CASE WHEN TG_OP='DELETE' THEN OLD.oid ELSE NEW.oid END,
        CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) END,
        CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) END);
 RETURN NULL;
END $$;
DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY['identidad_vehiculo','bus_urbano','bus_intermunicipal','microbus','conductor','ruta','viaje','mantenimiento'] LOOP
   EXECUTE format('DROP TRIGGER IF EXISTS tr_oid_inmutable ON floatmate_objetos.%I',t);
   EXECUTE format('CREATE TRIGGER tr_oid_inmutable BEFORE UPDATE ON floatmate_objetos.%I FOR EACH ROW EXECUTE FUNCTION floatmate_objetos.fn_trg_identidad_inmutable()',t);
   EXECUTE format('DROP TRIGGER IF EXISTS tr_auditoria ON floatmate_objetos.%I',t);
   EXECUTE format('CREATE TRIGGER tr_auditoria AFTER INSERT OR UPDATE OR DELETE ON floatmate_objetos.%I FOR EACH ROW EXECUTE FUNCTION floatmate_objetos.fn_trg_auditar()',t);
 END LOOP;
 FOREACH t IN ARRAY ARRAY['identidad_vehiculo','bus_urbano','bus_intermunicipal','microbus'] LOOP
   EXECUTE format('DROP TRIGGER IF EXISTS tr_instancia_completa ON floatmate_objetos.%I',t);
   EXECUTE format('CREATE CONSTRAINT TRIGGER tr_instancia_completa AFTER INSERT OR UPDATE OR DELETE ON floatmate_objetos.%I DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION floatmate_objetos.fn_trg_instancia_completa()',t);
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION floatmate_objetos.fn_trg_validar_viaje()
RETURNS trigger LANGUAGE plpgsql SET search_path TO pg_catalog AS $$
DECLARE v floatmate_objetos.vehiculo; c floatmate_objetos.conductor; r floatmate_objetos.ruta;
BEGIN
 SELECT b.* INTO v FROM floatmate_objetos.vehiculo b WHERE b.oid=NEW.vehiculo_oid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'No existe el objeto vehiculo'; END IF;
 SELECT b.* INTO c FROM floatmate_objetos.conductor b WHERE b.oid=NEW.conductor_oid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'No existe el objeto conductor'; END IF;
 SELECT b.* INTO r FROM floatmate_objetos.ruta b WHERE b.oid=NEW.ruta_oid;
 IF NOT FOUND THEN RAISE EXCEPTION 'No existe el objeto ruta'; END IF;
 IF NEW.terminal_codigo <> v.terminal_codigo OR NEW.terminal_codigo <> c.terminal_codigo OR NEW.terminal_codigo <> r.terminal_codigo THEN
   RAISE EXCEPTION 'Todos los objetos del viaje deben pertenecer a la misma terminal';
 END IF;
 IF NEW.pasajeros > (v.ficha).capacidad THEN RAISE EXCEPTION 'Pasajeros superan la capacidad del objeto vehiculo'; END IF;
 IF TG_OP='UPDATE' THEN
   IF OLD.estado IN ('EN_CURSO','FINALIZADO','CANCELADO') AND
     (NEW.vehiculo_oid,NEW.conductor_oid,NEW.ruta_oid,NEW.pasajeros,NEW.fecha_programada)
     IS DISTINCT FROM (OLD.vehiculo_oid,OLD.conductor_oid,OLD.ruta_oid,OLD.pasajeros,OLD.fecha_programada) THEN
     RAISE EXCEPTION 'No puede reasignar un viaje iniciado, finalizado o cancelado';
   END IF;
   IF NEW.estado IS DISTINCT FROM OLD.estado THEN
     IF NOT ((OLD.estado='PROGRAMADO' AND NEW.estado IN ('EN_CURSO','CANCELADO')) OR
             (OLD.estado='EN_CURSO' AND NEW.estado='FINALIZADO')) THEN
       RAISE EXCEPTION 'Transicion de estado no permitida: % -> %', OLD.estado, NEW.estado;
     END IF;
   END IF;
 END IF;
 IF NEW.estado='EN_CURSO' AND (TG_OP='INSERT' OR OLD.estado IS DISTINCT FROM NEW.estado) THEN
   IF v.estado <> 'DISPONIBLE' OR c.estado <> 'DISPONIBLE' OR NOT r.activa THEN
     RAISE EXCEPTION 'Vehiculo/conductor no disponible o ruta inactiva';
   END IF;
   IF (c.licencia).vence < NEW.fecha_salida::date THEN RAISE EXCEPTION 'Licencia vencida para la fecha de salida'; END IF;
   IF NEW.fecha_salida IS NULL OR NEW.expediente->>'control_salida' IS DISTINCT FROM 'APROBADO'
      OR coalesce(length(trim(NEW.expediente->>'ticket')),0)=0 THEN
     RAISE EXCEPTION 'Para iniciar necesita fecha de salida, control APROBADO y ticket';
   END IF;
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS tr_validar_viaje ON floatmate_objetos.viaje;
CREATE TRIGGER tr_validar_viaje BEFORE INSERT OR UPDATE ON floatmate_objetos.viaje
 FOR EACH ROW EXECUTE FUNCTION floatmate_objetos.fn_trg_validar_viaje();

CREATE OR REPLACE PROCEDURE floatmate_objetos.sp_programar_viaje(
 p_vehiculo uuid,p_conductor uuid,p_ruta uuid,p_fecha timestamptz,p_pasajeros smallint)
LANGUAGE plpgsql SET search_path TO pg_catalog AS $$
DECLARE v floatmate_objetos.vehiculo; c floatmate_objetos.conductor; r floatmate_objetos.ruta; id uuid;
BEGIN
 SELECT b.* INTO STRICT v FROM floatmate_objetos.vehiculo b WHERE b.oid=p_vehiculo FOR UPDATE;
 SELECT b.* INTO STRICT c FROM floatmate_objetos.conductor b WHERE b.oid=p_conductor FOR UPDATE;
 SELECT b.* INTO STRICT r FROM floatmate_objetos.ruta b WHERE b.oid=p_ruta;
 IF v.estado <> 'DISPONIBLE' OR c.estado <> 'DISPONIBLE' OR NOT r.activa THEN
   RAISE EXCEPTION 'Vehiculo/conductor no disponible o ruta inactiva';
 END IF;
 INSERT INTO floatmate_objetos.viaje(terminal_codigo,vehiculo_oid,conductor_oid,ruta_oid,fecha_programada,pasajeros)
 VALUES(v.terminal_codigo,p_vehiculo,p_conductor,p_ruta,p_fecha,p_pasajeros) RETURNING oid INTO id;
 RAISE NOTICE 'Objeto viaje creado: %',id;
EXCEPTION WHEN no_data_found THEN RAISE EXCEPTION 'No existe alguno de los objetos requeridos';
END $$;
CREATE OR REPLACE PROCEDURE floatmate_objetos.sp_aprobar_control(p_viaje uuid,p_ticket text)
LANGUAGE plpgsql SET search_path TO pg_catalog AS $$
BEGIN
 IF p_ticket IS NULL OR length(trim(p_ticket))=0 THEN RAISE EXCEPTION 'El ticket es obligatorio'; END IF;
 UPDATE floatmate_objetos.viaje SET expediente=expediente || jsonb_build_object('control_salida','APROBADO','ticket',p_ticket)
 WHERE oid=p_viaje AND estado='PROGRAMADO';
 IF NOT FOUND THEN RAISE EXCEPTION 'No existe un viaje PROGRAMADO con ese OID'; END IF;
END $$;
CREATE OR REPLACE PROCEDURE floatmate_objetos.sp_iniciar_viaje(p_viaje uuid,p_salida timestamptz)
LANGUAGE plpgsql SET search_path TO pg_catalog AS $$
DECLARE v floatmate_objetos.viaje;
BEGIN
 SELECT b.* INTO STRICT v FROM floatmate_objetos.viaje b WHERE b.oid=p_viaje FOR UPDATE;
 IF v.estado <> 'PROGRAMADO' THEN RAISE EXCEPTION 'El viaje debe estar PROGRAMADO'; END IF;
 UPDATE floatmate_objetos.viaje SET estado='EN_CURSO',fecha_salida=p_salida WHERE oid=p_viaje;
 UPDATE floatmate_objetos.vehiculo SET estado='EN_RUTA' WHERE oid=v.vehiculo_oid;
 UPDATE floatmate_objetos.conductor SET estado='EN_VIAJE' WHERE oid=v.conductor_oid;
EXCEPTION WHEN no_data_found THEN RAISE EXCEPTION 'No existe el objeto viaje';
END $$;
CREATE OR REPLACE PROCEDURE floatmate_objetos.sp_cerrar_viaje(p_viaje uuid,p_llegada timestamptz,p_km numeric)
LANGUAGE plpgsql SET search_path TO pg_catalog AS $$
DECLARE v floatmate_objetos.viaje; f floatmate_objetos.t_ficha;
BEGIN
 SELECT b.* INTO STRICT v FROM floatmate_objetos.viaje b WHERE b.oid=p_viaje FOR UPDATE;
 IF v.estado <> 'EN_CURSO' THEN RAISE EXCEPTION 'El viaje debe estar EN_CURSO'; END IF;
 SELECT (b.ficha).* INTO f FROM floatmate_objetos.vehiculo b WHERE b.oid=v.vehiculo_oid FOR UPDATE;
 IF p_km IS NULL OR p_km < f.kilometraje THEN RAISE EXCEPTION 'Kilometraje final invalido'; END IF;
 IF p_llegada IS NULL OR p_llegada < v.fecha_salida THEN RAISE EXCEPTION 'Fecha de llegada invalida'; END IF;
 UPDATE floatmate_objetos.viaje SET estado='FINALIZADO',fecha_llegada=p_llegada WHERE oid=p_viaje;
 UPDATE floatmate_objetos.vehiculo SET estado='DISPONIBLE',
   ficha=ROW(f.marca,f.modelo,f.capacidad,p_km,f.proximo_mantenimiento_km)::floatmate_objetos.t_ficha
 WHERE oid=v.vehiculo_oid;
 UPDATE floatmate_objetos.conductor SET estado='DISPONIBLE' WHERE oid=v.conductor_oid;
EXCEPTION WHEN no_data_found THEN RAISE EXCEPTION 'No existe el objeto viaje';
END $$;
COMMIT;
SELECT 'Metodos y reglas creados. Siga con 03_importar_datos_actuales.sql.' AS siguiente_paso;
