# FloatMate · Cuarto avance

Aplicación académica de gestión de flotas. Esta entrega reúne el ciclo de despacho, los catálogos de rutas y conductores y los registros de combustible, mantenimiento e incidentes.

## Instalación en Windows

Necesitas Node.js 22 o superior, PHP 8.4 y Composer 2. Prepara las dependencias una vez con internet. Abre esta carpeta en VS Code y usa dos terminales.

En `backend`:

```powershell
composer install
Copy-Item .env.example .env
php artisan key:generate
```

En `frontend`:

```powershell
npm ci
Copy-Item .env.example .env.local
npm run build
```

Si ya tienes configurados ambos archivos de entorno, consérvalos. Para arrancar, ejecuta `php artisan serve --host=127.0.0.1 --port=8000 --no-reload` en `backend` y `npm run start` en `frontend`. Abre [FloatMate local](http://127.0.0.1:3000) con el usuario `admin` y la contraseña de demostración `floatmate123`.

Para desarrollar, usa `npm run dev`.

## Mostrar FloatMate desde cero

Desde `backend`, prepara un almacén vacío y arranca Laravel. Con Next.js abierto, entra a la aplicación y pulsa **Recorrido guiado**.

```powershell
$env:DEMO_DATA_PATH = (php artisan flota:preparar-demo --vacia).Trim()
$env:FLOTA_STORAGE = 'json'
php artisan serve --host=127.0.0.1 --port=8000 --no-reload
```

Detén la instancia anterior de Laravel antes de usar el mismo puerto. La copia comienza sin vehículos, rutas, conductores, viajes ni registros. El recorrido enlaza cada pantalla y propone datos ficticios para crear el primer viaje.

## Preparar el pitch

En una terminal nueva, desde `backend`, prepara y arranca una copia aislada:

```powershell
$env:DEMO_DATA_PATH = (php artisan flota:preparar-demo).Trim()
$env:FLOTA_STORAGE = 'json'
php artisan serve --host=127.0.0.1 --port=8000 --no-reload
```

Detén primero cualquier instancia de Laravel que use el puerto 8000. Deja Next.js abierto. Cada vez que ejecutes la preparación obtendrás datos nuevos para repetir el ensayo.

1. En **Viajes**, registra un ticket nuevo para **V-9002** con un resultado simulado de `0.015` mg/L. Muestra el control rechazado.
2. En **V-9001**, registra otro ticket con `0` mg/L. Inicia el viaje y muestra el estado **En curso**.
3. Finaliza V-9001 con **35.000 km** de llegada. En **Vehículos**, busca **TPQ482** y muestra el estado **Mantenimiento**.
4. En **Registros → Mantenimientos**, registra el servicio de TPQ482 a **35.000 km** y su próximo mantenimiento a **40.000 km**. El bus vuelve a **Disponible**.

Para mostrar la revisión antes del despacho, abre **Programar viaje** en una copia nueva del pitch. Elige Medellín–Rionegro, KPT641, Daniel López, 20 pasajeros y una salida futura que no cruce la programación. Pulsa **Revisar elegibilidad**. KPT641 tiene 20 km disponibles antes del mantenimiento y el recorrido requiere 42 km. El resultado ofrece otros buses que cumplen las condiciones. Puedes elegir TPQ482 si el horario está libre y volver a revisar. Cierra el formulario sin guardar si vas a continuar con los viajes de ensayo V-9001 y V-9002.

## Material del pitch

- [Presentación editable en PowerPoint](docs/pitch/FloatMate-Pitch.pptx)
- [Guion, pasos de la demostración y preguntas del jurado](docs/pitch/Guion-Pitch-FloatMate.md)
- [Resultados de las pruebas](docs/VALIDACION.md)

## Datos, cuentas y pruebas

- Al programar, **Revisar elegibilidad** explica problemas de capacidad, disponibilidad, licencia, horario y kilometraje. Si hay un bus compatible con la ruta y el conductor seleccionados, puedes elegirlo desde el resultado. La revisión no reserva recursos y Laravel vuelve a comprobar las reglas al confirmar.

- El modo local guarda los datos en `backend/storage/app/demo/flota.json`. Puede abrir datos del tercer avance y agrega las nuevas colecciones al leerlos.
- PostgreSQL es una opción de persistencia. Usa un documento JSONB protegido por una transacción y bloqueo de fila. Consulta [configuración, roles y pruebas](docs/OPERACION.md).
- Las cuentas opcionales de Operador y Consulta se habilitan con hashes propios. El administrador gestiona catálogos y vehículos. El operador despacha y registra actividad. Consulta accede al resumen y a exportaciones.
- Los incidentes de esta entrega conservan detalle y gravedad. El alojamiento de evidencias, el cálculo de consumo por distancia y la integración con servicios externos quedan fuera del alcance implementado.

**Equipo** · Tomás Yepes, Cristian Benites y Mateo Gallo.
