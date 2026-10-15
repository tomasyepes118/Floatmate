/* Cada consulta se puede seleccionar y ejecutar por separado.
   Norte > floatmate_norte > Query Tool. Solo consultas, sin modificaciones. */

-- 1. ESQUEMA: objetos de la actividad fuera de public.
SELECT table_schema,table_name,table_type FROM information_schema.tables
WHERE table_schema='floatmate_objetos' ORDER BY table_name;

-- 2. CLASE Y OBJETO: cada fila es una instancia persistente con OID propio.
SELECT * FROM floatmate_objetos.v_flota ORDER BY clase,placa;

-- 3. HERENCIA: SELECT sobre el padre incluye los hijos.
SELECT oid,placa,clase,tableoid::regclass AS tabla_fisica FROM floatmate_objetos.vehiculo ORDER BY placa;
SELECT count(*) AS total_con_hijos FROM floatmate_objetos.vehiculo;
SELECT count(*) AS solo_padre_abstracto FROM ONLY floatmate_objetos.vehiculo;
-- Esperado en la carga original: 15 y 0, respectivamente.

-- 4. EVIDENCIA TECNICA DE INHERITS: tres vinculos de hijo hacia padre.
SELECT p.relname AS superclase,h.relname AS subclase FROM pg_inherits i
JOIN pg_class p ON p.oid=i.inhparent JOIN pg_class h ON h.oid=i.inhrelid
JOIN pg_namespace n ON n.oid=p.relnamespace WHERE n.nspname='floatmate_objetos';

-- 5. TIPOS COMPUESTOS: un atributo agrupa varios datos tipados.
SELECT nombre,(contacto).telefono,(contacto).correo,(licencia).numero,(licencia).categoria,(licencia).vence
FROM floatmate_objetos.conductor ORDER BY nombre;
SELECT placa,(ficha).marca,(ficha).modelo,(ficha).capacidad,(ficha).kilometraje
FROM floatmate_objetos.vehiculo ORDER BY placa;

-- 6. COLECCIONES: cada ruta contiene un arreglo ordenado de paradas.
SELECT nombre,paradas,paradas[1] AS primera_parada,cardinality(paradas) AS numero_paradas
FROM floatmate_objetos.ruta ORDER BY nombre;
SELECT r.nombre,p.orden,p.parada FROM floatmate_objetos.ruta r
CROSS JOIN LATERAL unnest(r.paradas) WITH ORDINALITY AS p(parada,orden)
ORDER BY r.nombre,p.orden;

-- 7. IDENTIDAD: UUID del objeto y correspondencia con el ID anterior.
SELECT oid,id_relacional,terminal_codigo,clase,placa FROM floatmate_objetos.identidad_vehiculo ORDER BY id_relacional;
-- OID no es placa, no cambia al modificar estado y no es un OID del catalogo del motor.

-- 8. METODOS: mismo nombre y diferente comportamiento segun el tipo recibido.
SELECT floatmate_objetos.fn_describir(b),floatmate_objetos.fn_costo(b,10::numeric)
FROM floatmate_objetos.bus_urbano b;
SELECT floatmate_objetos.fn_describir(b),floatmate_objetos.fn_costo(b,10::numeric)
FROM floatmate_objetos.bus_intermunicipal b;
SELECT floatmate_objetos.fn_describir(b),floatmate_objetos.fn_costo(b,10::numeric)
FROM floatmate_objetos.microbus b;
SELECT * FROM floatmate_objetos.v_comportamiento ORDER BY clase,placa;
-- Costos ficticios por 10 km: urbano 14000; intermunicipal con aire 24000; microbus 10000.

-- 9. JSON: reconstruye el objeto completo y navega hacia objetos relacionados.
SELECT jsonb_pretty(floatmate_objetos.fn_viaje_json(oid)) AS objeto_completo
FROM floatmate_objetos.viaje ORDER BY id_relacional LIMIT 1;
SELECT oid,expediente->>'ticket' AS ticket,expediente->>'control_salida' AS control
FROM floatmate_objetos.viaje ORDER BY id_relacional;

-- 10. METODO COMUN DE MANTENIMIENTO.
SELECT placa,floatmate_objetos.fn_km_restantes(ficha::floatmate_objetos.t_ficha) AS km_restantes
FROM floatmate_objetos.vehiculo ORDER BY placa;

-- 11. AUDITORIA / PERSISTENCIA.
SELECT evento_id,fecha,usuario,tabla,operacion,objeto_oid FROM floatmate_objetos.auditoria
ORDER BY evento_id DESC LIMIT 20;
SELECT * FROM floatmate_objetos.instalacion;

-- 12. INVENTARIO DE METODOS Y TRIGGERS.
SELECT p.proname AS nombre,pg_get_function_identity_arguments(p.oid) AS parametros,
       CASE p.prokind WHEN 'p' THEN 'PROCEDIMIENTO' ELSE 'FUNCION' END AS tipo
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='floatmate_objetos' ORDER BY nombre,parametros;
-- Se usa pg_trigger: information_schema repite un trigger por cada evento INSERT/UPDATE/DELETE.
SELECT c.relname AS tabla,t.tgname AS trigger,pg_get_triggerdef(t.oid) AS definicion
FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='floatmate_objetos' AND NOT t.tgisinternal ORDER BY tabla,trigger;
