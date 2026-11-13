# Validación del cuarto avance

Verificado el 13 de noviembre de 2026.

| Comprobación | Resultado |
|---|---|
| Laravel y PHPUnit | 36 pruebas y 291 aserciones correctas |
| Next.js | Compilación de producción correcta |
| Chromium y Playwright | 53 comprobaciones correctas en escritorio y móvil |
| PostgreSQL 18 | Migración, importación única, datos iniciales, escritura y reversión de una transacción rechazable |
| Datos del pitch | Rechazo de inicio en V-9002, inicio de V-9001, llegada a 35.000 km y vuelta a disponible tras el servicio |

El recorrido de navegador incluye los registros de combustible, mantenimiento e incidentes, la descarga CSV y el resumen actualizado. Consulta el [detalle de comprobaciones](resultados-navegador.json) y las [capturas](capturas/).

PHPUnit y Playwright usaron datos de prueba independientes. La comprobación de PostgreSQL se ejecutó contra una instancia temporal local.
