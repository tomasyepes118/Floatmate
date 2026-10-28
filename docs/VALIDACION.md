# Comprobación de la entrega

Fecha: 27 de octubre de 2026. Entorno de comprobación: Windows, Node.js 24.22.1, PHP 8.4.27.

## Resultado

- Compilación de producción de Next.js: correcta.
- PHPUnit: **8 pruebas y 30 comprobaciones correctas**.
- Recorrido real en navegador Edge con Playwright: **15 comprobaciones correctas**.
- Revisión visual de login y resumen en PC y móvil: realizada.

## Comprobaciones del navegador

1. Abrir el resumen sin sesión devuelve al acceso.
2. Ver muestra la contraseña.
3. Ocultar vuelve a protegerla.
4. Credenciales incorrectas muestran un mensaje en español.
5. El acceso correcto llega al resumen a través de Laravel.
6. Los indicadores muestran 5, 3, 2 y 1, como la referencia.
7. La tabla contiene los dos viajes de demostración.
8. Vehículos y Viajes están deshabilitados.
9. Recargar conserva la sesión.
10. Un POST sin token CSRF es rechazado por el servidor real.
11. La cookie de sesión tiene HttpOnly.
12. Salir invalida el acceso al resumen.
13. El login móvil no desborda horizontalmente.
14. El resumen móvil no desborda horizontalmente.
15. El recorrido no produce errores JavaScript.

## Evidencia

- `capturas/01-login-pc.png`
- `capturas/02-resumen-pc.png`
- `capturas/03-login-movil.png`
- `capturas/04-resumen-movil.png`

Las capturas de PC usan escala de 125 % para facilitar la comparación con las imágenes del PDF.
El recorrido en móvil usa 390 píxeles de ancho. Las capturas incluyen toda la página.

## Alcance de las pruebas

Esta revisión corresponde al login y la vista principal con datos de ejemplo. No prueba módulos posteriores,
integración con bases de datos, publicación en internet, carga masiva ni un sistema multiusuario completo.
Las pruebas del servidor no crean tablas ni requieren una base de datos.

Para repetir el recorrido con Edge instalado en Windows, desde `frontend`, con las aplicaciones iniciadas:

```powershell
$env:PLAYWRIGHT_CHANNEL = 'msedge'
npm run test:e2e
```

También se puede instalar Chromium siguiendo `DOCUMENTACION.md`, sin establecer esa variable.
