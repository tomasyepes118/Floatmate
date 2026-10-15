# Cómo colaborar

1. Lea el README y la guía del componente que va a cambiar.
2. Cree una rama descriptiva desde `main`, por ejemplo `feature/registro-vehiculos` o `fix/validacion-placa`.
3. Haga cambios pequeños que puedan revisarse y actualice la documentación afectada.
4. Ejecute `node scripts/check-repository.mjs`. Si modifica C#, compile y ejecute la solución con .NET 8. Si modifica SQL, documente los scripts y resultados comprobados en una base de laboratorio.
5. Abra un pull request con el problema, la solución y las comprobaciones realmente ejecutadas.

Mantenga el español en las explicaciones y los nombres existentes en el código. Use mensajes de commit descriptivos, por ejemplo `docs: aclarar ejecución de la base de datos`.

Los documentos actuales van en su entrega correspondiente; las versiones reemplazadas van en `06_Material_adicional/Archivo/`. Conserve las fuentes DOT de los diagramas junto a los SVG. No suba dependencias descargadas, credenciales, compilaciones ni ZIP que dupliquen las fuentes.

No marque una entrega como terminada sin su documento o evidencia. Para publicar una versión, indique qué componentes fueron verificados y qué queda pendiente.
