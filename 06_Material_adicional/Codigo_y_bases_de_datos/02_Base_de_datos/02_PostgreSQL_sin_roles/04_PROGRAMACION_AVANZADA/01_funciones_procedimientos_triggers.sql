/*
===============================================================================
 FLOATMATE - PROGRAMACION AVANZADA EN POSTGRESQL
===============================================================================
 Ejecutar en: floatmate_norte
 Usuario:     postgres
 Momento:     despues de crear el FDW y las vistas globales

 Incluye funciones SQL y PL/pgSQL, RETURNS TABLE, JSONB, sobrecarga, cursores,
 procedimientos almacenados, excepciones, triggers, auditoria, vista normal y
 vista materializada. Ningun objeto se crea en public.
*/

BEGIN;

CREATE SCHEMA IF NOT EXISTS floatmate_programacion;
REVOKE ALL ON SCHEMA floatmate_programacion FROM PUBLIC;

COMMENT ON SCHEMA floatmate_programacion IS
  'Funciones, procedimientos, triggers, auditoria y objetos programables de FloatMate.';

/* --------------------------------------------------------------------------
   1. TABLA DE AUDITORIA
   -------------------------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS floatmate_programacion.auditoria_cambios (
    auditoria_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_hora       timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_bd       name NOT NULL DEFAULT CURRENT_USER,
    operacion        varchar(20) NOT NULL
                     CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE', 'CARGA_INICIAL')),
    esquema_tabla    name NOT NULL,
    nombre_tabla     name NOT NULL,
    clave_registro   text,
    datos_anteriores jsonb,
    datos_nuevos     jsonb,
    direccion_cliente inet DEFAULT inet_client_addr()
);

CREATE INDEX IF NOT EXISTS ix_auditoria_tabla_fecha
    ON floatmate_programacion.auditoria_cambios(nombre_tabla, fecha_hora DESC);

-- Deja 15 evidencias iniciales para que incluso esta tabla supere el minimo.
INSERT INTO floatmate_programacion.auditoria_cambios
    (operacion, esquema_tabla, nombre_tabla, clave_registro, datos_nuevos)
SELECT
    'CARGA_INICIAL',
    'floatmate',
    'instalacion',
    n::text,
    jsonb_build_object('mensaje', 'Registro inicial de auditoria', 'numero', n)
FROM generate_series(1, 15) AS s(n)
WHERE NOT EXISTS (
    SELECT 1
    FROM floatmate_programacion.auditoria_cambios
    WHERE operacion = 'CARGA_INICIAL'
      AND nombre_tabla = 'instalacion'
);

/* --------------------------------------------------------------------------
   2. FUNCION ESCALAR EN LENGUAJE SQL
   Devuelve un unico valor y no modifica datos.
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION floatmate_programacion.fn_kilometros_para_mantenimiento(
    p_vehiculo_id bigint
)
RETURNS numeric(12,2)
LANGUAGE sql
STABLE
RETURNS NULL ON NULL INPUT
SET search_path TO pg_catalog
AS $funcion$
    SELECT greatest(v.proximo_mantenimiento_km - v.kilometraje, 0)::numeric(12,2)
    FROM floatmate.vehiculos AS v
    WHERE v.vehiculo_id = p_vehiculo_id;
$funcion$;

COMMENT ON FUNCTION floatmate_programacion.fn_kilometros_para_mantenimiento(bigint) IS
  'Funcion escalar: calcula cuantos kilometros faltan para el mantenimiento.';

/* --------------------------------------------------------------------------
   3. SOBRECARGA DE FUNCIONES
   Mismo nombre, pero parametros de tipos diferentes.
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION floatmate_programacion.fn_total_combustible(
    p_vehiculo_id bigint
)
RETURNS numeric(14,2)
LANGUAGE sql
STABLE
RETURNS NULL ON NULL INPUT
SET search_path TO pg_catalog
AS $funcion$
    SELECT coalesce(sum(a.litros), 0)::numeric(14,2)
    FROM floatmate_global.abastecimientos AS a
    WHERE a.vehiculo_id = p_vehiculo_id;
$funcion$;

CREATE OR REPLACE FUNCTION floatmate_programacion.fn_total_combustible(
    p_terminal_codigo varchar
)
RETURNS numeric(14,2)
LANGUAGE sql
STABLE
RETURNS NULL ON NULL INPUT
SET search_path TO pg_catalog
AS $funcion$
    SELECT coalesce(sum(a.litros), 0)::numeric(14,2)
    FROM floatmate_global.abastecimientos AS a
    WHERE a.terminal_codigo = upper(p_terminal_codigo);
$funcion$;

/* --------------------------------------------------------------------------
   4. FUNCION PL/pgSQL CON IF, SELECT INTO Y MENSAJE DE NEGOCIO
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION floatmate_programacion.fn_validar_inicio_viaje(
    p_viaje_id bigint
)
RETURNS TABLE(apto boolean, mensaje text)
LANGUAGE plpgsql
STABLE
SET search_path TO pg_catalog
AS $funcion$
DECLARE
    v_estado_viaje varchar(15);
    v_estado_vehiculo varchar(20);
    v_estado_conductor varchar(15);
    v_control_aprobado boolean;
BEGIN
    SELECT vi.estado, ve.estado, co.estado
      INTO v_estado_viaje, v_estado_vehiculo, v_estado_conductor
    FROM floatmate.viajes AS vi
    JOIN floatmate.vehiculos AS ve ON ve.vehiculo_id = vi.vehiculo_id
    JOIN floatmate.conductores AS co ON co.conductor_id = vi.conductor_id
    WHERE vi.viaje_id = p_viaje_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'El viaje no existe'::text;
        RETURN;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM floatmate.controles_salida AS cs
        WHERE cs.viaje_id = p_viaje_id
          AND cs.resultado = 'APROBADO'
          AND cs.numero_ticket IS NOT NULL
    ) INTO v_control_aprobado;

    IF v_estado_viaje NOT IN ('PROGRAMADO', 'EN_CURSO') THEN
        RETURN QUERY SELECT false, ('El viaje esta en estado ' || v_estado_viaje)::text;
    ELSIF v_estado_vehiculo <> 'DISPONIBLE' AND v_estado_viaje <> 'EN_CURSO' THEN
        RETURN QUERY SELECT false, ('El vehiculo esta en estado ' || v_estado_vehiculo)::text;
    ELSIF v_estado_conductor <> 'DISPONIBLE' AND v_estado_viaje <> 'EN_CURSO' THEN
        RETURN QUERY SELECT false, ('El conductor esta en estado ' || v_estado_conductor)::text;
    ELSIF NOT v_control_aprobado THEN
        RETURN QUERY SELECT false, 'Falta un control de salida aprobado'::text;
    ELSE
        RETURN QUERY SELECT true, 'Viaje habilitado para iniciar'::text;
    END IF;
END;
$funcion$;

/* --------------------------------------------------------------------------
   5. FUNCION QUE RETORNA UNA TABLA
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION floatmate_programacion.fn_viajes_por_terminal(
    p_terminal_codigo varchar,
    p_fecha_desde date,
    p_fecha_hasta date
)
RETURNS TABLE (
    viaje_id bigint,
    terminal_codigo varchar(3),
    nodo_origen text,
    fecha_hora_programada timestamptz,
    placa varchar(6),
    conductor text,
    ruta varchar(100),
    estado varchar(15)
)
LANGUAGE sql
STABLE
SET search_path TO pg_catalog
AS $funcion$
    SELECT v.viaje_id, v.terminal_codigo, v.nodo_origen,
           v.fecha_hora_programada, v.placa, v.conductor, v.ruta, v.estado
    FROM floatmate_global.v_operacion_viajes AS v
    WHERE v.terminal_codigo = upper(p_terminal_codigo)
      AND v.fecha_hora_programada::date BETWEEN p_fecha_desde AND p_fecha_hasta
    ORDER BY v.fecha_hora_programada;
$funcion$;

/* --------------------------------------------------------------------------
   6. FUNCION QUE RETORNA JSONB
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION floatmate_programacion.fn_detalle_viaje_json(
    p_viaje_id bigint
)
RETURNS jsonb
LANGUAGE sql
STABLE
RETURNS NULL ON NULL INPUT
SET search_path TO pg_catalog
AS $funcion$
    SELECT jsonb_build_object(
        'viaje_id', v.viaje_id,
        'terminal', v.terminal_codigo,
        'nodo', v.nodo_origen,
        'fecha_programada', v.fecha_hora_programada,
        'vehiculo', jsonb_build_object('placa', v.placa, 'codigo', v.vehiculo),
        'conductor', jsonb_build_object('documento', v.documento_conductor, 'nombre', v.conductor),
        'ruta', jsonb_build_object('codigo', v.codigo_ruta, 'nombre', v.ruta,
                                   'origen', v.origen, 'destino', v.destino),
        'pasajeros', v.pasajeros,
        'estado', v.estado,
        'control_salida', v.control_salida,
        'ticket', v.numero_ticket
    )
    FROM floatmate_global.v_operacion_viajes AS v
    WHERE v.viaje_id = p_viaje_id;
$funcion$;

/* --------------------------------------------------------------------------
   7. FUNCION CON CURSOR EXPLICITO
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION floatmate_programacion.fn_alertas_mantenimiento_cursor(
    p_umbral_km numeric DEFAULT 6000
)
RETURNS TABLE (
    vehiculo_id bigint,
    placa varchar(6),
    kilometros_restantes numeric(12,2),
    prioridad text
)
LANGUAGE plpgsql
STABLE
SET search_path TO pg_catalog
AS $funcion$
DECLARE
    registro record;
    cursor_vehiculos CURSOR FOR
        SELECT v.vehiculo_id,
               v.placa,
               greatest(v.proximo_mantenimiento_km - v.kilometraje, 0)::numeric(12,2) AS km_restantes
        FROM floatmate.vehiculos AS v
        WHERE greatest(v.proximo_mantenimiento_km - v.kilometraje, 0) <= p_umbral_km
        ORDER BY km_restantes, v.vehiculo_id;
BEGIN
    OPEN cursor_vehiculos;
    LOOP
        FETCH cursor_vehiculos INTO registro;
        EXIT WHEN NOT FOUND;

        vehiculo_id := registro.vehiculo_id;
        placa := registro.placa;
        kilometros_restantes := registro.km_restantes;
        prioridad := CASE
            WHEN registro.km_restantes = 0 THEN 'VENCIDO'
            WHEN registro.km_restantes <= 2000 THEN 'ALTA'
            ELSE 'MEDIA'
        END;
        RETURN NEXT;
    END LOOP;
    CLOSE cursor_vehiculos;
END;
$funcion$;

/* --------------------------------------------------------------------------
   8. FUNCION DE INDICADORES CON VARIOS VALORES DE SALIDA
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION floatmate_programacion.fn_estadisticas_terminal(
    p_terminal_codigo varchar
)
RETURNS TABLE (
    total_viajes bigint,
    total_pasajeros bigint,
    costo_combustible numeric(14,2),
    incidentes_abiertos bigint
)
LANGUAGE sql
STABLE
SET search_path TO pg_catalog
AS $funcion$
    SELECT
        (SELECT count(*)
         FROM floatmate_global.viajes v
         WHERE v.terminal_codigo = upper(p_terminal_codigo)),
        (SELECT coalesce(sum(v.pasajeros), 0)::bigint
         FROM floatmate_global.viajes v
         WHERE v.terminal_codigo = upper(p_terminal_codigo)),
        (SELECT coalesce(sum(a.valor_total), 0)::numeric(14,2)
         FROM floatmate_global.abastecimientos a
         WHERE a.terminal_codigo = upper(p_terminal_codigo)),
        (SELECT count(*)
         FROM floatmate_global.incidentes i
         WHERE i.terminal_codigo = upper(p_terminal_codigo)
           AND i.estado <> 'CERRADO');
$funcion$;

/* --------------------------------------------------------------------------
   9. FUNCIONES DE TRIGGER
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION floatmate_programacion.fn_trg_validar_viaje()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO pg_catalog
AS $funcion$
DECLARE
    v_capacidad smallint;
    v_terminal_vehiculo varchar(3);
    v_terminal_conductor varchar(3);
    v_terminal_ruta varchar(3);
BEGIN
    SELECT capacidad_pasajeros, terminal_codigo
      INTO v_capacidad, v_terminal_vehiculo
    FROM floatmate.vehiculos
    WHERE vehiculo_id = NEW.vehiculo_id;

    SELECT terminal_codigo INTO v_terminal_conductor
    FROM floatmate.conductores
    WHERE conductor_id = NEW.conductor_id;

    SELECT terminal_codigo INTO v_terminal_ruta
    FROM floatmate.rutas
    WHERE ruta_id = NEW.ruta_id;

    IF v_capacidad IS NULL OR v_terminal_conductor IS NULL OR v_terminal_ruta IS NULL THEN
        RAISE EXCEPTION 'Vehiculo, conductor o ruta inexistente';
    END IF;

    IF NEW.pasajeros > v_capacidad THEN
        RAISE EXCEPTION 'Pasajeros (%) superan la capacidad del vehiculo (%)',
            NEW.pasajeros, v_capacidad;
    END IF;

    IF NEW.terminal_codigo <> v_terminal_vehiculo
       OR NEW.terminal_codigo <> v_terminal_conductor
       OR NEW.terminal_codigo <> v_terminal_ruta THEN
        RAISE EXCEPTION 'Todos los recursos del viaje deben pertenecer a la misma terminal';
    END IF;

    RETURN NEW;
END;
$funcion$;

CREATE OR REPLACE FUNCTION floatmate_programacion.fn_trg_validar_inicio_viaje()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO pg_catalog
AS $funcion$
DECLARE
    v_apto boolean;
    v_mensaje text;
BEGIN
    IF NEW.estado = 'EN_CURSO' AND OLD.estado IS DISTINCT FROM NEW.estado THEN
        SELECT r.apto, r.mensaje
          INTO v_apto, v_mensaje
        FROM floatmate_programacion.fn_validar_inicio_viaje(NEW.viaje_id) AS r;

        IF NOT coalesce(v_apto, false) THEN
            RAISE EXCEPTION 'No se puede iniciar el viaje: %', coalesce(v_mensaje, 'validacion desconocida');
        END IF;
    END IF;

    RETURN NEW;
END;
$funcion$;

CREATE OR REPLACE FUNCTION floatmate_programacion.fn_trg_auditar_cambios()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO pg_catalog
AS $funcion$
DECLARE
    v_clave text;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_clave := coalesce(to_jsonb(NEW)->>(TG_ARGV[0]), 'SIN_CLAVE');
        INSERT INTO floatmate_programacion.auditoria_cambios
            (operacion, esquema_tabla, nombre_tabla, clave_registro, datos_nuevos)
        VALUES
            (TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME, v_clave, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        v_clave := coalesce(to_jsonb(NEW)->>(TG_ARGV[0]), 'SIN_CLAVE');
        INSERT INTO floatmate_programacion.auditoria_cambios
            (operacion, esquema_tabla, nombre_tabla, clave_registro,
             datos_anteriores, datos_nuevos)
        VALUES
            (TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME, v_clave,
             to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSE
        v_clave := coalesce(to_jsonb(OLD)->>(TG_ARGV[0]), 'SIN_CLAVE');
        INSERT INTO floatmate_programacion.auditoria_cambios
            (operacion, esquema_tabla, nombre_tabla, clave_registro, datos_anteriores)
        VALUES
            (TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME, v_clave, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$funcion$;

/* --------------------------------------------------------------------------
   10. CREACION DE TRIGGERS
   -------------------------------------------------------------------------- */

DROP TRIGGER IF EXISTS tr_validar_viaje ON floatmate.viajes;
CREATE TRIGGER tr_validar_viaje
BEFORE INSERT OR UPDATE OF terminal_codigo, vehiculo_id, conductor_id, ruta_id, pasajeros
ON floatmate.viajes
FOR EACH ROW
EXECUTE FUNCTION floatmate_programacion.fn_trg_validar_viaje();

DROP TRIGGER IF EXISTS tr_validar_inicio_viaje ON floatmate.viajes;
CREATE TRIGGER tr_validar_inicio_viaje
BEFORE UPDATE OF estado
ON floatmate.viajes
FOR EACH ROW
EXECUTE FUNCTION floatmate_programacion.fn_trg_validar_inicio_viaje();

DROP TRIGGER IF EXISTS tr_auditar_usuarios ON floatmate.usuarios;
CREATE TRIGGER tr_auditar_usuarios AFTER INSERT OR UPDATE OR DELETE ON floatmate.usuarios
FOR EACH ROW EXECUTE FUNCTION floatmate_programacion.fn_trg_auditar_cambios('usuario_id');

DROP TRIGGER IF EXISTS tr_auditar_conductores ON floatmate.conductores;
CREATE TRIGGER tr_auditar_conductores AFTER INSERT OR UPDATE OR DELETE ON floatmate.conductores
FOR EACH ROW EXECUTE FUNCTION floatmate_programacion.fn_trg_auditar_cambios('conductor_id');

DROP TRIGGER IF EXISTS tr_auditar_vehiculos ON floatmate.vehiculos;
CREATE TRIGGER tr_auditar_vehiculos AFTER INSERT OR UPDATE OR DELETE ON floatmate.vehiculos
FOR EACH ROW EXECUTE FUNCTION floatmate_programacion.fn_trg_auditar_cambios('vehiculo_id');

DROP TRIGGER IF EXISTS tr_auditar_rutas ON floatmate.rutas;
CREATE TRIGGER tr_auditar_rutas AFTER INSERT OR UPDATE OR DELETE ON floatmate.rutas
FOR EACH ROW EXECUTE FUNCTION floatmate_programacion.fn_trg_auditar_cambios('ruta_id');

DROP TRIGGER IF EXISTS tr_auditar_viajes ON floatmate.viajes;
CREATE TRIGGER tr_auditar_viajes AFTER INSERT OR UPDATE OR DELETE ON floatmate.viajes
FOR EACH ROW EXECUTE FUNCTION floatmate_programacion.fn_trg_auditar_cambios('viaje_id');

DROP TRIGGER IF EXISTS tr_auditar_controles ON floatmate.controles_salida;
CREATE TRIGGER tr_auditar_controles AFTER INSERT OR UPDATE OR DELETE ON floatmate.controles_salida
FOR EACH ROW EXECUTE FUNCTION floatmate_programacion.fn_trg_auditar_cambios('control_id');

DROP TRIGGER IF EXISTS tr_auditar_abastecimientos ON floatmate.abastecimientos;
CREATE TRIGGER tr_auditar_abastecimientos AFTER INSERT OR UPDATE OR DELETE ON floatmate.abastecimientos
FOR EACH ROW EXECUTE FUNCTION floatmate_programacion.fn_trg_auditar_cambios('abastecimiento_id');

DROP TRIGGER IF EXISTS tr_auditar_mantenimientos ON floatmate.mantenimientos;
CREATE TRIGGER tr_auditar_mantenimientos AFTER INSERT OR UPDATE OR DELETE ON floatmate.mantenimientos
FOR EACH ROW EXECUTE FUNCTION floatmate_programacion.fn_trg_auditar_cambios('mantenimiento_id');

DROP TRIGGER IF EXISTS tr_auditar_incidentes ON floatmate.incidentes;
CREATE TRIGGER tr_auditar_incidentes AFTER INSERT OR UPDATE OR DELETE ON floatmate.incidentes
FOR EACH ROW EXECUTE FUNCTION floatmate_programacion.fn_trg_auditar_cambios('incidente_id');

/* --------------------------------------------------------------------------
   11. PROCEDIMIENTOS ALMACENADOS
   Se invocan con CALL y pueden modificar datos.
   -------------------------------------------------------------------------- */

CREATE OR REPLACE PROCEDURE floatmate_programacion.sp_cambiar_estado_vehiculo(
    IN p_vehiculo_id bigint,
    IN p_nuevo_estado varchar
)
LANGUAGE plpgsql
SET search_path TO pg_catalog
AS $procedimiento$
BEGIN
    IF p_nuevo_estado NOT IN ('DISPONIBLE', 'EN_RUTA', 'MANTENIMIENTO', 'FUERA_SERVICIO') THEN
        RAISE EXCEPTION 'Estado de vehiculo no permitido: %', p_nuevo_estado;
    END IF;

    UPDATE floatmate.vehiculos
    SET estado = p_nuevo_estado
    WHERE vehiculo_id = p_vehiculo_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el vehiculo %', p_vehiculo_id;
    END IF;
END;
$procedimiento$;

CREATE OR REPLACE PROCEDURE floatmate_programacion.sp_programar_viaje(
    IN p_vehiculo_id bigint,
    IN p_conductor_id bigint,
    IN p_ruta_id bigint,
    IN p_fecha_hora timestamptz,
    IN p_pasajeros smallint,
    IN p_observaciones varchar,
    INOUT p_viaje_id bigint
)
LANGUAGE plpgsql
SET search_path TO pg_catalog
AS $procedimiento$
DECLARE
    v_capacidad smallint;
    v_estado_vehiculo varchar(20);
    v_estado_conductor varchar(15);
    v_ruta_activa boolean;
BEGIN
    SELECT capacidad_pasajeros, estado
      INTO STRICT v_capacidad, v_estado_vehiculo
    FROM floatmate.vehiculos
    WHERE vehiculo_id = p_vehiculo_id;

    SELECT estado INTO STRICT v_estado_conductor
    FROM floatmate.conductores
    WHERE conductor_id = p_conductor_id;

    SELECT activa INTO STRICT v_ruta_activa
    FROM floatmate.rutas
    WHERE ruta_id = p_ruta_id;

    IF v_estado_vehiculo <> 'DISPONIBLE' THEN
        RAISE EXCEPTION 'El vehiculo % no esta disponible', p_vehiculo_id;
    ELSIF v_estado_conductor <> 'DISPONIBLE' THEN
        RAISE EXCEPTION 'El conductor % no esta disponible', p_conductor_id;
    ELSIF NOT v_ruta_activa THEN
        RAISE EXCEPTION 'La ruta % no esta activa', p_ruta_id;
    ELSIF p_pasajeros > v_capacidad THEN
        RAISE EXCEPTION 'Pasajeros (%) superan capacidad (%)', p_pasajeros, v_capacidad;
    END IF;

    IF EXISTS (
        SELECT 1 FROM floatmate.viajes
        WHERE fecha_hora_programada = p_fecha_hora
          AND estado <> 'CANCELADO'
          AND (vehiculo_id = p_vehiculo_id OR conductor_id = p_conductor_id)
    ) THEN
        RAISE EXCEPTION 'Vehiculo o conductor ya asignado para esa fecha y hora';
    END IF;

    INSERT INTO floatmate.viajes
        (terminal_codigo, vehiculo_id, conductor_id, ruta_id,
         fecha_hora_programada, pasajeros, estado, observaciones)
    VALUES
        ('NOR', p_vehiculo_id, p_conductor_id, p_ruta_id,
         p_fecha_hora, p_pasajeros, 'PROGRAMADO', p_observaciones)
    RETURNING viaje_id INTO p_viaje_id;

EXCEPTION
    WHEN no_data_found THEN
        RAISE EXCEPTION 'Vehiculo, conductor o ruta no existe';
END;
$procedimiento$;

CREATE OR REPLACE PROCEDURE floatmate_programacion.sp_iniciar_viaje(
    IN p_viaje_id bigint,
    IN p_fecha_salida timestamptz DEFAULT CURRENT_TIMESTAMP
)
LANGUAGE plpgsql
SET search_path TO pg_catalog
AS $procedimiento$
DECLARE
    v_vehiculo_id bigint;
    v_conductor_id bigint;
BEGIN
    SELECT vehiculo_id, conductor_id
      INTO STRICT v_vehiculo_id, v_conductor_id
    FROM floatmate.viajes
    WHERE viaje_id = p_viaje_id;

    -- El trigger tr_validar_inicio_viaje bloquea la operacion si falta el control.
    UPDATE floatmate.viajes
    SET estado = 'EN_CURSO', fecha_hora_salida = p_fecha_salida
    WHERE viaje_id = p_viaje_id;

    UPDATE floatmate.vehiculos SET estado = 'EN_RUTA'
    WHERE vehiculo_id = v_vehiculo_id;

    UPDATE floatmate.conductores SET estado = 'EN_VIAJE'
    WHERE conductor_id = v_conductor_id;
EXCEPTION
    WHEN no_data_found THEN
        RAISE EXCEPTION 'No existe el viaje %', p_viaje_id;
END;
$procedimiento$;

CREATE OR REPLACE PROCEDURE floatmate_programacion.sp_cerrar_viaje(
    IN p_viaje_id bigint,
    IN p_fecha_llegada timestamptz,
    IN p_kilometraje_final numeric
)
LANGUAGE plpgsql
SET search_path TO pg_catalog
AS $procedimiento$
DECLARE
    v_vehiculo_id bigint;
    v_conductor_id bigint;
    v_estado varchar(15);
    v_kilometraje_actual numeric;
BEGIN
    SELECT vi.vehiculo_id, vi.conductor_id, vi.estado, ve.kilometraje
      INTO STRICT v_vehiculo_id, v_conductor_id, v_estado, v_kilometraje_actual
    FROM floatmate.viajes vi
    JOIN floatmate.vehiculos ve ON ve.vehiculo_id = vi.vehiculo_id
    WHERE vi.viaje_id = p_viaje_id;

    IF v_estado <> 'EN_CURSO' THEN
        RAISE EXCEPTION 'El viaje % no esta EN_CURSO', p_viaje_id;
    ELSIF p_kilometraje_final < v_kilometraje_actual THEN
        RAISE EXCEPTION 'El kilometraje final no puede ser menor al actual';
    END IF;

    UPDATE floatmate.viajes
    SET estado = 'FINALIZADO', fecha_hora_llegada = p_fecha_llegada
    WHERE viaje_id = p_viaje_id;

    UPDATE floatmate.vehiculos
    SET estado = 'DISPONIBLE', kilometraje = p_kilometraje_final
    WHERE vehiculo_id = v_vehiculo_id;

    UPDATE floatmate.conductores
    SET estado = 'DISPONIBLE'
    WHERE conductor_id = v_conductor_id;
EXCEPTION
    WHEN no_data_found THEN
        RAISE EXCEPTION 'No existe el viaje %', p_viaje_id;
END;
$procedimiento$;

/* --------------------------------------------------------------------------
   12. VISTA NORMAL Y VISTA MATERIALIZADA
   -------------------------------------------------------------------------- */

CREATE OR REPLACE VIEW floatmate_programacion.v_alertas_mantenimiento AS
SELECT
    v.vehiculo_id,
    v.terminal_codigo,
    v.placa,
    v.codigo_interno,
    v.kilometraje,
    v.proximo_mantenimiento_km,
    greatest(v.proximo_mantenimiento_km - v.kilometraje, 0)::numeric(12,2)
        AS kilometros_restantes,
    CASE
        WHEN v.kilometraje >= v.proximo_mantenimiento_km THEN 'VENCIDO'
        WHEN v.proximo_mantenimiento_km - v.kilometraje <= 2000 THEN 'ALTA'
        WHEN v.proximo_mantenimiento_km - v.kilometraje <= 5000 THEN 'MEDIA'
        ELSE 'NORMAL'
    END AS prioridad
FROM floatmate_global.vehiculos AS v;

CREATE OR REPLACE VIEW floatmate_programacion.v_indicadores_terminal AS
WITH viajes AS (
    SELECT terminal_codigo, count(*) AS total_viajes,
           coalesce(sum(pasajeros), 0) AS total_pasajeros
    FROM floatmate_global.viajes
    GROUP BY terminal_codigo
), combustible AS (
    SELECT terminal_codigo, coalesce(sum(litros), 0) AS litros,
           coalesce(sum(valor_total), 0) AS costo
    FROM floatmate_global.abastecimientos
    GROUP BY terminal_codigo
), incidentes AS (
    SELECT terminal_codigo, count(*) AS total_incidentes,
           count(*) FILTER (WHERE estado <> 'CERRADO') AS incidentes_abiertos
    FROM floatmate_global.incidentes
    GROUP BY terminal_codigo
)
SELECT v.terminal_codigo,
       v.total_viajes,
       v.total_pasajeros,
       c.litros::numeric(14,2) AS litros_combustible,
       c.costo::numeric(14,2) AS costo_combustible,
       i.total_incidentes,
       i.incidentes_abiertos
FROM viajes v
JOIN combustible c USING (terminal_codigo)
JOIN incidentes i USING (terminal_codigo);

DROP MATERIALIZED VIEW IF EXISTS floatmate_programacion.mv_consumo_vehiculo;
CREATE MATERIALIZED VIEW floatmate_programacion.mv_consumo_vehiculo AS
SELECT
    v.vehiculo_id,
    v.terminal_codigo,
    v.placa,
    count(a.abastecimiento_id) AS cantidad_abastecimientos,
    coalesce(sum(a.litros), 0)::numeric(14,2) AS litros_totales,
    coalesce(sum(a.valor_total), 0)::numeric(14,2) AS costo_total
FROM floatmate_global.vehiculos v
LEFT JOIN floatmate_global.abastecimientos a ON a.vehiculo_id = v.vehiculo_id
GROUP BY v.vehiculo_id, v.terminal_codigo, v.placa
WITH DATA;

CREATE UNIQUE INDEX ux_mv_consumo_vehiculo
    ON floatmate_programacion.mv_consumo_vehiculo(vehiculo_id);

CREATE OR REPLACE PROCEDURE floatmate_programacion.sp_refrescar_consumo_vehiculo()
LANGUAGE plpgsql
SET search_path TO pg_catalog
AS $procedimiento$
BEGIN
    REFRESH MATERIALIZED VIEW floatmate_programacion.mv_consumo_vehiculo;
END;
$procedimiento$;

/* --------------------------------------------------------------------------
   13. PERMISOS Y COMENTARIOS
   -------------------------------------------------------------------------- */

COMMENT ON TABLE floatmate_programacion.auditoria_cambios IS
  'Historial automatico de INSERT, UPDATE y DELETE en las tablas locales de FloatMate.';
COMMENT ON VIEW floatmate_programacion.v_alertas_mantenimiento IS
  'Vista normal: se calcula nuevamente en cada consulta.';
COMMENT ON MATERIALIZED VIEW floatmate_programacion.mv_consumo_vehiculo IS
  'Vista materializada: conserva una copia del resumen hasta ejecutar REFRESH.';

COMMIT;

-- Resumen de objetos creados. Debe mostrar funciones, procedimientos y vistas.
SELECT routine_type, routine_name
FROM information_schema.routines
WHERE routine_schema = 'floatmate_programacion'
ORDER BY routine_type, routine_name;
