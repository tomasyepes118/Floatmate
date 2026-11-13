# Operación y verificación

## Registros

- **Rutas y conductores.** Se crean y editan desde Catálogos. Una ruta con historial conserva su recorrido y duración. Las rutas y conductores con viajes vigentes conservan las condiciones necesarias para esos viajes.
- **Combustible.** Se registra por vehículo en litros y COP. Laravel calcula litros × precio unitario y redondea a dos decimales.
- **Mantenimiento.** Conserva el kilometraje del servicio y el próximo umbral. Un vehículo en mantenimiento vuelve a estar disponible al registrar un servicio válido.
- **Incidentes.** Se asocian a un viaje en curso o finalizado y al vehículo correspondiente. Se registra la fecha, la gravedad, el detalle y el nombre del perfil que lo guardó.
- **CSV.** La descarga incluye los registros completos del módulo, con encabezados y separador de punto y coma.

## Cuentas opcionales

Desde `backend`, genera dos hashes con contraseñas de prueba distintas elegidas por el equipo. Ejecuta el siguiente comando una vez por cuenta:

```powershell
php -r "echo password_hash(readline('Contraseña de prueba: '), PASSWORD_BCRYPT), PHP_EOL;"
```

En `.env`, pega los hashes entre comillas simples en `DEMO_OPERADOR_HASH` y `DEMO_CONSULTA_HASH`. Los nombres de usuario son `operador` y `consulta`. Reinicia Laravel tras editar el archivo. Usa datos ficticios y mantén estas cuentas en el entorno de laboratorio.

| Perfil | Acceso |
|---|---|
| Administrador | Inventario, catálogos, despacho, registros y exportaciones |
| Operador | Consulta del inventario, despacho, registros y exportaciones |
| Consulta | Resumen y exportaciones |

## PostgreSQL

1. Crea una base de datos dedicada a FloatMate y un usuario con permiso para ejecutar migraciones. Habilita `pdo_pgsql` en PHP.
2. Configura `FLOTA_STORAGE=pgsql` y las variables `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` y `DB_SSLMODE` en `backend/.env`.
3. Ejecuta `php artisan migrate` desde `backend`.
4. Para conservar datos locales, antes de abrir la aplicación ejecuta `php artisan flota:importar "ruta\a\flota.json"`. La importación requiere que la tabla operativa esté vacía. Si omites este paso, la primera consulta crea los datos ficticios.

PostgreSQL y el archivo local son almacenes independientes. La integración usa una tabla operativa JSONB y es independiente de los scripts académicos Norte/Sur y DWH.

## Pruebas reproducibles

Ejecuta `composer test` en `backend` y `npm run build` en `frontend`. Para el recorrido de Chromium, arranca Laravel desde una terminal nueva con:

```powershell
$env:DEMO_E2E = 'true'
$env:FLOTA_STORAGE = 'json'
$env:DEMO_DATA_PATH = Join-Path ([IO.Path]::GetTempPath()) ('floatmate-e2e-' + [guid]::NewGuid())
php artisan serve --host=127.0.0.1 --port=8000 --no-reload
```

Con Next.js abierto, ejecuta `npx playwright install chromium` y `npm run test:e2e` desde `frontend`. Los resultados quedan en `frontend/test-results/avance-4`.
