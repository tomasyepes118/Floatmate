/* OPCIONAL. Solo NORTE > floatmate_norte. Requiere la federacion anterior funcionando.
   Proyecciones en vivo sobre floatmate_global; no crean copias ni OID persistentes de Sur.
   Sirve para mostrar que BDD (ubicacion) y BDOO (representacion) pueden coexistir. */
BEGIN;
DO $$
BEGIN
 IF to_regclass('floatmate_global.vehiculos') IS NULL OR to_regclass('floatmate_global.conductores') IS NULL THEN
   RAISE EXCEPTION 'Primero configure la federacion anterior y sus vistas globales; este archivo es opcional.';
 END IF;
END $$;
CREATE OR REPLACE VIEW floatmate_objetos.v_ficha_global_en_vivo AS
 SELECT v.terminal_codigo,v.vehiculo_id AS id_relacional,v.nodo_origen,v.placa,v.tipo,
   ROW(v.marca,v.modelo,v.capacidad_pasajeros,v.kilometraje,v.proximo_mantenimiento_km)::floatmate_objetos.t_ficha AS ficha,
   v.estado
 FROM floatmate_global.vehiculos v;
CREATE OR REPLACE VIEW floatmate_objetos.v_contacto_global_en_vivo AS
 SELECT c.terminal_codigo,c.conductor_id AS id_relacional,c.nodo_origen,
   concat_ws(' ',c.nombres,c.apellidos) AS nombre,
   ROW(c.telefono,NULL::text)::floatmate_objetos.t_contacto AS contacto,
   ROW(c.numero_licencia,c.categoria_licencia,c.licencia_vence)::floatmate_objetos.t_licencia AS licencia
 FROM floatmate_global.conductores c;
COMMIT;
SELECT terminal_codigo,nodo_origen,count(*) AS vehiculos
FROM floatmate_objetos.v_ficha_global_en_vivo GROUP BY terminal_codigo,nodo_origen;
SELECT terminal_codigo,placa,(ficha).marca,(ficha).capacidad
FROM floatmate_objetos.v_ficha_global_en_vivo ORDER BY terminal_codigo,placa;
/* Con los datos iniciales y FDW conectado: NOR=15, SUR=15.
   Estas vistas no federan los UUID del modulo de Sur: federan el modelo previo. */
