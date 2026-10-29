# Comprobaciones del segundo avance

Fecha: 29 de octubre de 2026.

## Resultados

- Laravel: **26 pruebas y 123 comprobaciones correctas**.
- Next.js: **compilación de producción correcta**.
- Navegador Chromium: **31 comprobaciones correctas**.
- GitHub Actions: los tres trabajos de compilación, servidor y navegador finalizaron correctamente.

## Recorrido comprobado

1. resumen exige una sesión.
2. vehiculos exige una sesión.
3. viajes exige una sesión.
4. El login rechaza una contraseña incorrecta.
5. Login y resumen funcionan.
6. La consulta muestra los vehículos guardados.
7. El filtro de estado de vehículos funciona.
8. La búsqueda vacía tiene un mensaje claro.
9. Cerrar el formulario no crea registros.
10. La placa repetida se rechaza desde Laravel.
11. Corregir la placa retira el error anterior.
12. Se registra el vehículo y aparece en la tabla.
13. El registro se conserva al recargar.
14. El resumen refleja el vehículo nuevo.
15. La consulta muestra los viajes guardados.
16. El filtro de estado de viajes funciona.
17. La búsqueda sin viajes muestra un mensaje.
18. El formulario solo ofrece buses disponibles.
19. La fecha pasada se rechaza con un mensaje.
20. El servidor rechaza el exceso de capacidad.
21. El viaje creado aparece en la programación.
22. El servidor rechaza cruces del vehículo.
23. Las altas exigen protección CSRF.
24. El panel refleja el viaje nuevo.
25. Salir protege nuevamente la programación.
26. El archivo conserva los registros después de salir.
27. Vehículos se adapta al ancho móvil.
28. El formulario de vehículo cabe en móvil.
29. Viajes se adapta al ancho móvil.
30. El formulario de viaje cabe en móvil.
31. El recorrido no genera errores JavaScript.

## Capturas

Las diez capturas del segundo avance están en `capturas/`. Incluyen consultas, formularios, un error de placa repetida, el resumen actualizado y las vistas móviles. Los formularios largos permiten desplazarse dentro de la ventana.

## Alcance de las pruebas

Las pruebas de Laravel usan carpetas temporales independientes. El navegador se ejecutó en GitHub Actions con `DEMO_E2E=true` y un archivo JSON separado. No se usaron ni modificaron registros de operación del equipo.

Las comprobaciones cubren el acceso y los módulos de vehículos y viajes de esta etapa. No equivalen a pruebas de carga, operación empresarial, integración con PostgreSQL ni módulos todavía pendientes.

## Ejecución de referencia

https://github.com/tomasyepes118/Floatmate/actions/runs/40941457710
