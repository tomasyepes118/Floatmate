# Arquitectura actual

Los componentes se desarrollan como entregas relacionadas y todavía funcionan por separado.

```text
Navegador -> prototipo HTML/CSS/JavaScript -> almacenamiento local

Consola .NET 8 -> GestorFlota -> dominio de vehículos, rutas e interfaces

PostgreSQL Norte -> postgres_fdw -> PostgreSQL Sur
        |
        +-> vistas globales
        +-> laboratorio CSV / ETL / DWH
```

La web no llama a una API ni ejecuta los scripts SQL. La consola demuestra reglas de asignación con datos definidos en el programa. PostgreSQL tiene sus propios scripts y guías de instalación.

La carpeta `04_Diagramas_UML/` contiene el diseño vigente; los documentos del archivo histórico pueden reflejar estados anteriores. No debe suponerse que cada elemento del modelo ya está implementado en la web.

## Criterio de organización

Se conserva la estructura por entregas para mantener las referencias de informes, capturas y revisión académica. El README central ofrece acceso directo al código y a las guías. Una futura reorganización a aplicaciones y servicios debe actualizar enlaces y documentos en el mismo cambio.

## Ruta hacia una aplicación integrada

Definir los requerimientos pendientes, elegir y documentar una API, integrar la persistencia y reemplazar el login de demostración. Estas decisiones siguen pendientes y no se representan como funciones existentes.
