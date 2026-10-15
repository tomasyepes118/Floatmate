/* Demostracion manual. NORTE > floatmate_norte.
   Ejecutar cada SECCION por separado, en este orden.
   Requiere el CSV de ejemplo y una carga inicial exitosa.
*/

-- SECCION 1. Con CSV original, ambos resultados deben ser 180000.00.
SELECT 'FEDERACION_EN_VIVO' AS consulta,costo AS costo_cop
FROM floatmate_federacion.mantenimientos_federados
WHERE fuente='CSV_LOCAL' AND terminal_codigo='NOR' AND registro_origen='EXT-NOR-001'
UNION ALL
SELECT 'DWH_ULTIMA_CARGA',costo_cop FROM dwh.fact_mantenimiento
WHERE fuente='CSV_LOCAL' AND terminal_codigo='NOR' AND registro_origen='EXT-NOR-001';

-- SECCION 2 (EN EL EQUIPO WINDOWS DE NORTE, NO ES SQL).
-- Abrir una copia de respaldo del CSV y conservarla fuera de la ruta enlazada.
-- En el archivo enlazado, cambiar costo de EXT-NOR-001: 180000.00 -> 190000.00.
-- Guardar como CSV UTF-8, con coma y punto decimal; cerrar Excel/editor.
-- Repetir SELECT de SECCION 1: federacion=190000, DWH=180000.

-- SECCION 3. Actualizar el DWH. Ahora ambos deben mostrar 190000.00.
BEGIN ISOLATION LEVEL REPEATABLE READ;
CALL dwh.sp_cargar();
COMMIT;
SELECT fuente,registro_origen,costo_cop FROM dwh.fact_mantenimiento
WHERE fuente='CSV_LOCAL' AND terminal_codigo='NOR' AND registro_origen='EXT-NOR-001';

-- SECCION 4 (EN NORTE). Restaurar el CSV original de la copia de respaldo.
-- Luego volver a ejecutar SECCION 3: el DWH regresara a 180000.00.
-- La prueba demuestra enlace en vivo frente a copia fisica actualizada por ETL.
