/* NORTE > floatmate_norte. Repetible: no duplica hechos.
   Detener edicion del CSV durante la carga; archivo externo no tiene MVCC.
   En pgAdmin: Auto-commit activo, ejecutar todo, sin seleccionar un fragmento.
   Si hay error: ejecutar ROLLBACK; corregir y repetir este archivo.
*/
BEGIN ISOLATION LEVEL REPEATABLE READ;
CALL dwh.sp_cargar();
COMMIT;
SELECT * FROM dwh.etl_ejecucion ORDER BY ejecucion_id DESC LIMIT 1;
