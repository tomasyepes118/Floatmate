/*
  PRUEBA AUTOMATICA DE LA ENTREGA.
  Ejecutar en floatmate_norte cuando todos los pasos anteriores hayan terminado.
  Si algo obligatorio falta, el bloque genera un ERROR explicativo.
*/

DO $validar_floatmate$
DECLARE
    tabla text;
    cantidad_local bigint;
    cantidad_remota bigint;
    cantidad_global bigint;
    cantidad_public bigint;
    cantidad_objetos bigint;
    huerfanos bigint;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_foreign_server WHERE srvname = 'servidor_terminal_sur'
    ) THEN
        RAISE EXCEPTION 'Falta el servidor FDW servidor_terminal_sur';
    END IF;

    SELECT count(*) INTO cantidad_objetos
    FROM information_schema.foreign_tables
    WHERE foreign_table_schema = 'floatmate_remoto';

    IF cantidad_objetos <> 9 THEN
        RAISE EXCEPTION 'Se esperaban 9 tablas foraneas y se encontraron %', cantidad_objetos;
    END IF;

    SELECT count(*) INTO cantidad_public
    FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

    IF cantidad_public <> 0 THEN
        RAISE EXCEPTION 'Hay % tablas de usuario en public. Deben estar en esquemas propios', cantidad_public;
    END IF;

    FOREACH tabla IN ARRAY ARRAY[
        'usuarios', 'conductores', 'vehiculos', 'rutas', 'viajes',
        'controles_salida', 'abastecimientos', 'mantenimientos', 'incidentes'
    ]
    LOOP
        EXECUTE format('SELECT count(*) FROM floatmate.%I', tabla)
            INTO cantidad_local;
        EXECUTE format('SELECT count(*) FROM floatmate_remoto.%I', tabla)
            INTO cantidad_remota;
        EXECUTE format('SELECT count(*) FROM floatmate_global.%I', tabla)
            INTO cantidad_global;

        IF cantidad_local < 15 THEN
            RAISE EXCEPTION 'La tabla local % solo tiene % registros', tabla, cantidad_local;
        END IF;
        IF cantidad_remota < 15 THEN
            RAISE EXCEPTION 'La tabla remota % solo tiene % registros', tabla, cantidad_remota;
        END IF;
        IF cantidad_global <> cantidad_local + cantidad_remota THEN
            RAISE EXCEPTION
                'Vista global % inconsistente: global %, local %, remota %',
                tabla, cantidad_global, cantidad_local, cantidad_remota;
        END IF;

        RAISE NOTICE '%: local %, remota %, global % - OK',
            tabla, cantidad_local, cantidad_remota, cantidad_global;
    END LOOP;

    SELECT count(*) INTO cantidad_objetos
    FROM floatmate.vehiculos
    WHERE terminal_codigo <> 'NOR';
    IF cantidad_objetos <> 0 THEN
        RAISE EXCEPTION 'El fragmento Norte contiene registros ajenos a NOR';
    END IF;

    SELECT count(*) INTO cantidad_objetos
    FROM floatmate_remoto.vehiculos
    WHERE terminal_codigo <> 'SUR';
    IF cantidad_objetos <> 0 THEN
        RAISE EXCEPTION 'El fragmento Sur contiene registros ajenos a SUR';
    END IF;

    SELECT count(*) INTO huerfanos
    FROM floatmate_global.viajes AS vi
    LEFT JOIN floatmate_global.vehiculos AS ve ON ve.vehiculo_id = vi.vehiculo_id
    LEFT JOIN floatmate_global.conductores AS co ON co.conductor_id = vi.conductor_id
    LEFT JOIN floatmate_global.rutas AS ru ON ru.ruta_id = vi.ruta_id
    WHERE ve.vehiculo_id IS NULL OR co.conductor_id IS NULL OR ru.ruta_id IS NULL;

    IF huerfanos <> 0 THEN
        RAISE EXCEPTION 'Existen % viajes globales con relaciones huerfanas', huerfanos;
    END IF;

    SELECT count(*) INTO huerfanos
    FROM floatmate_global.controles_salida AS c
    LEFT JOIN floatmate_global.viajes AS v ON v.viaje_id = c.viaje_id
    LEFT JOIN floatmate_global.usuarios AS u ON u.usuario_id = c.usuario_id
    WHERE v.viaje_id IS NULL OR u.usuario_id IS NULL;

    IF huerfanos <> 0 THEN
        RAISE EXCEPTION 'Existen % controles globales con relaciones huerfanas', huerfanos;
    END IF;

    RAISE NOTICE 'VALIDACION COMPLETA: FLOATMATE BDD CUMPLE TODOS LOS CONTROLES.';
END
$validar_floatmate$;

-- Resultado visible para capturas de pantalla de la sustentacion.
SELECT 'usuarios' AS tabla,
       (SELECT count(*) FROM floatmate.usuarios) AS registros_norte,
       (SELECT count(*) FROM floatmate_remoto.usuarios) AS registros_sur,
       (SELECT count(*) FROM floatmate_global.usuarios) AS total_global
UNION ALL
SELECT 'conductores',
       (SELECT count(*) FROM floatmate.conductores),
       (SELECT count(*) FROM floatmate_remoto.conductores),
       (SELECT count(*) FROM floatmate_global.conductores)
UNION ALL
SELECT 'vehiculos',
       (SELECT count(*) FROM floatmate.vehiculos),
       (SELECT count(*) FROM floatmate_remoto.vehiculos),
       (SELECT count(*) FROM floatmate_global.vehiculos)
UNION ALL
SELECT 'rutas',
       (SELECT count(*) FROM floatmate.rutas),
       (SELECT count(*) FROM floatmate_remoto.rutas),
       (SELECT count(*) FROM floatmate_global.rutas)
UNION ALL
SELECT 'viajes',
       (SELECT count(*) FROM floatmate.viajes),
       (SELECT count(*) FROM floatmate_remoto.viajes),
       (SELECT count(*) FROM floatmate_global.viajes)
UNION ALL
SELECT 'controles_salida',
       (SELECT count(*) FROM floatmate.controles_salida),
       (SELECT count(*) FROM floatmate_remoto.controles_salida),
       (SELECT count(*) FROM floatmate_global.controles_salida)
UNION ALL
SELECT 'abastecimientos',
       (SELECT count(*) FROM floatmate.abastecimientos),
       (SELECT count(*) FROM floatmate_remoto.abastecimientos),
       (SELECT count(*) FROM floatmate_global.abastecimientos)
UNION ALL
SELECT 'mantenimientos',
       (SELECT count(*) FROM floatmate.mantenimientos),
       (SELECT count(*) FROM floatmate_remoto.mantenimientos),
       (SELECT count(*) FROM floatmate_global.mantenimientos)
UNION ALL
SELECT 'incidentes',
       (SELECT count(*) FROM floatmate.incidentes),
       (SELECT count(*) FROM floatmate_remoto.incidentes),
       (SELECT count(*) FROM floatmate_global.incidentes)
ORDER BY tabla;
