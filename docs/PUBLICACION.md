# Demo navegable en GitHub Pages

URL prevista: https://tomasyepes118.github.io/Floatmate/

Acceso de demostración: usuario `admin`, contraseña `floatmate123`.

La profesora podrá abrir el enlace desde el navegador, ingresar y recorrer el panel, los vehículos y los viajes sin descargar el repositorio. Los datos se guardan en el navegador de cada persona. No hay una API ni conexión a PostgreSQL en esta demo.

## Activación inicial

1. Abrir Settings → Pages en el repositorio.
2. En Build and deployment → Source, seleccionar GitHub Actions.
3. Abrir Actions → Publicar demo de FloatMate.
4. Si la primera ejecución falló antes de activar Pages, elegir Re-run all jobs. También se puede iniciar desde Run workflow, con la rama main.
5. Esperar a que build y deploy terminen correctamente y abrir la URL que muestra el despliegue.

## Actualizaciones

El workflow `.github/workflows/pages.yml` publica automáticamente los cambios de la carpeta de la web en main. Copia las cuatro pantallas HTML y assets al sitio. Los informes, las capturas y los scripts SQL no forman parte del sitio desplegado.

## Verificación

Abrir el enlace en una ventana privada, ingresar con los datos de demostración, recorrer panel, vehículos y viajes, y comprobar la vista móvil. Una prueba con registros nuevos afecta únicamente el almacenamiento de ese navegador.

## Mensaje para compartir

Profe, esta es la demo navegable de FloatMate: https://tomasyepes118.github.io/Floatmate/
Usuario: admin. Contraseña: floatmate123.
Puede consultar el panel, registrar vehículos y programar viajes. Es un prototipo con datos de demostración que se guardan en el navegador.
