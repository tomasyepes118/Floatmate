# FloatMate: federación con CSV y Data Warehouse

Todo este módulo se ejecuta en **servidor NORTE > base `floatmate_norte`**, como
`postgres`, desde Query Tool de pgAdmin. SUR conserva su base operativa. No hay
que crear una tercera base: el almacén se implementa en el esquema **`dwh`** de
NORTE. El nombre correcto del concepto es **Data Warehouse**, almacén de datos.

## Qué es cada parte y cómo se aplica

| Parte | Qué significa | Aplicación en FloatMate |
|---|---|---|
| Federación | Consultar fuentes diferentes mediante una conexión lógica | NORTE consulta SUR con `postgres_fdw` y un CSV con `file_fdw` |
| Tabla externa o foránea | Definición SQL que apunta a datos fuera de la base | `floatmate_externo.mantenimientos_csv` apunta al archivo del servidor |
| Vista federada | Consulta virtual que integra las fuentes | `floatmate_federacion.mantenimientos_federados` une NORTE + SUR + CSV |
| DWH | Almacén físico dedicado al análisis | Tablas persistentes dentro de `dwh` |
| Staging | Copia de las fuentes antes del modelado analítico | Nueve tablas `dwh.stg_*` guardan las entidades completas |
| Dimensión | Describe con qué criterios agrupamos y filtramos | Fecha, terminal, vehículo, conductor, ruta y usuario |
| Hecho | Guarda eventos y sus medidas | Viajes, abastecimientos, mantenimientos, controles e incidentes |
| ETL | Extraer, transformar y cargar datos | `CALL dwh.sp_cargar()` lee fuentes, valida y carga el almacén |

Crear la tabla externa **no copia el Excel dentro de PostgreSQL**. Primero se
exporta la hoja a CSV y luego `SELECT` lee ese archivo mediante `file_fdw`.
PostgreSQL no lee `.xlsx` directamente con este wrapper. La copia física ocurre
al ejecutar la carga ETL al DWH. Una vista federada cumple la integración lógica;
no es necesario crear otra tabla física que duplique la tabla externa.

La tabla foránea y la vista dependen de que las fuentes estén accesibles. Después
de una carga exitosa, las consultas `dwh.*` usan las tablas almacenadas en NORTE
y pueden ejecutarse sin acceder a SUR ni al CSV.

## Arquitectura

```text
NORTE: floatmate.* ---------------------+
SUR: floatmate.* -- postgres_fdw -------+--> floatmate_global.*
                                       |          |
CSV en Windows de NORTE -- file_fdw ----+----> mantenimientos_federados
                                                  |
                                            procedimiento ETL
                                                  |
                                         dwh.stg_* (9 entidades)
                                                  |
                                  dimensiones + 5 tablas de hechos
                                                  |
                                       consultas analíticas SQL
```

Solo los mantenimientos incorporan la tercera fuente CSV. Las demás entidades
se centralizan desde las vistas globales NORTE-SUR existentes. El módulo BDOO
anterior es independiente de esta actividad; no se necesita para estos pasos.

## 1. Revisar la federación NORTE-SUR

En pgAdmin, abrir **NORTE > Databases > floatmate_norte > Query Tool**.
Ejecutar `00_revisar_federacion.sql`. Revisa las nueve entidades locales, remotas
y globales, e intenta leerlas. Si falla por conexión, credenciales o tablas
faltantes, primero reparar la federación existente.

Con la carga original hay 15 filas por entidad en cada nodo y 30 globales.
Si se agregaron datos, los conteos pueden ser mayores. **No volver a ejecutar
el script antiguo de configuración FDW solo para revisar**: contiene `DROP ...
CASCADE` y puede eliminar vistas dependientes. El archivo 00 de este módulo es
de solo lectura.

## 2. Crear/exportar el CSV y llevarlo al servidor

Ya se incluye `datos/mantenimientos_externos.csv`, con **cuatro registros
ficticios de demostración**: dos NOR y dos SUR. Referencian vehículos de la carga
original (1001, 1002, 2001, 2002). Son eventos nuevos de talleres externos, no
copias de eventos que ya estén en `floatmate.mantenimientos`.

Si haces el archivo en Excel:

1. Usar estos encabezados, en este orden:

   ```text
   registro_csv,terminal_codigo,vehiculo_id,tipo,fecha_ingreso,fecha_salida,kilometraje,costo,proveedor,descripcion,estado
   ```

2. `registro_csv` identifica el evento y debe ser estable; por ejemplo `EXT-NOR-001`.
   La combinación fuente + terminal + registro debe ser única.
3. Usar `NOR` o `SUR` y un vehículo que exista en esa terminal. No escribir una
   placa donde se solicita `vehiculo_id`.
4. Fechas `AAAA-MM-DD`, decimales con punto y sin separador de miles.
5. Tipos `PREVENTIVO` o `CORRECTIVO`; estados `PROGRAMADO`, `EN_PROCESO` o
   `FINALIZADO`. Costo y kilometraje no negativos.
6. Guardar la hoja como **CSV UTF-8**. Abrirlo en un editor y comprobar que los
   campos estén separados por **coma**: Excel puede exportar con punto y coma
   según la configuración regional. En ese caso, usar `delimiter ';'` en 01 o
   exportar correctamente con coma. No reemplazar separadores a ciegas dentro
   de textos entre comillas.
7. Copiar el CSV al **otro equipo Windows donde corre PostgreSQL NORTE**:

   ```text
   C:\FloatMate\csv\mantenimientos_externos.csv
   ```

La ruta local de tu computador cliente no sirve para este enlace. El servicio
PostgreSQL del equipo NORTE debe poder leer la carpeta y el archivo. En Windows,
revisar en Servicios la cuenta de inicio del servicio PostgreSQL y darle lectura
en Propiedades > Seguridad de esa carpeta. No hace falta dar acceso a todos los
usuarios ni crear roles de negocio nuevos.

Mantener ese archivo guardado y estable durante una carga. A diferencia de una
tabla PostgreSQL, el CSV externo no participa en el control transaccional de
versiones; no editarlo mientras se carga.

Si el archivo está en otra carpeta de NORTE, cambiar `filename` en 01 antes de
la primera ejecución. Si la tabla ya existe, `IF NOT EXISTS` conserva su ruta;
para actualizarla usar:

```sql
ALTER FOREIGN TABLE floatmate_externo.mantenimientos_csv
OPTIONS (SET filename 'C:/OtraCarpeta/mantenimientos_externos.csv');
```

## 3. Orden de ejecución

Activar **Auto-commit** en pgAdmin. Ejecutar cada archivo completo con F5, sin
dejar un fragmento seleccionado. Todos van en **NORTE > `floatmate_norte`**, como
`postgres`. Los scripts no cambian las tablas operativas de NORTE o SUR.

| Orden | Archivo | Qué debe ocurrir |
|---|---|---|
| 0 | `00_revisar_federacion.sql` | Lecturas NORTE-SUR correctas |
| 1 | `01_conectar_csv.sql` | Crea `file_fdw`, servidor y tabla externa; devuelve 4 filas del CSV |
| 2 | `02_vista_federada.sql` | Devuelve mantenimiento PostgreSQL y CSV por terminal |
| 3 | `03_crear_dwh.sql` | Crea staging, dimensiones, hechos y bitácora en `dwh` |
| 4 | `04_instalar_etl.sql` | Crea el procedimiento; todavía no carga datos |
| 5 | `05_ejecutar_carga.sql` | Extrae, valida y carga; avisa `CARGA DWH COMPLETA` |
| 6 | `06_validar_dwh.sql` | Avisa `VALIDACION DWH COMPLETA` y muestra cantidades/costos |
| 7 | `07_consultas_analiticas.sql` | Comparaciones de pasajeros, costos y eventos |
| 8 | `08_prueba_csv_vs_dwh.sql` | Demostración manual de cambio en CSV y posterior ETL |

Después de la instalación, basta repetir **05, 06 y 07** para actualizar y
consultar. Si una ejecución falla y pgAdmin queda en transacción abortada,
ejecutar `ROLLBACK;`, corregir el mensaje y repetir el archivo fallido.

## 4. Cómo está modelado el DWH

Las nueve tablas `stg_*` guardan todos los campos expuestos por las fuentes.
`stg_mantenimientos` guarda la unión PostgreSQL + CSV con su procedencia; el ID
original del mantenimiento se conserva como texto en `registro_origen`.
El CSV no conoce al usuario interno que registró el evento; en esos registros
`usuario_id` y la clave de dimensión de usuario son NULL, sin inventar usuarios.

| Hecho | Granularidad: una fila representa | Medidas principales |
|---|---|---|
| `fact_viaje` | Un viaje de una terminal | Pasajeros, capacidad, distancia programada, duración real |
| `fact_abastecimiento` | Un abastecimiento | Litros, valor por litro y costo |
| `fact_mantenimiento` | Un mantenimiento de una fuente y terminal | Costo y kilometraje |
| `fact_control_salida` | Un control de salida | Alcoholemia; número de eventos mediante COUNT |
| `fact_incidente` | Un incidente | Número de eventos mediante COUNT, clasificados por tipo y severidad |

Las dimensiones de vehículo, conductor, ruta y usuario usan claves sustitutas
`*_sk`. Su correspondencia con el sistema original usa **terminal + ID original**,
para no confundir entidades de nodos distintos. Las fechas de los eventos con
hora se clasifican en la zona **America/Bogota**.

La carga es completa y transaccional: copia las fuentes, rechaza duplicados y
referencias inexistentes, actualiza dimensiones y reemplaza los hechos. Las
dimensiones conservan sus claves y actualizan atributos con estrategia **tipo 1**.
Dimensiones antiguas pueden seguir presentes aunque ya no existan en el origen;
los hechos reflejan únicamente la última carga. Una recarga refleja también
eliminaciones del origen. Si falla, se conserva la carga anterior.

Este primer DWH conserva la **última fotografía completa** y una bitácora de
cargas. No mantiene versiones históricas de cada cambio de estado/atributo, ni
captura automáticamente eventos eliminados del sistema entre cargas. Para ese
requisito se necesitaría otra estrategia (por ejemplo SCD tipo 2 y carga de cambios).
La carga es manual; todavía no se configuró un horario automático.

No poner en el CSV un mantenimiento que ya exista en PostgreSQL: las fuentes
tienen identidades separadas y ese mismo evento se contaría dos veces. Si un
taller envía eventos ya registrados, habría que definir una clave de negocio
común, como número de orden/factura, y una regla de deduplicación antes de cargar.

## 5. Cómo comprobar que funciona

Con la carga original y el CSV incluido se esperan:

| Elemento | Cantidad |
|---|---:|
| CSV externo | 4 |
| Vista de mantenimientos federados | 34: 15 NOR + 15 SUR + 4 CSV |
| Dimensiones usuario, vehículo, conductor y ruta | 30 cada una |
| Dimensión terminal | 2 |
| Hechos viajes, abastecimientos, controles e incidentes | 30 cada uno |
| Hechos mantenimiento | 34 |
| Costo de los 4 mantenimientos CSV | 1.200.000 COP |

Los conteos cambian si los datos operativos ya cambiaron. La validación 06
compara con las fuentes copiadas de la última carga, sin forzar estos números.

### Prueba A: CSV y federación

```sql
SELECT * FROM floatmate_externo.mantenimientos_csv;
SELECT fuente,terminal_codigo,count(*)
FROM floatmate_federacion.mantenimientos_federados
GROUP BY fuente,terminal_codigo;
```

Debe verse tanto `POSTGRESQL` como `CSV_LOCAL`. Con el ejemplo, el CSV aporta dos
registros a NOR y dos a SUR, aunque el archivo se lee desde el servidor NORTE.

### Prueba B: centralización e idempotencia

Ejecutar 05 y luego 06. Repetir ambos. Deben conservarse las cantidades y los
costos, sin duplicados; habrá dos nuevas entradas de bitácora, una por carga.

```sql
SELECT * FROM dwh.etl_ejecucion ORDER BY ejecucion_id DESC;
SELECT fuente,terminal_codigo,count(*),sum(costo_cop)
FROM dwh.fact_mantenimiento GROUP BY fuente,terminal_codigo;
```

### Prueba C: fuente en vivo frente a copia física

Seguir las secciones de 08. Cambiar temporalmente el costo de `EXT-NOR-001` de
180000 a 190000 en el CSV guardado en NORTE. El SELECT de la vista federada cambia
inmediatamente; el SELECT del DWH mantiene 180000 hasta ejecutar ETL. Tras cargar,
ambos muestran 190000. Restaurar el CSV original y cargar otra vez.

### Prueba D: datos inválidos

Conservar respaldo del CSV. Cambiar temporalmente un vehículo a uno inexistente
o duplicar una fila del CSV. La lectura externa puede mostrarla, pero 05 debe
rechazar la carga. Ejecutar `ROLLBACK;` si corresponde y comprobar que el DWH
mantiene la última carga exitosa. Restaurar el CSV y volver a cargar.

### Prueba E: independencia del almacén

Ejecutar 07: todas sus consultas referencian únicamente tablas físicas `dwh.*`.
No apagar SUR compartido para demostrarlo. Si el CSV o SUR no estuvieran disponibles,
esas consultas seguirían usando la última copia; una nueva carga ETL sí fallaría.

## Errores frecuentes

- `could not open file`: el CSV no está en el equipo NORTE, la ruta es distinta
  o el servicio Windows no tiene permiso para leerlo.
- `missing data for column` / `extra data after last expected column`: separador,
  número u orden de columnas incorrecto; revisar exportación de Excel.
- `invalid input syntax`: fecha/decimal incorrecto; no usar `$`, separador de
  miles ni fechas ambiguas.
- `extension file_fdw is not available`: el servidor necesita los archivos de
  la extensión correspondiente a su instalación PostgreSQL. Pedir al encargado
  de ese equipo que revise su instalación.
- `Relacion invalida`: el ID del CSV no existe en esa terminal; buscar los IDs
  reales con `SELECT terminal_codigo,vehiculo_id,placa FROM floatmate_global.vehiculos;`.
- Error al consultar SUR: reparar la conexión previa antes de ejecutar 05.

## Verificación realizada

Se ejecutó SQL y PL/pgSQL real con PostgreSQL 18.3 mediante PGlite, con NORTE,
SUR y CSV simulados mediante tablas en un entorno separado. Se verificaron
recarga, conservación de claves, cambios y eliminaciones del origen, rechazo
de datos inválidos, reversión de carga e independencia de consultas analíticas.
El resultado está en `INFORME_VERIFICACION.txt`.

**No se ha instalado este módulo en el otro equipo.** La conexión real
`file_fdw`, la red hacia SUR y los permisos del servicio Windows se verifican
allí ejecutando 00, 01 y la carga. El wrapper real del archivo no está disponible
en el entorno de pruebas, y no se presenta su simulación como prueba de conexión.

## Referencias

- PostgreSQL `file_fdw`: https://www.postgresql.org/docs/18/file-fdw.html
- PostgreSQL `postgres_fdw`: https://www.postgresql.org/docs/18/postgres-fdw.html
