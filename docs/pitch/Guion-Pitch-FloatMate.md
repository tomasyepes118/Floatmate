# Guion del pitch de FloatMate

**Tomás Yepes · Cristian Benites · Mateo Gallo**

Guion base de 10 minutos. La rúbrica compartida también menciona una versión de 15 minutos. Confirmen la duración del pitch y si las preguntas se cuentan aparte.

## Preparación del portátil

- Arranquen la copia aislada para el pitch. En la carpeta `backend`, generen una copia con `php artisan flota:preparar-demo`, asignen la ruta impresa a `DEMO_DATA_PATH` y arranquen Laravel en el puerto 8000 con `FLOTA_STORAGE=json`. Next.js debe estar abierto en el puerto 3000. Los comandos completos están en la [guía del cuarto avance](../../README.md).
- Inicien sesión y dejen **Viajes** abierto. Comprueben que V-9001 está Programado, que TPQ482 tiene 34.958 km y que el otro bus, KPT641, tiene 34.980 km. Ambos tienen su umbral a los 35.000 km en esta copia.
- Elijan de antemano una salida futura sin cruces para revisar la elegibilidad. Una opción para ensayar es una fecha tres días después del ensayo a las 10:00 a. m. con Daniel López y 20 pasajeros.
- Dejen listas las diapositivas 9 y 10 como respaldo. La diapositiva 6 muestra la fila real del bus después de la llegada. Tengan abierto este guion para retomar la narración en el mismo punto si el navegador se demora.
- Hagan dos ensayos cronometrados con una copia nueva en cada uno. Para el jurado, entren con datos ficticios y tickets de ensayo.

## 0:00–1:50 · Tomás · Problema e interesados

**Diapositiva 1.** «Una ruta de Medellín a Rionegro necesita 42 kilómetros. Un bus aparece disponible, pero le quedan 20 kilómetros antes de su próximo mantenimiento. Si ustedes estuvieran programando esa salida, ¿lo asignarían?» Hagan una pausa breve.

«Somos Tomás Yepes, Cristian Benites y Mateo Gallo. FloatMate ayuda al operador a comprobar si la asignación cumple antes de guardar el viaje».

**Diapositiva 2.** «El caso de estudio contempla ocho buses. La factibilidad describe que la información del vehículo, el viaje y los controles se consulta en registros separados. El operador tiene que reunir esos datos antes de despachar. Al conductor le importa saber qué tiene asignado y a Don Alex le interesa consultar cómo quedó la flota».

Si tienen una entrevista u observación documentada, cuenten con quién se hizo, cuándo y qué regla confirmó o corrigió. Con el material disponible, el proceso aún requiere validación con Don Alex y el operador. Los ocho buses delimitan el caso de estudio. Para cuantificar el problema, el equipo todavía debe medir el tiempo del proceso actual.

**Pase a Cristian.** «Para resolverlo, convertimos las decisiones del operador en reglas que se pueden probar».

## 1:50–4:00 · Cristian · Requerimientos y arquitectura

**Diapositiva 3.** «Como operador, necesito comprobar si el vehículo y el conductor cumplen las condiciones para asignarlos a un viaje. Lo verificamos con criterios concretos. Si la asignación excede el kilometraje permitido, el sistema rechaza la programación. Si el control se rechaza, el viaje queda Programado. Si la llegada alcanza el umbral, el vehículo pasa a Mantenimiento».

«Clasificamos como imprescindibles la asignación, el control y el cierre. Los registros complementan la operación y las integraciones externas quedan para una etapa posterior. El requisito de usabilidad RNF-USA-01 propone cinco casos con un máximo de dos minutos por caso. Mediríamos desde que el operador recibe la tarea hasta que la completa y registraríamos errores. Esa medición sigue pendiente».

**Diapositiva 4.** «Next.js y React muestran las pantallas. Laravel recibe la solicitud y decide si puede ejecutarse. Revisar y guardar aplican las mismas reglas. Al confirmar, Laravel vuelve a comprobar la disponibilidad porque la flota puede haber cambiado mientras el operador tenía abierto el formulario».

«En la demo, el servidor guarda un archivo JSON con bloqueo de escritura. También probamos un modo PostgreSQL que guarda un documento JSONB con una transacción y bloqueo de fila. Así los cambios del viaje, el bus y el conductor se guardan juntos. Laravel comprueba sesión y roles antes de aceptar una acción».

**Pase a Mateo.** «Veamos esas reglas en la aplicación con los dos buses».

## 4:00–7:50 · Mateo · Demostración

| Tiempo | Acción | Qué explicar |
|---|---|---|
| 4:00–4:45 | **Viajes → Programar viaje**. Elige Medellín–Rionegro, KPT641, Daniel López, salida futura y 20 pasajeros. Pulsa **Revisar elegibilidad**. | «El bus figura disponible. Para esta ruta le faltan 22 km de margen, porque le quedan 20 y el recorrido requiere 42. La proyección llega a 35.022 km». **CU07 y CU08.** |
| 4:45–5:20 | Pulsa **Usar TPQ482** y vuelve a revisar. Señala la llegada estimada de 35.000 km. Cierra el formulario sin guardar y busca el viaje preparado V-9001. | «El segundo bus llega justo al umbral y puede completar el trayecto. Para mostrar el despacho, abro V-9001, que ya tiene asignados esa ruta y ese bus». La revisión usó a Daniel López. V-9001 tiene a Carlos Restrepo. |
| 5:20–6:20 | En **V-9001 → Registrar control** escribe un ticket único, por ejemplo `PITCH-B01`, y una medición ficticia de `0` mg/L. Guarda, pulsa **Iniciar viaje** y confirma. | «El ticket queda asociado y el control aprobado habilita la acción. Al iniciar, el bus y el conductor quedan ocupados». **CU09, CU10 y CU11.** |
| 6:20–7:15 | Pulsa **Finalizar viaje**, ingresa `35000` y confirma. Ve a **Vehículos**, busca **TPQ482** y señala **Mantenimiento**. | «La llegada actualiza el odómetro, libera al conductor y cambia el estado del bus al alcanzar el umbral». **CU12.** |
| 7:15–7:50 | Vuelve a la diapositiva 6. | «La revisión anticipó el kilometraje y el registro real de llegada cambió la disponibilidad para el siguiente viaje». |

Si un paso falla, pasen a la captura correspondiente y sigan el relato. Usen la diapositiva 9 para la elegibilidad, la 10 para el control aprobado y la 6 para la llegada. Si el jurado pide ver el rechazo de salida, V-9002 permite registrar un ticket diferente con `0.015` mg/L simulados. El viaje queda Programado y el servidor rechaza el inicio.

## 7:50–10:00 · Cristian y Tomás · Calidad y cierre

**Diapositiva 7, Cristian.** «Avanzamos por entregas incrementales. Primero hicimos acceso y resumen. Después sumamos inventario y programación, luego control y cierre, y finalmente los catálogos, registros, roles y la revisión de elegibilidad».

«Probamos el riesgo de permitir una asignación que ya no cumple. Laravel repite la validación al guardar e iniciar. Ejecutamos 36 pruebas de Laravel con 291 aserciones y 53 comprobaciones en Chromium. Dos casos concretos verificaron el bloqueo del control rechazado y la actualización del bus al alcanzar el límite».

**Diapositiva 8, Tomás.** «El siguiente paso es recorrer cinco casos con Don Alex y el operador. Queremos confirmar las reglas para un bus sin kilometraje suficiente, un cruce de horario, un control rechazado, una salida aprobada y una llegada a mantenimiento. También mediremos cuánto tarda cada caso».

## Si confirman 15 minutos

| Tiempo adicional | Dónde agregarlo |
|---|---|
| **2 min · Programación completa** | Después de la revisión, programa un viaje nuevo, muestra la fila guardada y demuestra un cruce de horario. Continúa con ese viaje para el control y la llegada. |
| **2 min · Registros y módulos** | Después de la llegada, registra mantenimiento a 35.000 km con el próximo servicio a 40.000 km. Comprueba que el bus vuelve a Disponible. Apóyate en la diapositiva 11 para mostrar dónde están combustible, incidentes y CSV. |
| **1 min · Evidencia y validación** | En la diapositiva 2, muestra una evidencia documentada si la tienen. Si sigue pendiente, explica cómo observarían el despacho y cómo registrarían la línea base de tiempos. |

## Preguntas que deben poder contestar los tres

| Pregunta | Respuesta |
|---|---|
| ¿Cómo validaron con usuarios reales? | La factibilidad documenta el proceso propuesto y las pruebas verifican las reglas implementadas. La confirmación del flujo con Don Alex y el operador sigue pendiente según los materiales revisados. Si ya cuentan con evidencia nueva, identifiquen la técnica, la fecha y la decisión resultante. |
| ¿Cómo se mide un requisito no funcional? | RNF-USA-01 propone que el operador resuelva cada uno de cinco casos en dos minutos como máximo. Medimos cada caso con cronómetro y anotamos errores. |
| ¿Qué conservarían si recortan el alcance? | Programación, elegibilidad, control, salida y llegada. Ese recorrido resuelve la decisión principal del operador y conserva el estado del vehículo para el siguiente viaje. |
| ¿Qué riesgo técnico mitigaron? | Una revisión válida puede quedar desactualizada. La API vuelve a validar al guardar y al iniciar. Las escrituras se protegen con bloqueo y, en PostgreSQL, con una transacción. |
| ¿Qué cambió entre avances? | El alcance funcional de la validación pasó de informar el resultado al guardar a ofrecer una revisión previa con explicación y alternativas. La validación final se conserva. Preséntenlo como una evolución implementada. Si tienen un cambio aprobado por un usuario, lleven su evidencia. |
| ¿Ya usan PostgreSQL? | Hay un modo opcional probado con PostgreSQL y una tabla JSONB. La demo corre en modo JSON local. Norte/Sur y DWH son prácticas académicas independientes. |
| ¿Qué queda para un piloto? | Validar las reglas y tiempos con el operador, revisar cómo se gestionarán los datos reales y acordar el alcance de funciones pendientes como los adjuntos de incidentes. |
