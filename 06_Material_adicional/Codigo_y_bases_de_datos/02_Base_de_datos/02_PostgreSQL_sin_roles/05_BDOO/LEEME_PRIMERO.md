# FloatMate: actividad de bases de datos orientadas a objetos

Esta entrega aplica al proyecto FloatMate los conceptos del documento del profesor Edson Gutiérrez: objetos, clases, atributos, métodos, encapsulamiento, herencia e identidad del objeto (OID). Se implementa mediante las capacidades objeto-relacionales de PostgreSQL: tipos compuestos, herencia de tablas, funciones y JSONB.

El PDF del profesor tiene nueve diapositivas. No contiene una rúbrica con cantidad mínima de tablas/registros, fecha de entrega ni un ejercicio SQL concreto. Los mínimos de la actividad BDD anterior no se presentan como requisitos nuevos de BDOO. La entrega usa tus datos existentes y aporta demostraciones adicionales de sobrecarga y colecciones.

## Qué vas a instalar y dónde

Abre **Norte > Databases > floatmate_norte > Query Tool**. Todo el módulo se crea en el esquema **floatmate_objetos**. No necesitas crear otra base, registrar otro servidor ni crear usuarios/roles para esta práctica.

El modelo anterior sigue en `floatmate`. Las funciones anteriores siguen en `floatmate_programacion`. La federación sigue en `floatmate_remoto` y `floatmate_global`.

El archivo 03 lee tus tablas locales y crea una **instantánea independiente** en el esquema nuevo. Los cambios posteriores en un modelo no se sincronizan automáticamente con el otro. Esto es una ampliación académica del mismo proyecto; para convertirlo en el modelo operativo único haría falta decidir una migración y adaptar la aplicación.

Los scripts principales también sirven en **Sur > floatmate_sur**, leyendo sus propios datos. Para demostrar BDOO basta empezar en Norte. Ejecutar el módulo en Sur es opcional: no debes instalarlo dos veces en Norte creyendo que eso crea objetos en Sur.

## Pasos exactos en pgAdmin

1. Descomprime `FloatMate_BDOO_PostgreSQL.zip` y conserva todos sus archivos juntos.
2. Abre pgAdmin y expande el servidor **Norte**.
3. Expande **Databases** y selecciona **floatmate_norte**. No abras Query Tool sobre `postgres`.
4. Clic derecho en **floatmate_norte > Query Tool**. Confirma que la pestaña diga esa base.
5. Activa **Auto-commit**. Los archivos de instalación tienen su propio BEGIN/COMMIT. Si la pestaña quedó en transacción fallida por un error previo, ejecuta `ROLLBACK;` antes de continuar; esto descarta cambios pendientes de esa transacción.
6. Usa **Open File** (icono de carpeta) para abrir `00_comprobar_base.sql`. Ejecuta todo con F5, sin dejar seleccionado un fragmento. Debe informar base correcta y mostrar datos en tus tablas.
7. Abre `01_modelo_objetos.sql` y ejecuta completo con F5. Crea tipos, dominios, clases y relaciones. Ejecuta este archivo una sola vez.
8. Abre `02_metodos_y_reglas.sql` y ejecuta completo. Crea métodos, vistas y triggers. Es normal ver avisos de triggers que todavía no existían durante la primera instalación.
9. Abre `03_importar_datos_actuales.sql` y ejecuta completo. Carga tus registros actuales con UUID persistentes. Repetir este archivo no vuelve a importar ni sobrescribe la instantánea.
10. En el árbol, clic derecho sobre **Schemas > Refresh**. Expande **floatmate_objetos > Tables**, **Types**, **Domains**, **Functions** y **Procedures**. Ver `public` en el árbol es normal: lo importante es dónde están estos objetos.
11. Abre `04_consultas_sustentacion.sql`. Selecciona y ejecuta cada consulta para comprender sus resultados; también puede ejecutarse todo y revisar los resultados individualmente.
12. Abre `05_pruebas_automaticas.sql` y ejecuta todo. En **Messages** debe aparecer `RESULTADO: todas las pruebas BDOO superadas`. Termina con ROLLBACK y no conserva los viajes del ensayo.
13. Si la federación Norte-Sur anterior está funcionando, ejecuta `06_puente_bdd_opcional.sql` desde Norte. Este archivo muestra datos distribuidos como valores compuestos. Es opcional.
14. Para sustentar paso a paso, usa `07_demostracion_guiada.sql`: ejecuta sus seis secciones en orden, una por una, en la misma pestaña. La última hace ROLLBACK. No cierres la pestaña durante la demostración.
15. `08_crear_objeto_ejemplo.sql` demuestra cómo construir un nuevo vehículo: crea su identidad y luego su instancia de BusUrbano dentro de la misma transacción. Ejecuta el archivo completo; al final revierte el ejemplo.

No ejecutes los archivos 01-03 en orden distinto. Si 01 informa que el esquema existe y ya lo ejecutaste correctamente, sigue con 02; el script no borra el esquema. Si aparece un error diferente, conserva su mensaje exacto para identificarlo.

## Qué significa BDOO con un ejemplo real del proyecto

Piensa en un bus como una entidad con identidad, datos y operaciones. La placa, el estado y la ficha describen ese bus. Consultar kilómetros para mantenimiento o calcular un costo son operaciones sobre esos datos. En el modelo nuevo, el objeto queda almacenado y puede recuperarse por su UUID después de cerrar y abrir la conexión.

Una **clase** es el molde. `bus_urbano` define qué datos tienen los buses urbanos. Un **objeto** es una instancia concreta: por ejemplo, la fila de FTA101. Un **atributo** describe el objeto: placa, estado, capacidad o puertas. Un **método** realiza una operación: describir el bus, calcular su costo o iniciar el viaje.

PostgreSQL no ofrece aquí clases con métodos miembros al estilo Java/C#. Las clases se representan mediante tablas y tipos de fila, y los métodos mediante funciones/procedimientos externos que trabajan con esos objetos. Esa equivalencia debe explicarse con precisión.

## Modelo de clases

```text
Vehiculo (superclase conceptual abstracta)
|-- BusUrbano: puertas y accesibilidad
|-- BusIntermunicipal: aire acondicionado y bodega
`-- Microbus: servicio especial

Vehiculo contiene FichaTecnica y Equipamiento[]
Conductor contiene Contacto y Licencia
Ruta contiene Paradas[]
Viaje referencia Vehiculo, Conductor y Ruta mediante UUID
Mantenimiento referencia Vehiculo mediante UUID
```

La composición significa que un objeto contiene una estructura de datos: un conductor contiene su contacto y licencia. La asociación significa que apunta a otro objeto con identidad propia: un viaje referencia al conductor, al vehículo y a la ruta.

Los atributos nuevos que antes no existían (puertas, accesibilidad, aire, bodega, servicio especial, equipamiento) toman valores de demostración definidos como DEFAULT. No se presentan como características verificadas de los vehículos reales. Las paradas iniciales son únicamente origen y destino.

## Qué crea cada parte

| Concepto del profesor | Implementación | Cómo demostrarlo |
|---|---|---|
| Clase y objeto | Tablas y tipos de fila; una fila es una instancia | Consultar `v_flota` |
| Atributos | Placa, ficha, estado, puertas, bodega, etc. | Consultar un hijo y sus campos |
| Métodos | Funciones y procedimientos del archivo 02 | Ejecutar SELECT o CALL |
| Encapsulamiento | Procedimientos agrupan las operaciones y validaciones | Iniciar y cerrar un viaje con un CALL |
| Herencia | Tres tablas con `INHERITS (vehiculo)` | SELECT padre, SELECT ONLY y pg_inherits |
| OID | UUID persistente, PK y trigger que impide cambiarlo | Intentar UPDATE del UUID en la prueba |
| Tipos compuestos | `t_contacto`, `t_licencia`, `t_ficha` | `(contacto).telefono`, `(ficha).capacidad` |
| JSON nativo | Expediente, detalle y reconstrucción de objetos | `fn_viaje_json`, `jsonb_pretty` |
| Colecciones (adicional) | `paradas text[]` y `equipamiento text[]` | `unnest` y `cardinality` |
| Sobrecarga (adicional) | `fn_describir` y `fn_costo` con tres firmas | `v_comportamiento` |

## OID: qué es y cómo lo hacemos correctamente

El profesor explica que la identidad es única, inmutable e independiente de los atributos. En este módulo se representa con una columna llamada `oid` de tipo **uuid**, generada con `gen_random_uuid()`. Cambiar estado o kilometraje conserva el UUID; intentar modificar el UUID genera un error.

Este OID conceptual no es el tipo `oid` del catálogo del motor, no es `tableoid`, no es el número de fila ni es la placa. `tableoid` se usa solamente para mostrar de qué tabla física proviene una instancia.

La tabla `identidad_vehiculo` centraliza el UUID de los vehículos y su correspondencia con la terminal y el ID relacional original. Permite relaciones por FK incluso cuando el vehículo está almacenado en una tabla hija. La placa es única en ese registro central y cada hijo debe coincidir con él.

Al finalizar la transacción, una restricción diferida comprueba que cada identidad tenga exactamente una instancia en los hijos. Crear una identidad sin crear su objeto no queda permitido al COMMIT.

## Herencia: por qué el padre devuelve 15 y ONLY devuelve 0

`vehiculo` es el padre y sus tres hijos tienen las columnas comunes más las propias. PostgreSQL incluye los hijos cuando haces `SELECT * FROM floatmate_objetos.vehiculo`. En cambio, `SELECT * FROM ONLY floatmate_objetos.vehiculo` consulta únicamente las filas físicas del padre.

La implementación considera abstracto al padre: un trigger bloquea INSERT directos. Por eso ONLY devuelve cero; los objetos están en las subclases. Con tus 15 vehículos iniciales se obtienen 5 urbanos, 5 intermunicipales y 5 microbuses. No faltan datos: la superclase los reúne.

En PostgreSQL, PRIMARY KEY, UNIQUE y FOREIGN KEY no se heredan ni garantizan unicidad entre padre e hijos. Por eso los hijos tienen sus propias restricciones y hacen referencia al registro central. Los INSERT tampoco se distribuyen automáticamente a los hijos.

## Encapsulamiento: qué puedes afirmar

`sp_programar_viaje`, `sp_aprobar_control`, `sp_iniciar_viaje` y `sp_cerrar_viaje` agrupan reglas y cambios. Desde fuera se invoca la operación sin repetir todo su SQL. Eso aplica encapsulamiento de la lógica del negocio.

Los tipos compuestos agrupan atributos; los dominios controlan sus valores. Los triggers protegen identidad y validaciones aunque se escriba SQL directo.

No se implementan atributos privados del lenguaje ni un control de acceso de producción. La práctica se ejecuta con tu usuario actual y no crea roles nuevos. Un administrador mantiene acceso directo a las tablas. Si el profesor pide ocultamiento estricto por permisos, eso sería una ampliación concreta de esta entrega.

## Métodos incluidos

- `fn_contacto`: construye un contacto tipado y valida teléfono/correo.
- `fn_km_restantes`: calcula cuántos kilómetros faltan para mantenimiento.
- `fn_describir`: tiene tres versiones, una por subclase; cada una utiliza sus atributos propios.
- `fn_costo`: tiene tres versiones; calcula un costo ficticio según clase y distancia.
- `fn_vehiculo_json`: recupera un vehículo con sus atributos comunes y específicos, más su descripción.
- `fn_viaje_json`: recupera un viaje y reconstruye sus objetos asociados como JSONB.
- `sp_programar_viaje`: crea un viaje, verifica disponibilidad y deja actuar las restricciones de recursos/capacidad.
- `sp_aprobar_control`: registra control aprobado y ticket en el expediente del viaje programado; sirve como método didáctico, no realiza mediciones de alcoholemia.
- `sp_iniciar_viaje`: exige control y ticket, fecha de salida, licencia vigente y disponibilidad; cambia estados de viaje, vehículo y conductor.
- `sp_cerrar_viaje`: valida llegada/kilometraje, finaliza viaje, actualiza ficha y libera vehículo/conductor.

`fn_describir(bus_urbano)` y `fn_describir(microbus)` muestran sobrecarga según el tipo de argumento. No representan despacho virtual automático por herencia: las consultas pasan el tipo de fila concreto de cada hijo. Esta demostración adicional no figura como requisito expreso del PDF.

Las tarifas son ejemplos académicos en COP/km: urbano 1400, intermunicipal 2200 más 200 si tiene aire, microbús 1000. No son precios del negocio ni normas reales.

## Resultados esperados con la carga inicial

| Objeto | Registros |
|---|---:|
| Vehículos vistos desde la superclase | 15 |
| Filas físicas solo en el padre | 0 |
| Identidades de vehículo | 15 |
| Bus urbano | 5 |
| Bus intermunicipal | 5 |
| Microbús | 5 |
| Conductores | 15 |
| Rutas | 15 |
| Viajes | 15 |
| Mantenimientos | 15 |

Si agregaste registros al modelo original, los resultados varían: 03 importa los datos locales presentes en ese momento. La cantidad 15 pertenece a tu carga inicial, no se fuerza rellenando subclases con vehículos inventados.

## Qué revisan las pruebas

Las pruebas comprueban herencia, conteos, identidad sin duplicados, métodos sobrecargados, OID inmutable, dominio compuesto inválido, bloqueo del padre abstracto, identidad sin instancia, sobrecupo, inicio sin control, programación, inicio autorizado, cierre, navegación JSON y auditoría. Los cambios del ensayo se revierten.

También se verificó reejecutar 02 y 03 sin alterar los UUID de la carga. El informe adjunto describe el entorno usado y los límites de esa verificación.

## Relación con Norte y Sur

BDD responde a **dónde están los datos**: en Norte y Sur, unidos por FDW. BDOO responde a **cómo se representan y se operan**: objetos con tipos, identidad, herencia y métodos. Son conceptos que pueden convivir.

06 consulta tus vistas globales previas y muestra fichas/contactos compuestos en vivo desde ambos nodos. No crea copias de Sur, no instala este módulo en Sur y no asigna UUID persistentes a esas proyecciones. Si instalas 01-03 también en Sur, esos objetos son locales a Sur; sus UUID no aparecen automáticamente en el FDW previo.

## Respuesta breve para sustentar

“Ampliamos FloatMate con un modelo objeto-relacional en PostgreSQL. Representamos cada vehículo como un objeto persistente con identidad UUID inmutable. La superclase Vehículo tiene tres especializaciones: BusUrbano, BusIntermunicipal y Microbús. Agrupamos atributos mediante tipos compuestos, implementamos métodos con funciones y procedimientos, y usamos JSONB para recuperar objetos relacionados. Conservamos la actividad distribuida anterior y mostramos cómo puede coexistir con la representación por objetos.”

## Fuentes y alcance

- Documento enviado por el profesor: `SD1008_Bases_de_Datos_II_UND2_Bases_de_Datos_Orientadas_a_Objetos_(BDOO).pdf`, diapositivas 2-8 para conceptos; diapositiva 9 para diferencia BDD/BDOO.
- PostgreSQL: https://www.postgresql.org/about/
- Tipos compuestos: https://www.postgresql.org/docs/18/rowtypes.html
- Herencia y limitaciones: https://www.postgresql.org/docs/18/ddl-inherit.html
- CREATE TYPE: https://www.postgresql.org/docs/18/sql-createtype.html

La entrega cubre los conceptos visibles en el documento. La nota depende de la sustentación y de cualquier indicación adicional que el profesor dé en clase.
