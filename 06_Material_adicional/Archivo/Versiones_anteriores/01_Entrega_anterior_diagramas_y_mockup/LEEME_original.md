# FloatMate entrega de modelado

Abra FloatMate_Diagramas_y_Mockup.pdf para revisar los cinco puntos pedidos.

- diagramas: cuatro diagramas en SVG y PNG; los archivos DOT son editables con Graphviz.
- mockup/index.html: prototipo navegable sin instalación ni internet. Datos de demostración.
- fuentes/modelo.json: diccionario completo extraído del DDL.
- fuentes/modelo_norte.sql: esquema que respalda el modelo.

## Recorrido
Abra mockup/index.html. Usuario admin, clave floatmate123. Consulte el panel, busque vehículos, registre uno, consulte viajes y programe uno seleccionando ruta y conductor. Pruebe una placa repetida y una fecha pasada.

## Alcance
La base principal es relacional PostgreSQL, con fragmentos NOR y SUR. Los tipos compuestos del ejercicio BDOO y los campos JSONB no la convierten en MongoDB ni en una base de grafos. La parte 1 comprende acceso, panel, vehículos, programación de viajes y sus formularios. Los otros módulos quedan modelados para posteriores partes.

La autenticación, los permisos y los métodos del diagrama lógico son diseño propuesto; el prototipo los simula. No se conecta a PostgreSQL. El diagrama de objetos muestra una instancia de los datos semilla del nodo Norte, no el estado actual de un servidor.

## Informe editable
FloatMate_Diagramas_y_Mockup_editable.docx contiene el texto y las tablas editables en Word. Los diagramas se insertan como imágenes; sus archivos DOT y SVG están disponibles en diagramas para editar su contenido. La versión Word usa páginas A3 para facilitar la lectura de los diagramas.
