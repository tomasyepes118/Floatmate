# FloatMate en dos servidores PostgreSQL - sin roles adicionales

Esta versión utiliza directamente el usuario `postgres` en los dos servidores que
ya aparecen registrados en pgAdmin como `Norte` y `Sur`.

No se crea `floatmate_admin` ni `floatmate_fdw`.

## Resultado esperado

```text
Servidor Norte
└── floatmate_norte
    ├── floatmate             tablas NOR
    ├── floatmate_remoto      tablas extranjeras de Sur
    ├── floatmate_global      vistas Norte + Sur
    └── floatmate_programacion

Servidor Sur
└── floatmate_sur
    └── floatmate             tablas SUR
```

## Parte 1 - Servidor Norte

1. En pgAdmin despliegue `Norte`.
2. Despliegue `Databases`.
3. Clic derecho sobre la base `postgres` y seleccione `Query Tool`.
4. Confirme la conexión:

```sql
SELECT current_database(), current_user, current_setting('port');
```

Debe mostrar la base `postgres` y el usuario `postgres`.

5. Abra y ejecute únicamente:

```text
01_NORTE/01_crear_base_norte.sql
```

6. Clic derecho en `Databases` y seleccione `Refresh`.
7. Debe aparecer `floatmate_norte`.
8. Clic derecho sobre `floatmate_norte` y abra `Query Tool`.
9. Ejecute en orden:

```text
01_NORTE/02_modelo_norte.sql
01_NORTE/03_datos_norte.sql
```

10. Compruebe:

```sql
SELECT count(*) FROM floatmate.vehiculos;
```

Debe devolver `15`.

## Parte 2 - Servidor Sur

1. En pgAdmin despliegue `Sur`.
2. Despliegue `Databases`.
3. Clic derecho sobre la base `postgres` y seleccione `Query Tool`.
4. Confirme:

```sql
SELECT current_database(), current_user, current_setting('port');
```

5. Abra y ejecute únicamente:

```text
02_SUR/01_crear_base_sur.sql
```

6. Actualice `Databases` y abra el Query Tool de `floatmate_sur`.
7. Ejecute en orden:

```text
02_SUR/02_modelo_sur.sql
02_SUR/03_datos_sur.sql
```

8. Compruebe:

```sql
SELECT count(*) FROM floatmate.vehiculos;
```

Debe devolver `15`.

9. Ejecute:

```text
02_SUR/04_consultar_conexion_sur.sql
```

Anote `host_sur`, `puerto_sur` y la contraseña que utiliza para conectarse como
`postgres` al servidor Sur.

## Parte 3 - Federación desde Norte

1. Abra este archivo con un editor de texto:

```text
03_FEDERACION_EN_NORTE/01_configurar_fdw_hacia_sur.sql
```

2. Reemplace:

```text
HOST_DEL_SERVIDOR_SUR
PUERTO_DEL_SERVIDOR_SUR
CLAVE_POSTGRES_SUR
```

Si ambos servidores están en el mismo computador, el host normalmente será
`127.0.0.1`, pero los puertos de dos instancias diferentes deben ser distintos.

3. En pgAdmin abra `Norte` -> `Databases` -> `floatmate_norte` -> `Query Tool`.
4. Confirme:

```sql
SELECT current_database(), current_user;
```

Debe mostrar `floatmate_norte` y `postgres`.

5. Ejecute en orden:

```text
03_FEDERACION_EN_NORTE/01_configurar_fdw_hacia_sur.sql
03_FEDERACION_EN_NORTE/02_vistas_globales.sql
03_FEDERACION_EN_NORTE/03_validacion_total.sql
03_FEDERACION_EN_NORTE/04_consultas_sustentacion.sql
```

El primer archivo debe mostrar `15` vehículos recibidos desde Sur. La validación
debe terminar con:

```text
VALIDACION COMPLETA: FLOATMATE BDD CUMPLE TODOS LOS CONTROLES.
```

## Parte 4 - Programación avanzada

En `Norte` -> `floatmate_norte`, como `postgres`, ejecute:

```text
04_PROGRAMACION_AVANZADA/01_funciones_procedimientos_triggers.sql
04_PROGRAMACION_AVANZADA/02_pruebas_y_ejemplos.sql
```

La guía de estudio está en:

```text
04_PROGRAMACION_AVANZADA/03_guia_estudio.md
```

## Actividad BDOO: objetos, herencia y métodos

Para la actividad de **federación con CSV y Data Warehouse**, ver
[la guía de implementación](../03_Federacion_CSV_DWH/LEEME_IMPLEMENTACION.md).
Ese módulo se ejecuta en NORTE > `floatmate_norte` y es independiente de BDOO.

El módulo está en [05_BDOO/LEEME_PRIMERO.md](05_BDOO/LEEME_PRIMERO.md).
Para instalarlo por primera vez, abra Query Tool en `Norte > floatmate_norte`
y ejecute los archivos de `05_BDOO` en este orden:

1. `00_comprobar_base.sql`: comprueba la conexión y las tablas de origen.
2. `01_modelo_objetos.sql`: crea el esquema `floatmate_objetos`; una sola vez.
3. `02_metodos_y_reglas.sql`: crea funciones, procedimientos y reglas.
4. `03_importar_datos_actuales.sql`: carga una instantánea de los datos locales.
5. `04_consultas_sustentacion.sql`: muestra objetos, herencia y métodos.
6. `05_pruebas_automaticas.sql`: comprueba el módulo y revierte el ensayo.

La importación es una instantánea independiente: los cambios posteriores de las
tablas operativas no se sincronizan automáticamente. Consulte la guía del módulo
para comprobar una instalación previa y ejecutar las demostraciones opcionales.

El PDF adjunto el 13 de octubre de 2026 tiene el nombre
`SD1008_Bases_de_Datos_II_UND2_Federación_DWH_Analítica.pdf`, pero sus nueve
diapositivas tratan BDOO. Este módulo corresponde a ese contenido. Ese documento
no define una actividad de almacén de datos (DWH) ni un modelo de analítica.

## Orden completo de BDD y programación avanzada

| Orden | Servidor | Base | Archivo |
|---:|---|---|---|
| 1 | Norte | postgres | `01_NORTE/01_crear_base_norte.sql` |
| 2 | Norte | floatmate_norte | `01_NORTE/02_modelo_norte.sql` |
| 3 | Norte | floatmate_norte | `01_NORTE/03_datos_norte.sql` |
| 4 | Sur | postgres | `02_SUR/01_crear_base_sur.sql` |
| 5 | Sur | floatmate_sur | `02_SUR/02_modelo_sur.sql` |
| 6 | Sur | floatmate_sur | `02_SUR/03_datos_sur.sql` |
| 7 | Sur | floatmate_sur | `02_SUR/04_consultar_conexion_sur.sql` |
| 8 | Norte | floatmate_norte | `03_FEDERACION_EN_NORTE/01_configurar_fdw_hacia_sur.sql` |
| 9 | Norte | floatmate_norte | `03_FEDERACION_EN_NORTE/02_vistas_globales.sql` |
| 10 | Norte | floatmate_norte | `03_FEDERACION_EN_NORTE/03_validacion_total.sql` |
| 11 | Norte | floatmate_norte | `03_FEDERACION_EN_NORTE/04_consultas_sustentacion.sql` |
| 12 | Norte | floatmate_norte | `04_PROGRAMACION_AVANZADA/01_funciones_procedimientos_triggers.sql` |
| 13 | Norte | floatmate_norte | `04_PROGRAMACION_AVANZADA/02_pruebas_y_ejemplos.sql` |
