/*
 FLOATMATE - PRUEBAS DE FUNCIONES, PROCEDIMIENTOS Y TRIGGERS
 Ejecutar en floatmate_norte despues de 01_todo_funciones_procedimientos_triggers.sql.
 Las pruebas que modifican datos terminan con ROLLBACK y no alteran la entrega.
*/

/* 1. Catalogo de funciones y procedimientos almacenados. */
SELECT
    n.nspname AS esquema,
    p.proname AS objeto,
    CASE p.prokind WHEN 'f' THEN 'FUNCION' WHEN 'p' THEN 'PROCEDIMIENTO' END AS tipo,
    pg_get_function_identity_arguments(p.oid) AS parametros,
    pg_get_function_result(p.oid) AS retorno
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'floatmate_programacion'
  AND p.prokind IN ('f', 'p')
ORDER BY tipo, objeto, parametros;

/* 2. Funcion escalar. */
SELECT floatmate_programacion.fn_kilometros_para_mantenimiento(1001)
       AS kilometros_restantes_vehiculo_1001;

/* 3. Sobrecarga: mismo nombre con bigint y con varchar. */
SELECT floatmate_programacion.fn_total_combustible(1001::bigint)
       AS litros_vehiculo_1001;

SELECT floatmate_programacion.fn_total_combustible('NOR'::varchar)
       AS litros_terminal_norte;

/* 4. Funcion PL/pgSQL con validaciones de negocio. */
SELECT *
FROM floatmate_programacion.fn_validar_inicio_viaje(1001);

/* 5. Funcion que retorna una tabla. */
SELECT *
FROM floatmate_programacion.fn_viajes_por_terminal(
    'SUR', date '2026-09-01', date '2026-09-30'
);

/* 6. Funcion que retorna JSONB. */
SELECT jsonb_pretty(floatmate_programacion.fn_detalle_viaje_json(2001))
       AS viaje_en_json;

/* 7. Funcion con cursor explicito. */
SELECT *
FROM floatmate_programacion.fn_alertas_mantenimiento_cursor(6000);

/* 8. Funcion con varios valores de salida. */
SELECT *
FROM floatmate_programacion.fn_estadisticas_terminal('NOR');

SELECT *
FROM floatmate_programacion.fn_estadisticas_terminal('SUR');

/* 9. Vista normal. */
SELECT *
FROM floatmate_programacion.v_alertas_mantenimiento
ORDER BY prioridad, kilometros_restantes;

/* 10. Vista de indicadores. */
SELECT *
FROM floatmate_programacion.v_indicadores_terminal
ORDER BY terminal_codigo;

/* 11. Vista materializada y procedimiento de refresco. */
CALL floatmate_programacion.sp_refrescar_consumo_vehiculo();

SELECT *
FROM floatmate_programacion.mv_consumo_vehiculo
ORDER BY terminal_codigo, vehiculo_id;

/* 12. Catalogo de triggers instalados. */
SELECT
    event_object_schema AS esquema,
    event_object_table AS tabla,
    trigger_name,
    event_manipulation AS evento,
    action_timing AS momento
FROM information_schema.triggers
WHERE action_statement ILIKE '%floatmate_programacion%'
ORDER BY tabla, trigger_name, evento;

/* 13. Demostracion segura de un procedimiento y del trigger de auditoria. */
BEGIN;

CALL floatmate_programacion.sp_cambiar_estado_vehiculo(1001, 'MANTENIMIENTO');

SELECT vehiculo_id, placa, estado
FROM floatmate.vehiculos
WHERE vehiculo_id = 1001;

SELECT operacion, nombre_tabla, clave_registro, datos_anteriores, datos_nuevos
FROM floatmate_programacion.auditoria_cambios
WHERE nombre_tabla = 'vehiculos' AND clave_registro = '1001'
ORDER BY auditoria_id DESC
LIMIT 1;

ROLLBACK;

/* 14. Flujo completo programar -> controlar -> iniciar -> cerrar.
       Todo ocurre dentro de una transaccion que finalmente se revierte. */
BEGIN;

DO $prueba_flujo$
DECLARE
    v_viaje_id bigint;
    v_kilometraje numeric;
BEGIN
    CALL floatmate_programacion.sp_programar_viaje(
        1001,
        1001,
        1001,
        timestamptz '2027-01-15 08:00:00-05',
        20::smallint,
        'Viaje temporal para probar procedimientos',
        v_viaje_id
    );

    INSERT INTO floatmate.controles_salida
        (terminal_codigo, viaje_id, usuario_id, fecha_hora_control,
         alcoholemia_mg_l, resultado, numero_ticket, observaciones)
    VALUES
        ('NOR', v_viaje_id, 1001, timestamptz '2027-01-15 07:30:00-05',
         0.000, 'APROBADO', 'PRUEBA-PROC-001', 'Control temporal');

    CALL floatmate_programacion.sp_iniciar_viaje(
        v_viaje_id,
        timestamptz '2027-01-15 08:05:00-05'
    );

    SELECT kilometraje + 120 INTO v_kilometraje
    FROM floatmate.vehiculos
    WHERE vehiculo_id = 1001;

    CALL floatmate_programacion.sp_cerrar_viaje(
        v_viaje_id,
        timestamptz '2027-01-15 10:00:00-05',
        v_kilometraje
    );

    RAISE NOTICE 'Flujo completo correcto para el viaje temporal %', v_viaje_id;
END
$prueba_flujo$;

SELECT operacion, nombre_tabla, clave_registro, fecha_hora
FROM floatmate_programacion.auditoria_cambios
WHERE operacion <> 'CARGA_INICIAL'
ORDER BY auditoria_id DESC
LIMIT 15;

ROLLBACK;

/* 15. El trigger debe impedir que los pasajeros superen la capacidad.
       La excepcion esperada se captura para que el archivo pueda continuar. */
DO $prueba_trigger$
BEGIN
    BEGIN
        INSERT INTO floatmate.viajes
            (terminal_codigo, vehiculo_id, conductor_id, ruta_id,
             fecha_hora_programada, pasajeros, estado, observaciones)
        VALUES
            ('NOR', 1001, 1001, 1001,
             timestamptz '2027-02-01 08:00:00-05', 99,
             'PROGRAMADO', 'Esta insercion debe ser rechazada');

        RAISE EXCEPTION 'ERROR DE PRUEBA: el trigger no rechazo la capacidad';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE 'Pasajeros (%) superan la capacidad%' THEN
                RAISE NOTICE 'Trigger de capacidad funcionando: %', SQLERRM;
            ELSE
                RAISE;
            END IF;
    END;
END
$prueba_trigger$;

/* Los ROLLBACK eliminan las filas temporales, pero PostgreSQL no revierte las
   secuencias. Las restauramos al maximo real para dejar la entrega limpia. */
SELECT setval(
    pg_get_serial_sequence('floatmate.viajes', 'viaje_id'),
    (SELECT max(viaje_id) FROM floatmate.viajes),
    true
);
SELECT setval(
    pg_get_serial_sequence('floatmate.controles_salida', 'control_id'),
    (SELECT max(control_id) FROM floatmate.controles_salida),
    true
);
SELECT setval(
    pg_get_serial_sequence('floatmate_programacion.auditoria_cambios', 'auditoria_id'),
    (SELECT max(auditoria_id) FROM floatmate_programacion.auditoria_cambios),
    true
);

/* 16. Validacion automatica del modulo avanzado. */
DO $validacion$
DECLARE
    v_funciones integer;
    v_procedimientos integer;
    v_triggers integer;
    v_auditorias integer;
    v_objetos_public integer;
BEGIN
    SELECT count(*) FILTER (WHERE p.prokind = 'f'),
           count(*) FILTER (WHERE p.prokind = 'p')
      INTO v_funciones, v_procedimientos
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'floatmate_programacion';

    SELECT count(DISTINCT trigger_name) INTO v_triggers
    FROM information_schema.triggers
    WHERE action_statement ILIKE '%floatmate_programacion%';

    SELECT count(*) INTO v_auditorias
    FROM floatmate_programacion.auditoria_cambios;

    SELECT count(*) INTO v_objetos_public
    FROM information_schema.routines
    WHERE routine_schema = 'public'
      AND (routine_name LIKE 'fn_%' OR routine_name LIKE 'sp_%');

    IF v_funciones < 10 THEN
        RAISE EXCEPTION 'Se esperaban al menos 10 funciones; existen %', v_funciones;
    ELSIF v_procedimientos < 5 THEN
        RAISE EXCEPTION 'Se esperaban al menos 5 procedimientos; existen %', v_procedimientos;
    ELSIF v_triggers < 11 THEN
        RAISE EXCEPTION 'Se esperaban al menos 11 triggers; existen %', v_triggers;
    ELSIF v_auditorias < 15 THEN
        RAISE EXCEPTION 'La auditoria debe tener minimo 15 evidencias; existen %', v_auditorias;
    ELSIF v_objetos_public <> 0 THEN
        RAISE EXCEPTION 'Se encontraron % funciones/procedimientos de FloatMate en public', v_objetos_public;
    END IF;

    RAISE NOTICE
        'MODULO AVANZADO CORRECTO: % funciones, % procedimientos, % triggers, % auditorias.',
        v_funciones, v_procedimientos, v_triggers, v_auditorias;
END
$validacion$;
