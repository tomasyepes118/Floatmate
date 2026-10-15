/*
  EJECUTAR UNA SOLA VEZ, conectado como postgres a la base postgres.
  Este archivo se ejecuta ANTES de crear floatmate_norte y floatmate_sur.
*/

DO $crear_rol$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'floatmate_admin') THEN
        CREATE ROLE floatmate_admin LOGIN PASSWORD 'FloatMate_Admin_2026!';
    END IF;
END
$crear_rol$;

ALTER ROLE floatmate_admin WITH LOGIN PASSWORD 'FloatMate_Admin_2026!';
