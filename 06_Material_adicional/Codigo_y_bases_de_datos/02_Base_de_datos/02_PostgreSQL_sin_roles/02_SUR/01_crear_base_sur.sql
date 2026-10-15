/*
  Ejecutar en el servidor SUR, conectado a la base postgres como postgres.
  Debe ejecutarse solo. No lo combine con otras sentencias.
*/
CREATE DATABASE floatmate_sur
    WITH OWNER = postgres
         ENCODING = 'UTF8'
         TEMPLATE = template0;
