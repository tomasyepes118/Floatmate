# FloatMate

Aplicación académica para gestionar flotas de buses con **Next.js, JavaScript y Laravel**.

## Segundo avance

Esta versión conserva el login y el panel de la primera etapa e incorpora:

- Consulta, búsqueda por placa, código o marca y filtro por estado de vehículos.
- Registro de vehículos con placa, código, tipo, marca, modelo, capacidad, kilometraje, próximo mantenimiento y estado.
- Consulta y filtros de viajes por ruta, conductor, placa y estado.
- Programación con ruta activa, vehículo y conductor disponibles, fecha, pasajeros y observaciones.
- Validación en Laravel de duplicados, capacidad, fechas futuras y cruces de horario.
- Panel conectado a los registros, con cifras que cambian al crear vehículos y viajes.
- Pantallas y formularios adaptados a computador y móvil.

**No utiliza base de datos.** Laravel conserva los registros de demostración en un archivo JSON local. Los datos permanecen al recargar, cerrar sesión y reiniciar el servidor.

## Tecnologías

| Parte | Herramientas |
|---|---|
| Interfaz | Next.js 16, React 19 y JavaScript con JSX |
| Servidor | Laravel 13 y PHP 8.4 |
| Diseño | CSS y Bootstrap local |
| Pruebas | PHPUnit y Playwright |
| Datos de esta etapa | JSON local, sin PostgreSQL, MySQL ni SQLite |

## Estructura

```text
FloatMate/
├── frontend/        Pantallas, componentes, estilos y pruebas de navegador
├── backend/         API, validaciones y almacenamiento de demostración
├── docs/            Guía, capturas y comprobaciones
├── .github/         Compilación y pruebas automáticas
└── README.md        Instalación y ejecución
```

## Instalación inicial

Necesitas **Node.js 22 o superior con npm, PHP 8.4 y Composer 2**. La instalación inicial requiere internet.

Abre en VS Code la carpeta que contiene `frontend` y `backend`. Desde una terminal en esa carpeta:

```powershell
cd backend
composer install
Copy-Item .env.example .env
php artisan key:generate
```

Abre otra terminal desde la raíz:

```powershell
cd frontend
npm ci
Copy-Item .env.example .env.local
```

La copia de los archivos `.env` y la generación de clave se hacen solo en una instalación nueva. No ejecutes migraciones ni crees una base de datos. En macOS o Linux usa `cp` en lugar de `Copy-Item`.

## Cómo abrir FloatMate desde VS Code

### Iniciar Laravel

En **Terminal → Nueva terminal**, desde la raíz del proyecto:

```powershell
cd backend
php artisan serve --host=127.0.0.1 --port=8000
```

Cuando aparezca `Server running on http://127.0.0.1:8000`, deja esa terminal abierta.

### Iniciar Next.js

Pulsa **+** para abrir una segunda terminal. Desde la raíz:

```powershell
cd frontend
npm run dev
```

Si la terminal se abre dentro de `backend`, usa `cd ../frontend` en lugar de `cd frontend`.

### Abrir el navegador

Abre [http://127.0.0.1:3000](http://127.0.0.1:3000).

- Usuario: `admin`
- Contraseña: `floatmate123`

El puerto 3000 muestra la aplicación y el 8000 ejecuta Laravel. Usa siempre `127.0.0.1` para conservar la sesión en el mismo dominio. No se usa Live Server.

Para detenerla, presiona **Ctrl + C** en ambas terminales.

## Qué puedes probar

1. Ingresa y abre Vehículos.
2. Busca una placa y filtra por estado.
3. Registra un vehículo y prueba una placa repetida para ver el mensaje.
4. Abre Viajes, selecciona una ruta y programa una salida futura.
5. Revisa que los pasajeros no superen la capacidad y que no se crucen horarios del bus o del conductor.
6. Vuelve al Resumen para consultar las cifras actualizadas.
7. Sal y vuelve a ingresar: los registros deben conservarse.

## Dónde se guardan los datos

El archivo `backend/storage/app/demo/flota.json` se crea automáticamente en el primer uso. Contiene vehículos, viajes y los catálogos de rutas y conductores de demostración. No se publica en Git ni se incluye con datos generados en el ZIP.

Los catálogos de rutas y conductores ya vienen preparados; en este avance se seleccionan al programar, pero no tienen pantallas de administración.

No elimines el JSON si quieres conservar tus registros. En una copia nueva del proyecto se genera la muestra inicial: 5 vehículos y 4 viajes. Las dos salidas programadas se colocan en fechas futuras al crear ese archivo por primera vez.

## Pruebas

Desde `backend`:

```powershell
composer test
```

Desde `frontend`:

```powershell
npm run build
```

El recorrido de navegador crea registros; por eso se ejecuta con una carpeta de prueba separada. Los pasos están en [la guía completa](docs/DOCUMENTACION.md#pruebas-de-navegador-con-datos-separados).

## Documentación y alcance

- [Guía completa](docs/DOCUMENTACION.md).
- [Resultados de comprobaciones](docs/VALIDACION.md).
- [Capturas](docs/capturas).
- `docs/Documentacion.html` permite leer la guía localmente en un navegador.

Quedan para después la edición y desactivación de registros, el ciclo de salida y llegada del viaje, los demás módulos, los usuarios con permisos propios y la conexión a PostgreSQL. El acceso actual sigue siendo una cuenta compartida de demostración.

## Equipo

Tomás Yepes · Cristian Benites · Mateo Gallo.

Las dependencias conservan sus licencias. Esta entrega no concede una licencia general de código abierto a FloatMate.
