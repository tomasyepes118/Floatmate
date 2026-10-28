# FloatMate: explicación de esta versión

**Entrega:** login y vista principal. **Fecha:** 27 de octubre de 2026.

## 1. Qué estamos entregando

Organizamos el inicio de FloatMate en un proyecto pequeño y claro. Por ahora el usuario puede ingresar,
consultar el resumen de la flota y cerrar su sesión. Las otras ventanas y formularios quedan para otra entrega.

Esta versión usa Next.js para las pantallas y Laravel para atender las solicitudes. Los datos son de demostración.
No necesita PostgreSQL, MySQL, SQLite, pgAdmin, Redis ni un servidor de correo.
No se incluyeron los laboratorios SQL, el DWH, los informes antiguos ni la consola C#.
El material anterior se conserva en el historial de Git y en la copia local original del proyecto.

## 2. Tecnologías y lenguaje

| Tecnología | Para qué la usamos |
|---|---|
| Next.js 16.4.3 | Organiza las rutas y presenta las páginas |
| React 19.3.1 | Construye los componentes de la interfaz |
| JavaScript con JSX | Programa la parte visual y sus interacciones |
| Laravel 13 | Valida el acceso, administra la sesión y entrega el resumen |
| PHP 8.4 | Ejecuta Laravel y las pruebas del servidor |
| CSS y Bootstrap local | Mantienen la distribución y apariencia del mockup |
| npm y Composer | Instalan las dependencias de cada aplicación |
| Playwright | Comprueba el recorrido en navegador y genera capturas |

Usamos JavaScript, no TypeScript. Los textos, mensajes y explicaciones están en español y conservan
el tono sencillo del proyecto: “Iniciar sesión”, “Ingresa para consultar tu flota” y “Resumen de la flota”.
El detalle exacto de las versiones instaladas queda en `frontend/package-lock.json` y `backend/composer.lock`.

## 3. Qué funciona

### Acceso

El usuario escribe su nombre y contraseña. Puede mostrar u ocultar la contraseña. Si los campos están vacíos,
el formulario solicita completarlos. Si los datos son incorrectos, aparece un mensaje y puede intentar otra vez.
Mientras se procesa la solicitud, el botón dice “Ingresando…” para evitar envíos repetidos.

El acceso de prueba es **admin / floatmate123**. Laravel compara la contraseña con un hash bcrypt y crea
una sesión en el servidor. La contraseña no se valida en el JavaScript del navegador.

La cuenta sigue siendo una cuenta compartida de demostración: no es todavía un sistema de usuarios de una empresa.
No hay registro, recuperación de contraseña, roles editables ni cuentas personales.

### Vista principal

El panel conserva el contenido de la referencia:

- Menú lateral con FloatMate, Resumen, Vehículos y Viajes.
- Perfil Tomas Yepes, Administrador, y acción Salir.
- Encabezado “Centro de operaciones” y aviso “Datos de demostración”.
- Cuatro indicadores: 5 vehículos registrados, 3 disponibles, 2 viajes programados y 1 en mantenimiento.
- Tabla de próximos viajes: Medellín - Rionegro y Medellín - Guatapé.
- Estado de los vehículos: 3 disponibles, 1 en viaje y 1 en mantenimiento.
- Bloque “Organiza tu operación”.

Los datos son fijos y están en `backend/app/Http/Controllers/ResumenController.php`.
Las fechas de octubre se conservan para coincidir con el mockup; no representan salidas actuales.

Vehículos, Viajes, Ver programación y Consultar vehículos se muestran, pero están deshabilitados.
No abren ventanas vacías, formularios ni pantallas que todavía no se han desarrollado.
Al poner el cursor sobre esos controles se indica que corresponden a una próxima entrega.

### Sesión y salida

Si alguien abre `/resumen` sin ingresar, vuelve a `/login`. Al recargar el panel, Laravel verifica la sesión.
Al salir, la sesión se invalida y el usuario regresa al acceso. La sesión tiene una duración de inactividad de
120 minutos. Si vence, el acceso al resumen requiere ingresar nuevamente.
Si Laravel está apagado, se muestra un mensaje para reintentar; no se inventa una sesión ni se muestran datos por fuera del servicio.

## 4. Cómo se conectan las partes

```text
Navegador (127.0.0.1:3000)
    |
    v
Next.js: /login y /resumen
    |
    | /api/* se reenvía al servidor
    v
Laravel (127.0.0.1:8000)
    |-- Valida las credenciales de demostración
    |-- Guarda la sesión en archivos locales
    |-- Entrega el resumen con datos de ejemplo
    `-- Invalida la sesión al salir
```

Next.js funciona como la entrada de la aplicación. El navegador solicita la API en el mismo origen,
y las reescrituras de `next.config.mjs` envían esas solicitudes a Laravel. Así no hace falta configurar CORS
ni exponer una dirección distinta en los componentes.

Al pedir una página protegida, Next.js envía las cookies recibidas a Laravel para verificar el acceso.
Las respuestas de sesión y resumen no se guardan en caché. El navegador no guarda contraseñas,
tokens de acceso ni registros de flota en `localStorage`.

La sesión es un archivo técnico temporal, no una base de datos. Se guarda en `backend/storage/framework/sessions`.
El caché técnico para limitar intentos se guarda en `backend/storage/framework/cache/data`.

## 5. Estructura del proyecto

```text
FloatMate-Inicio/
|-- README.md
|-- frontend/
|   |-- app/
|   |   |-- layout.js           Idioma, título y estilos compartidos
|   |   |-- page.js             Entrada que lleva al login
|   |   |-- login/page.js       Página de acceso
|   |   |-- resumen/page.js     Panel protegido
|   |   |-- not-found.js        Mensaje para rutas inexistentes
|   |   |-- globals.css         Diseño de FloatMate
|   |   `-- bootstrap.min.css   Estilos base locales
|   |-- components/
|   |   |-- Marca.js            Logo y nombre
|   |   |-- FormularioAcceso.js Formulario y mensajes
|   |   `-- BarraLateral.js     Menú, perfil y salida
|   |-- lib/
|   |   |-- api.js              Acciones del navegador con protección CSRF
|   |   `-- servidor.js         Consultas de Next.js a Laravel
|   |-- next.config.mjs         Reenvío de la API
|   |-- package.json
|   `-- package-lock.json
|-- backend/
|   |-- app/Http/Controllers/
|   |   |-- AccesoController.php
|   |   `-- ResumenController.php
|   |-- app/Http/Middleware/RequiereSesionDemo.php
|   |-- bootstrap/             Inicio de Laravel
|   |-- config/                Ajustes del servidor y cuenta demo
|   |-- public/index.php       Entrada HTTP de Laravel
|   |-- routes/web.php         Endpoints con sesión y CSRF
|   |-- storage/               Sesiones, caché y registros locales
|   |-- tests/                 Pruebas del acceso y del resumen
|   |-- artisan                Comandos de Laravel
|   |-- composer.json
|   `-- composer.lock
`-- docs/
    |-- DOCUMENTACION.md
    |-- Documentacion.html
    |-- VALIDACION.md
    `-- capturas/              Evidencia visual de PC y móvil
```

## 6. Instalación paso a paso

### Requisitos

Instala Node.js 22 o superior, npm, PHP 8.4 y Composer 2. Para PHP habilita las extensiones habituales de Laravel:
cURL, DOM, Fileinfo, Filter, Hash, Mbstring, OpenSSL, PCRE, PDO, Session, Tokenizer y XML.
ZIP facilita la instalación de Composer. PDO es una extensión del entorno: no implica crear una base de datos.
Para ejecutar las pruebas también se necesita XMLWriter. No necesitas instalar npm dentro de `backend`.

Puedes comprobar tu equipo con:

```powershell
node --version
npm --version
php --version
php -m
composer --version
```

### Preparar el servidor

Clona el repositorio o descomprime su ZIP. Abre una terminal en la raíz, donde aparecen `frontend` y `backend`:

```powershell
cd backend
composer install
Copy-Item .env.example .env
php artisan key:generate
php artisan serve --host=127.0.0.1 --port=8000
```

Conserva abierta esa terminal. La copia de `.env` y la generación de clave se hacen al preparar una copia nueva.
No vuelvas a sobrescribir `.env` en cada inicio. No uses `php artisan migrate`.

### Preparar las pantallas

Abre una segunda terminal en la raíz del proyecto:

```powershell
cd frontend
npm ci
Copy-Item .env.example .env.local
npm run dev
```

Entra a `http://127.0.0.1:3000` y usa las credenciales de demostración.
Para detener la aplicación, presiona Ctrl+C en ambas terminales.
En otro inicio solo necesitas el comando `php artisan serve ...` y `npm run dev`.
En macOS y Linux usa `cp` en lugar de `Copy-Item`.

### Comprobar la compilación

Desde `frontend`:

```powershell
npm run build
npm run start
```

Laravel debe seguir funcionando en el puerto 8000. Esta es una comprobación local de la compilación,
no una publicación en internet.

## 7. Configuración y puntos de cambio

| Archivo | Qué permite cambiar |
|---|---|
| `frontend/.env.local` | Dirección interna de Laravel mediante `LARAVEL_URL` |
| `backend/.env` | Nombre de la aplicación, clave, sesión y cuenta demo |
| `backend/config/demo.php` | Perfil de demostración y valores de respaldo de la cuenta |
| `backend/app/Http/Controllers/ResumenController.php` | Cifras, viajes y estados del panel |
| `frontend/app/globals.css` | Colores, tamaños, separación y adaptación a móvil |

Si cambias la dirección de Laravel, reinicia Next.js. Para una compilación de producción vuelve a compilar,
porque las reescrituras se preparan durante la compilación.
Si cambias la cuenta, actualiza también el aviso visible de credenciales de demostración del formulario.
`DEMO_PASSWORD_HASH` recibe un hash bcrypt, no la contraseña en texto.

## 8. API de esta entrega

| Método | Ruta | Función |
|---|---|---|
| GET | `/api/csrf` | Prepara la sesión y entrega el token del formulario |
| POST | `/api/login` | Recibe `usuario` y `clave`; abre la sesión si son correctos |
| GET | `/api/sesion` | Devuelve el perfil de la sesión actual |
| GET | `/api/resumen` | Devuelve indicadores, viajes y estados de ejemplo |
| POST | `/api/logout` | Cierra e invalida la sesión |

Las tres últimas rutas requieren sesión. Los POST requieren token CSRF y cookie de sesión.
Se limita el acceso a cinco intentos por minuto y dirección IP. Los campos incorrectos devuelven 422,
la falta de sesión devuelve 401, un token inválido devuelve 419 y el límite de intentos devuelve 429.

## 9. Relación con el mockup

Se siguieron las imágenes de acceso y panel del mockup compartido para esta versión. Se conservaron el fondo claro, los botones oscuros, la marca F, las tarjetas blancas,
el menú lateral, la tabla, los indicadores y los textos principales.
Los estilos base y Bootstrap vienen del prototipo que corresponde a esas capturas; no se cambió al diseño verde de otra versión.

Hay dos ajustes intencionales: el aviso del login describe una demostración con datos de ejemplo porque ahora Laravel
sí valida la sesión, y los accesos a módulos pendientes se deshabilitan por el alcance solicitado.
En móvil el contenido se reorganiza para que pueda leerse y usarse sin salir del ancho de la pantalla.
Las capturas de la implementación están en `capturas/` para revisar su apariencia.

## 10. Pruebas

Desde `backend` ejecuta:

```powershell
composer test
```

Las pruebas revisan acceso sin sesión, credenciales incorrectas, campos vacíos, acceso correcto,
datos del panel, salida, límite de intentos y ausencia de endpoints de módulos pendientes.
Usan sesión y caché en memoria; no crean bases ni ejecutan migraciones.
La protección CSRF se comprueba adicionalmente contra el servidor real, porque Laravel la omite en pruebas unitarias.

Para una comprobación manual:

1. Abre `/resumen` sin sesión: debe llevarte al login.
2. Usa una contraseña incorrecta: debe aparecer un mensaje.
3. Usa “Ver” y “Ocultar”: debe cambiar la visibilidad de la contraseña.
4. Ingresa con `admin / floatmate123`: debe aparecer el resumen.
5. Recarga: debes seguir dentro de la sesión.
6. Comprueba que los módulos pendientes no abran otras ventanas.
7. Pulsa Salir y vuelve a `/resumen`: debe pedir acceso otra vez.
8. Prueba en móvil: las tarjetas y los viajes deben adaptarse al ancho.

Los resultados de la revisión de esta entrega se registran en `VALIDACION.md`.

También se incluye una prueba de navegador en `frontend/tests/recorrido.mjs`. Con Laravel y Next.js iniciados,
desde `frontend` ejecuta:

```powershell
npx playwright install chromium
npm run test:e2e
```

La primera orden descarga el navegador de prueba. El recorrido genera las capturas en `docs/capturas`.
Revisa acceso, errores, sesión al recargar, salida, cookies, protección CSRF, módulos deshabilitados y ancho móvil.
Si acabas de probar varias contraseñas, espera un minuto para no alcanzar el límite de acceso.

## 11. Problemas frecuentes

| Situación | Cómo resolverla |
|---|---|
| “npm”, “php” o “composer” no se reconoce | Instala la herramienta y abre una terminal nueva |
| Composer informa una versión incompatible de PHP | Usa PHP 8.4 y revisa `php --version` |
| Composer indica que falta una extensión | Actívala en el `php.ini` que muestra `php --ini` |
| Falta `vendor/autoload.php` | Ejecuta `composer install` dentro de `backend` |
| Laravel indica que falta la clave | Copia `.env.example` a `.env` y ejecuta `php artisan key:generate` |
| No pudimos conectar con el servicio | Inicia Laravel en 8000 y revisa `LARAVEL_URL` |
| Se pierde la sesión o aparece un error CSRF | Usa siempre `127.0.0.1:3000`, permite cookies y vuelve a ingresar |
| Aparece el límite de intentos | Espera un minuto antes de intentar otra vez |
| El puerto está ocupado | Detén la otra instancia o cambia el puerto y su configuración correspondiente |
| Laravel no puede escribir | Revisa permisos de `storage` y `bootstrap/cache` |

## 12. Qué queda para después

Quedan pendientes las ventanas de vehículos, conductores, rutas y viajes, sus formularios, los demás módulos,
la conexión a PostgreSQL y el sistema de usuarios y permisos del producto completo.
La entrega actual no incluye esos desarrollos. Cuando se retomen, el frontend podrá conservar sus componentes
y Laravel podrá sustituir los datos fijos por consultas y reglas del negocio.

## 13. Fuentes y licencias

- Next.js: https://nextjs.org/docs/app/getting-started/installation
- Laravel: https://laravel.com/docs/13.x/installation
- Sesiones Laravel: https://laravel.com/docs/13.x/session
- Plantilla Laravel: https://github.com/laravel/laravel/tree/13.x
- Bootstrap: conserva su licencia en `frontend/LICENSE-bootstrap.txt`.

Las dependencias conservan sus propias licencias en los paquetes instalados.
Esta entrega no concede una licencia general de código abierto al proyecto FloatMate.
