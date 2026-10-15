# FloatMate — guía de funciones, procedimientos y triggers

Todo el módulo está en el esquema `floatmate_programacion`. No se crea ningún
objeto del proyecto en `public`.

## Orden de ejecución

Después de terminar Norte, Sur, FDW y vistas globales, conéctate a
`floatmate_norte` como `postgres` y ejecuta:

```text
01_todo_funciones_procedimientos_triggers.sql
02_pruebas_y_ejemplos.sql
```

El segundo archivo prueba modificaciones dentro de transacciones que terminan en
`ROLLBACK`, por lo que los datos originales permanecen intactos.

## Objetos incluidos

| Tipo | Ejemplo | Qué demuestra |
|---|---|---|
| Función escalar | `fn_kilometros_para_mantenimiento` | Recibe un dato y retorna un valor |
| Función sobrecargada | `fn_total_combustible` | Mismo nombre con parámetros diferentes |
| Función PL/pgSQL | `fn_validar_inicio_viaje` | Variables, `IF`, `SELECT INTO` y reglas |
| Función tabular | `fn_viajes_por_terminal` | `RETURNS TABLE` |
| Función JSON | `fn_detalle_viaje_json` | Construcción de documentos `jsonb` |
| Función con cursor | `fn_alertas_mantenimiento_cursor` | `CURSOR`, `OPEN`, `FETCH`, `CLOSE` |
| Varios valores de salida | `fn_estadisticas_terminal` | Retorno de indicadores relacionados |
| Procedimiento | `sp_programar_viaje` | Inserción validada y parámetro `INOUT` |
| Procedimiento | `sp_iniciar_viaje` | Cambio coordinado de estados |
| Procedimiento | `sp_cerrar_viaje` | Actualización transaccional de varias tablas |
| Trigger `BEFORE` | `tr_validar_viaje` | Rechaza pasajeros o terminal incorrectos |
| Trigger `AFTER` | `tr_auditar_*` | Guarda valores anteriores y nuevos |
| Vista normal | `v_alertas_mantenimiento` | Consulta almacenada, datos siempre actuales |
| Vista materializada | `mv_consumo_vehiculo` | Resultado persistido que requiere `REFRESH` |

## Diferencia entre función y procedimiento

Una función se usa normalmente dentro de una expresión o un `SELECT`:

```sql
SELECT floatmate_programacion.fn_kilometros_para_mantenimiento(1001);
```

Un procedimiento se ejecuta mediante `CALL` y está pensado para realizar una
operación o proceso:

```sql
CALL floatmate_programacion.sp_cambiar_estado_vehiculo(1001, 'MANTENIMIENTO');
```

## Qué es una función almacenada

Es código guardado dentro de PostgreSQL. Tiene nombre, parámetros, tipo de retorno,
lenguaje y cuerpo. Puede reutilizarse desde consultas, aplicaciones, vistas u otras
funciones.

Estructura básica:

```sql
CREATE OR REPLACE FUNCTION esquema.nombre(parametro tipo)
RETURNS tipo
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN valor;
END;
$$;
```

## Volatilidad de funciones

- `IMMUTABLE`: con los mismos parámetros siempre produce el mismo resultado y no
  depende de tablas ni del tiempo.
- `STABLE`: puede consultar tablas, pero no las modifica; mantiene un resultado
  estable dentro de una sentencia.
- `VOLATILE`: puede cambiar datos o devolver resultados distintos en llamadas
  sucesivas. Es el comportamiento predeterminado.

Las funciones de consulta de FloatMate se declaran `STABLE`. Las funciones de
trigger son `VOLATILE` por defecto porque registran o validan modificaciones.

## Parámetros

- `IN`: valor de entrada; es el modo predeterminado.
- `OUT`: valor producido como salida.
- `INOUT`: entra con un valor y puede salir modificado.
- `VARIADIC`: permite recibir una cantidad variable de argumentos.

`sp_programar_viaje` utiliza `INOUT p_viaje_id` para devolver el identificador
generado.

## Qué es la sobrecarga

PostgreSQL permite objetos con el mismo nombre si sus tipos de entrada son
diferentes. El módulo incluye:

```sql
fn_total_combustible(bigint)  -- total de un vehículo
fn_total_combustible(varchar) -- total de una terminal
```

Para evitar ambigüedades se puede escribir el tipo explícitamente:

```sql
SELECT floatmate_programacion.fn_total_combustible(1001::bigint);
SELECT floatmate_programacion.fn_total_combustible('NOR'::varchar);
```

## Qué es un trigger

Es una acción automática asociada a un evento de una tabla. En PostgreSQL el
trigger llama a una función que retorna `trigger`.

- `BEFORE`: se ejecuta antes del cambio y puede rechazarlo o modificar `NEW`.
- `AFTER`: se ejecuta después del cambio; es apropiado para auditoría.
- `FOR EACH ROW`: se ejecuta por cada fila afectada.
- `FOR EACH STATEMENT`: se ejecuta una vez por sentencia.

Variables importantes dentro de una función de trigger:

- `NEW`: fila nueva en `INSERT` o `UPDATE`.
- `OLD`: fila anterior en `UPDATE` o `DELETE`.
- `TG_OP`: operación ejecutada.
- `TG_TABLE_NAME`: tabla que activó el trigger.
- `TG_ARGV`: argumentos enviados al trigger.

## Qué registra la auditoría

La tabla `auditoria_cambios` almacena:

- Fecha y hora.
- Usuario de PostgreSQL.
- Operación `INSERT`, `UPDATE` o `DELETE`.
- Esquema y tabla.
- Identificador del registro.
- Fila anterior como `jsonb`.
- Fila nueva como `jsonb`.
- Dirección del cliente.

## Vista normal frente a vista materializada

Una vista normal no guarda físicamente el resultado; ejecuta su consulta cada vez.
Una vista materializada sí conserva el resultado y puede consultarse más rápido,
pero debe actualizarse:

```sql
CALL floatmate_programacion.sp_refrescar_consumo_vehiculo();
```

## Manejo de excepciones

Los procedimientos usan `RAISE EXCEPTION` para impedir operaciones inválidas. Por
ejemplo, programar un vehículo ocupado, iniciar un viaje sin control aprobado o
cerrar un viaje que no se encuentre en curso.

También utilizan:

```sql
EXCEPTION
    WHEN no_data_found THEN
        RAISE EXCEPTION 'El registro no existe';
```

## Preguntas probables del profesor

### ¿Por qué no se usó `public`?

Para separar los objetos por responsabilidad, controlar permisos y evitar mezclar
objetos del proyecto con el esquema predeterminado. Los datos están en `floatmate`,
la federación en `floatmate_remoto`, las vistas distribuidas en `floatmate_global`
y la programación en `floatmate_programacion`.

### ¿Dónde se ejecutan las funciones?

Las funciones se almacenan y ejecutan dentro del servidor PostgreSQL. Las funciones
globales se invocan desde Norte y pueden consultar los datos de Sur por FDW.

### ¿Un trigger es un procedimiento?

No. En PostgreSQL un trigger siempre ejecuta una función que retorna el tipo
especial `trigger`. Aunque la sintaxis histórica acepta la palabra `PROCEDURE`, el
objeto invocado sigue siendo una función de trigger.

### ¿Por qué la auditoría usa JSONB?

Porque permite guardar una representación completa de filas con estructuras
distintas sin crear una tabla de auditoría diferente para cada entidad.

### ¿Qué sucede si una función no encuentra datos?

Una función SQL escalar puede retornar `NULL`. Un procedimiento con
`SELECT INTO STRICT` produce `no_data_found`, que el código captura y transforma en
un mensaje comprensible.

### ¿Qué significa `CREATE OR REPLACE`?

Crea el objeto si no existe o reemplaza su implementación conservando su identidad
y permisos. No permite cambiar libremente los tipos de parámetros o el tipo de
retorno; para esos cambios normalmente se debe eliminar y volver a crear el objeto.

### ¿Por qué se usa `ROLLBACK` en las pruebas?

Para demostrar procedimientos y triggers sin dejar modificaciones permanentes en
los datos preparados para la entrega.

## Consultas rápidas para la sustentación

```sql
-- Funciones y procedimientos
SELECT routine_schema, routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'floatmate_programacion';

-- Triggers
SELECT trigger_name, event_object_table, event_manipulation
FROM information_schema.triggers
WHERE action_statement ILIKE '%floatmate_programacion%';

-- Auditoría
SELECT *
FROM floatmate_programacion.auditoria_cambios
ORDER BY auditoria_id DESC;

-- Vistas materializadas
SELECT schemaname, matviewname, ispopulated
FROM pg_matviews
WHERE schemaname = 'floatmate_programacion';
```
