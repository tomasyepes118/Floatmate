/*
  EJECUTAR UNA SOLA VEZ, conectado como postgres a la base postgres.
  Antes debe ejecutar: 00_preparar_rol_admin.sql

  IMPORTANTE: este archivo contiene deliberadamente una sola sentencia.
  CREATE DATABASE no puede ejecutarse dentro de un bloque de transaccion.
*/
CREATE DATABASE floatmate_norte
    WITH OWNER = floatmate_admin
         ENCODING = 'UTF8'
         TEMPLATE = template0;
