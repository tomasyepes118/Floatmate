/*
  Ejecutar en el servidor NORTE, conectado a la base postgres como postgres.
  Debe ejecutarse solo. No lo combine con otras sentencias.
*/
CREATE DATABASE floatmate_norte
    WITH OWNER = postgres
         ENCODING = 'UTF8'
         TEMPLATE = template0;
