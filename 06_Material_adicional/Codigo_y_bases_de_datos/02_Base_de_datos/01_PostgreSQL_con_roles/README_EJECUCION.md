# FloatMate — Base de datos distribuida en PostgreSQL

Este paquete está configurado para simular dos nodos dentro de una sola instalación
local de PostgreSQL:

- **Terminal Norte:** base local y coordinadora. Guarda el fragmento `NOR`.
- **Terminal Sur:** segunda base local que representa el nodo remoto. Guarda `SUR`.
- **Federación:** Norte consulta Sur mediante `postgres_fdw`.
- **Vista global:** el esquema `floatmate_global` une ambos fragmentos con `UNION ALL`.

No se crea ninguna tabla de negocio en `public`. Cada nodo contiene **9 tablas
relacionadas y 15 registros por tabla**. Las vistas globales contienen 30 registros
por entidad.

## Arquitectura

```text
USUARIO / PGADMIN EN TERMINAL NORTE
                |
                v
      floatmate_norte (misma instalación local)
      +----------------------------------------+
      | floatmate.*       15 filas, NOR        |
      | floatmate_remoto.* tablas FDW ---------+---- red privada ----+
      | floatmate_global.* vistas UNION ALL    |                     |
      +----------------------------------------+                     v
                                                   floatmate_sur (misma instalación local)
                                                   +-------------------------+
                                                   | floatmate.*             |
                                                   | 15 filas por tabla, SUR |
                                                   +-------------------------+
```

## Requisitos

- PostgreSQL 14 o superior instalado en el computador de la práctica.
- pgAdmin 4 o `psql` para ejecutar los archivos.
- Usuario `postgres` o equivalente con privilegios para crear bases, roles y extensiones.

## Datos de laboratorio incluidos

| Elemento | Valor |
|---|---|
| Base Norte | `floatmate_norte` |
| Base Sur | `floatmate_sur` |
| Esquema físico de cada nodo | `floatmate` |
| Esquema de tablas foráneas en Norte | `floatmate_remoto` |
| Esquema de vistas globales en Norte | `floatmate_global` |
| Administrador de la base | `floatmate_admin` |
| Clave académica del administrador | `FloatMate_Admin_2026!` |
| Usuario remoto de solo lectura | `floatmate_fdw` |
| Clave académica FDW | `FloatMate_FDW_2026!` |

Las claves son deliberadamente visibles para que la entrega sea reproducible.
Deben cambiarse antes de usar información real.

## Orden exacto de ejecución

Antes de los nodos, conectado como `postgres` a la base `postgres`, ejecute una
sola vez `00_preparar_rol_admin.sql`.

### A. Base de Terminal Norte

1. Conectarse como `postgres` a la base `postgres`.
2. Activar **Autocommit** en pgAdmin.
3. Ejecutar `01_nodo_norte/00_crear_base_norte.sql` una sola vez.
4. Abrir una conexión a `floatmate_norte` como `floatmate_admin`.
5. Ejecutar `01_nodo_norte/01_modelo_norte.sql`.
6. Ejecutar `01_nodo_norte/02_datos_norte.sql`.

### B. Base de Terminal Sur

1. Conectarse como `postgres` a la base `postgres`.
2. Activar **Autocommit** en pgAdmin.
3. Ejecutar `02_nodo_sur/00_crear_base_sur.sql` una sola vez.
4. Abrir una conexión a `floatmate_sur` como `floatmate_admin`.
5. Ejecutar `02_nodo_sur/01_modelo_sur.sql`.
6. Ejecutar `02_nodo_sur/02_datos_sur.sql`.
7. Volver a conectarse a `floatmate_sur` como `postgres`.
8. Ejecutar `02_nodo_sur/03_usuario_fdw_sur.sql`.
9. En instalación local no se utiliza la carpeta `04_manual`.

### C. Federación en Terminal Norte

1. El archivo ya usa `127.0.0.1` y el puerto estándar `5432`.
2. Si PostgreSQL usa otro puerto, cambiar únicamente el valor `5432`.
3. Conectarse a `floatmate_norte` como `postgres`.
4. Ejecutar `03_federacion/01_configurar_fdw_en_norte.sql`.
5. Ejecutar `03_federacion/02_vistas_globales.sql`.
6. Ejecutar `03_federacion/03_validacion_total.sql`.
7. Ejecutar `03_federacion/04_consultas_sustentacion.sql` durante la exposición.
8. Ejecutar `05_programacion_bd/01_todo_funciones_procedimientos_triggers.sql`.
9. Ejecutar `05_programacion_bd/02_pruebas_y_ejemplos.sql`.

La validación termina con el aviso:

```text
VALIDACION COMPLETA: FLOATMATE BDD CUMPLE TODOS LOS CONTROLES.
```

También devuelve una tabla con 15 registros en Norte, 15 en Sur y 30 en la vista
global para cada entidad.

## Qué demuestra cada parte

| Concepto solicitado | Evidencia en la solución |
|---|---|
| Base local | `floatmate_norte`, esquema `floatmate` |
| Base remota | `floatmate_sur`, esquema `floatmate` |
| Mínimo 5 tablas relacionadas | Se entregan 9 tablas con PK, FK, `CHECK`, `UNIQUE` e índices |
| Mínimo 15 registros por tabla | Cada nodo contiene 15; cada vista global contiene 30 |
| Concepto de esquema | `floatmate`, `floatmate_remoto` y `floatmate_global` |
| Federación FDW | Servidor `servidor_terminal_sur` y 9 tablas foráneas |
| Fragmentación horizontal | Restricción `terminal_codigo = 'NOR'` o `'SUR'` en todas las tablas |
| Vista remota | Tablas `floatmate_remoto.*` visibles desde Norte |
| Vista global | Vistas `floatmate_global.*` y `v_operacion_viajes` |
| Funciones y procedimientos | Esquema `floatmate_programacion` |
| Triggers y auditoría | Validaciones automáticas e historial JSONB |
| Vista materializada | `mv_consumo_vehiculo` y procedimiento de actualización |

## Modelo relacional resumido

```text
usuarios --------+----------+-----------+-----------+
                 |          |           |           |
                 v          v           v           v
controles_salida   abastecimientos   mantenimientos  incidentes
       |                 |                 |             |
       v                 +----> vehiculos <+             |
     viajes <------------------------------+-------------+
       |
       +--------> conductores
       +--------> vehiculos
       +--------> rutas
```

## Qué decir en la sustentación

1. “No usamos `public`; aislamos los objetos del negocio en esquemas propios”.
2. “La clave `terminal_codigo` define el predicado de fragmentación horizontal”.
3. “Norte solo admite `NOR` y Sur solo admite `SUR` mediante restricciones `CHECK`”.
4. “`postgres_fdw` permite que Norte consulte físicamente las tablas de Sur”.
5. “La vista global aplica `UNION ALL` y reconstruye la relación lógica completa”.
6. “Los identificadores 1001–1015 y 2001–2015 evitan colisiones entre nodos”.
7. “El usuario FDW tiene acceso de solo lectura y la validación comprueba cantidades,
   fragmentación, relaciones y ausencia de tablas en `public`”.

## Problemas frecuentes

- **`could not connect to server`:** comprobar que PostgreSQL esté iniciado y que
  el puerto del archivo FDW coincida con el puerto local.
- **`no pg_hba.conf entry`:** la instalación local no está permitiendo conexiones
  TCP por `127.0.0.1`; revisar el archivo opcional de `04_manual`.
- **`password authentication failed`:** volver a ejecutar
  `03_usuario_fdw_sur.sql` y comprobar que la clave del `USER MAPPING` sea igual.
- **`extension postgres_fdw is not available`:** instalar en el servidor Norte el
  paquete de extensiones correspondiente a la misma versión de PostgreSQL.
- **`database already exists`:** el archivo `00_crear_base_*.sql` es de una sola
  ejecución. Continuar con el modelo si la base ya fue creada correctamente.
- **Una vista global falla tras cambiar el modelo:** volver a ejecutar, en orden,
  los cuatro archivos de `03_federacion`.

## Referencias técnicas

- PostgreSQL, `postgres_fdw`: https://www.postgresql.org/docs/current/postgres-fdw.html
- PostgreSQL, `IMPORT FOREIGN SCHEMA`: https://www.postgresql.org/docs/current/sql-importforeignschema.html
- PostgreSQL, `CREATE USER MAPPING`: https://www.postgresql.org/docs/current/sql-createusermapping.html
