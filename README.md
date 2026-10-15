# FloatMate

Gestión de flotas de buses: vehículos, viajes, rutas y mantenimiento.

Proyecto Integrador de Aula (PIA) de Programación Web, Ingeniería de Software y Bases de Datos II. Este repositorio reúne código, modelos de datos, diagramas y evidencias de las entregas. La organización conserva los nombres de las entregas para facilitar la revisión de la profesora.

## Estado del proyecto

| Componente | Estado actual |
| --- | --- |
| Web | Prototipo HTML, CSS, Bootstrap y JavaScript con almacenamiento en el navegador |
| POO | Aplicación de consola C# / .NET 8 con herencia, interfaces y polimorfismo |
| Datos | Scripts PostgreSQL para nodos Norte/Sur, federación, programación avanzada, BDOO y DWH |
| Diseño | Diagramas entidad-relación, casos de uso, clases y objetos; fuentes DOT y SVG |
| Documentación | Factibilidad, informes, capturas y guías de ejecución |

La web todavía no está conectada a PostgreSQL ni tiene autenticación de servidor. No se presenta como un sistema listo para producción. Los documentos de requerimientos I, II y III, los manuales y el plan completo de pruebas siguen señalados como pendientes donde no existe evidencia.

## Inicio rápido

### Prototipo web

Abra [index.html](06_Material_adicional/Codigo_y_bases_de_datos/01_Codigo_web/FloatMate_Web/index.html) en el navegador. Funciona sin instalación ni conexión a internet. Use `admin` / `floatmate123`, exclusivamente para la demostración.

Permite consultar y registrar vehículos, programar viajes y ver un panel de resumen. Los registros se guardan en el navegador; no se comparten entre usuarios o equipos.

El [mockup de la entrega de diagramas](05_Tareas_adicionales/2026-10-13_Diagramas_y_mockup/Mockup/01_Parte_I/01_Prototipo_navegable/index.html) se conserva como evidencia de esa entrega.

### Consola C#

Instale el SDK de .NET 8 y ejecute desde la raíz:

```powershell
dotnet run --project "05_Tareas_adicionales/POO_Herencia_y_polimorfismo/FloatMate.POO/FloatMate.Console/FloatMate.Console.csproj"
```

La demostración evalúa vehículos para rutas urbanas e intermunicipales. Consulte la [guía de POO](05_Tareas_adicionales/POO_Herencia_y_polimorfismo/FloatMate.POO/README.md).

### PostgreSQL

Empiece por la [guía de ejecución con roles](06_Material_adicional/Codigo_y_bases_de_datos/02_Base_de_datos/01_PostgreSQL_con_roles/README_EJECUCION.md). Requiere PostgreSQL 14 o superior y permisos para crear bases, roles y extensiones. Ejecute los scripts en el orden de esa guía sobre una instalación de laboratorio.

La [variante sin roles](06_Material_adicional/Codigo_y_bases_de_datos/02_Base_de_datos/02_PostgreSQL_sin_roles/LEEME_PASO_A_PASO.md) es una alternativa; no mezcle las dos secuencias en una misma instalación. La [federación CSV y DWH](06_Material_adicional/Codigo_y_bases_de_datos/02_Base_de_datos/03_Federacion_CSV_DWH/LEEME_IMPLEMENTACION.md) tiene requisitos y orden propios.

## Mapa del repositorio

| Carpeta | Contenido |
| --- | --- |
| `01_Analisis_de_factibilidad/` | Documento de factibilidad |
| `02_Requerimientos_Parte_I/` | Estado de la entrega I |
| `03_Requerimientos_Parte_II/` | Estado de la entrega II |
| `04_Diagramas_UML/` | Diagramas vigentes y fuentes editables |
| `05_Tareas_adicionales/` | Informes, mockup, POO y guías académicas |
| `06_Material_adicional/Codigo_y_bases_de_datos/` | Web, SQL y referencias de pruebas |
| `06_Material_adicional/Por_completar/` | Documentos todavía pendientes |
| `06_Material_adicional/Archivo/` | Versiones anteriores e inventarios históricos |
| `docs/` | Arquitectura, criterios de versionado y próximos pasos |
| `scripts/` | Comprobaciones del repositorio |

Los inventarios de `Archivo/` corresponden a la organización anterior y pueden mencionar archivos excluidos o ya reubicados. Los ZIP, herramientas descargadas y temporales se conservan en el equipo y quedan fuera de Git.

## Comprobaciones

Con Node.js 22 o superior:

```powershell
node scripts/check-repository.mjs
```

Comprueba referencias locales en HTML, sintaxis JavaScript y archivos que no deben publicarse. GitHub Actions ejecuta estas comprobaciones y compila y ejecuta la consola con .NET 8 en cada push o pull request. No valida la ejecución de PostgreSQL ni sustituye las pruebas funcionales de la web.

Consulte [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md) y el [plan de evolución](docs/ROADMAP.md).

## Equipo y uso

- Tomás Yepes
- Cristian Benites
- Mateo Gallo

No se ha concedido una licencia general de código abierto. La licencia incluida de Bootstrap se conserva junto a sus archivos de terceros.
