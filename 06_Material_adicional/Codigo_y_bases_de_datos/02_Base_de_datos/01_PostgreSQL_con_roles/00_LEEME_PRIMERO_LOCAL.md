# FloatMate local — instrucciones exactas

Esta es la versión preparada para trabajar en **un solo computador**, con una sola
instalación de PostgreSQL y dos bases diferentes:

```text
PostgreSQL local (127.0.0.1:5432)
├── floatmate_norte   ← coordinador y fragmento NOR
└── floatmate_sur     ← nodo remoto simulado y fragmento SUR
```

No necesitas configurar IP, firewall, `postgresql.conf` ni la carpeta `04_manual`.
El archivo FDW ya utiliza `127.0.0.1`. Solo debes cambiar el puerto si tu PostgreSQL
no utiliza el puerto estándar `5432`.

## Antes de comenzar

En pgAdmin identifica dos elementos:

- El usuario administrador, normalmente `postgres`.
- El puerto del servidor, normalmente `5432`.

Mantén activado **Autocommit** al crear las bases de datos.

Antes de crear cualquier base, conéctate a `postgres` como usuario `postgres` y
ejecuta una sola vez:

```text
00_preparar_rol_admin.sql
```

Los archivos `00_crear_base_norte.sql` y `00_crear_base_sur.sql` contienen cada
uno una sola sentencia `CREATE DATABASE`, porque PostgreSQL no permite ejecutar
esa orden dentro de un bloque de transacción.

## Paso 1 — Crear Terminal Norte

Conéctate a la base `postgres` como usuario `postgres` y ejecuta:

```text
01_nodo_norte/00_crear_base_norte.sql
```

Actualiza el árbol de bases de datos. Después abre `floatmate_norte`, conéctate como
`floatmate_admin` y usa la contraseña:

```text
FloatMate_Admin_2026!
```

Ejecuta en este orden:

```text
01_nodo_norte/01_modelo_norte.sql
01_nodo_norte/02_datos_norte.sql
```

## Paso 2 — Crear Terminal Sur

Vuelve a la base `postgres` como usuario `postgres` y ejecuta:

```text
02_nodo_sur/00_crear_base_sur.sql
```

Actualiza el árbol, abre `floatmate_sur` como `floatmate_admin` y ejecuta:

```text
02_nodo_sur/01_modelo_sur.sql
02_nodo_sur/02_datos_sur.sql
```

Después abre `floatmate_sur` como usuario `postgres` y ejecuta:

```text
02_nodo_sur/03_usuario_fdw_sur.sql
```

## Paso 3 — Conectar Norte con Sur

Abre `floatmate_norte` como usuario `postgres`.

Si tu puerto es `5432`, no modifiques nada. Ejecuta:

```text
03_federacion/01_configurar_fdw_en_norte.sql
03_federacion/02_vistas_globales.sql
```

El primer archivo hace que `floatmate_norte` se conecte por FDW a
`floatmate_sur`, aunque ambas bases estén dentro del mismo PostgreSQL.

## Paso 4 — Comprobar toda la entrega

Todavía dentro de `floatmate_norte` como `postgres`, ejecuta:

```text
03_federacion/03_validacion_total.sql
```

El resultado correcto debe incluir:

```text
VALIDACION COMPLETA: FLOATMATE BDD CUMPLE TODOS LOS CONTROLES.
```

También debe mostrar, para cada tabla:

```text
registros_norte = 15
registros_sur   = 15
total_global   = 30
```

## Paso 5 — Sustentación

Ejecuta las consultas de:

```text
03_federacion/04_consultas_sustentacion.sql
```

Estas consultas muestran esquemas, tablas extranjeras, fragmentos, vista global,
consultas analíticas y el `Foreign Scan` de PostgreSQL.

## Paso 6 — Funciones, procedimientos y triggers

Después de validar la base distribuida, abre `floatmate_norte` como `postgres` y
ejecuta:

```text
05_programacion_bd/01_todo_funciones_procedimientos_triggers.sql
05_programacion_bd/02_pruebas_y_ejemplos.sql
```

El primer archivo crea todo dentro de `floatmate_programacion`: funciones
escalares y tabulares, JSONB, sobrecarga, cursor, procedimientos, excepciones,
triggers, auditoría, vistas y una vista materializada. El segundo demuestra y
valida los objetos sin modificar permanentemente los datos de la entrega.

La explicación para estudiar está en:

```text
05_programacion_bd/03_guia_estudio_y_preguntas.md
```

## Qué debes explicar al profesor

- Se simulan dos nodos mediante dos bases independientes.
- Norte conserva registros con `terminal_codigo = 'NOR'`.
- Sur conserva registros con `terminal_codigo = 'SUR'`.
- `postgres_fdw` permite que Norte consulte Sur mediante una conexión de base a base.
- `floatmate_remoto` contiene las tablas extranjeras de Sur.
- `floatmate_global` reconstruye la información completa mediante `UNION ALL`.
- La implementación local demuestra todos los conceptos, aunque ambos nodos estén
  alojados físicamente en la misma instalación para facilitar la práctica académica.

## Carpetas

- `01_nodo_norte`: creación, modelo y datos de Norte.
- `02_nodo_sur`: creación, modelo, datos y usuario remoto de Sur.
- `03_federacion`: FDW, vistas, validación y consultas de sustentación.
- `04_manual`: no se usa en la instalación local; se conserva únicamente por si
  posteriormente se separan las terminales en computadores diferentes.
- `05_programacion_bd`: funciones, procedimientos, triggers, auditoría, vistas,
  pruebas y preguntas de sustentación.
