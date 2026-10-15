/* FLOATMATE - BDOO / modelo objeto-relacional.
   Ejecutar completo en floatmate_norte, despues de 00.
   Instalacion inicial: este archivo se ejecuta UNA VEZ.
   No modifica floatmate, floatmate_remoto, floatmate_global ni floatmate_programacion. */
BEGIN;
DO $$
BEGIN
  IF to_regclass('floatmate.vehiculos') IS NULL THEN
    RAISE EXCEPTION 'Esta base no tiene floatmate.vehiculos. Abra la base correcta.';
  END IF;
  IF to_regnamespace('floatmate_objetos') IS NOT NULL THEN
    RAISE EXCEPTION 'floatmate_objetos ya existe. No se borra nada. Si ya instalo 01, siga con 02.';
  END IF;
END $$;
CREATE SCHEMA floatmate_objetos;
COMMENT ON SCHEMA floatmate_objetos IS 'Actividad BDOO: clases, objetos persistentes, UUID, composicion, herencia y metodos.';

CREATE TYPE floatmate_objetos.clase_vehiculo AS ENUM ('BUS_URBANO','BUS_INTERMUNICIPAL','MICROBUS');
CREATE TYPE floatmate_objetos.estado_vehiculo AS ENUM ('DISPONIBLE','EN_RUTA','MANTENIMIENTO','FUERA_SERVICIO');
CREATE TYPE floatmate_objetos.estado_viaje AS ENUM ('PROGRAMADO','EN_CURSO','FINALIZADO','CANCELADO');
CREATE TYPE floatmate_objetos.t_contacto AS (telefono text, correo text);
CREATE TYPE floatmate_objetos.t_licencia AS (numero text, categoria text, vence date);
CREATE TYPE floatmate_objetos.t_ficha AS (
  marca text, modelo smallint, capacidad smallint,
  kilometraje numeric(12,2), proximo_mantenimiento_km numeric(12,2)
);
/* Los CREATE TYPE compuestos no aceptan CHECK internos.
   El dominio valida incluso los valores compuestos usados fuera de una tabla. */
CREATE DOMAIN floatmate_objetos.d_contacto AS floatmate_objetos.t_contacto
  CHECK ((VALUE).telefono IS NOT NULL AND length(trim((VALUE).telefono)) >= 7
    AND ((VALUE).correo IS NULL OR position('@' IN (VALUE).correo) > 1));
CREATE DOMAIN floatmate_objetos.d_licencia AS floatmate_objetos.t_licencia
  CHECK ((VALUE).numero IS NOT NULL AND length(trim((VALUE).numero)) > 0
    AND (VALUE).categoria IS NOT NULL AND (VALUE).categoria IN ('C1','C2','C3')
    AND (VALUE).vence IS NOT NULL);
CREATE DOMAIN floatmate_objetos.d_ficha AS floatmate_objetos.t_ficha
  CHECK ((VALUE).marca IS NOT NULL AND length(trim((VALUE).marca)) > 0
    AND (VALUE).modelo IS NOT NULL AND (VALUE).modelo BETWEEN 2000 AND 2035
    AND (VALUE).capacidad IS NOT NULL AND (VALUE).capacidad BETWEEN 10 AND 80
    AND (VALUE).kilometraje IS NOT NULL AND (VALUE).kilometraje >= 0
    AND (VALUE).proximo_mantenimiento_km IS NOT NULL AND (VALUE).proximo_mantenimiento_km >= 0);

/* Registro central: la unicidad del padre INHERITS no cubre sus hijos.
   Cada objeto vehiculo se identifica aqui; los hijos hacen referencia a este registro. */
CREATE TABLE floatmate_objetos.identidad_vehiculo (
  oid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  terminal_codigo varchar(3) NOT NULL CHECK (terminal_codigo IN ('NOR','SUR')),
  id_relacional bigint,
  clase floatmate_objetos.clase_vehiculo NOT NULL,
  placa varchar(6) NOT NULL UNIQUE CHECK (placa ~ '^[A-Z]{3}[0-9]{3}$'),
  creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (terminal_codigo, id_relacional),
  UNIQUE (oid, terminal_codigo),
  UNIQUE (oid, clase, terminal_codigo, placa)
);
COMMENT ON COLUMN floatmate_objetos.identidad_vehiculo.oid IS
  'OID del modelo de objetos: UUID estable e inmutable. No es el tipo oid del catalogo PostgreSQL.';

CREATE TABLE floatmate_objetos.vehiculo (
  oid uuid NOT NULL,
  terminal_codigo varchar(3) NOT NULL CHECK (terminal_codigo IN ('NOR','SUR')),
  clase floatmate_objetos.clase_vehiculo NOT NULL,
  placa varchar(6) NOT NULL CHECK (placa ~ '^[A-Z]{3}[0-9]{3}$'),
  ficha floatmate_objetos.d_ficha NOT NULL,
  estado floatmate_objetos.estado_vehiculo NOT NULL DEFAULT 'DISPONIBLE',
  equipamiento text[] NOT NULL DEFAULT ARRAY['BOTIQUIN','EXTINTOR']::text[],
  CHECK (cardinality(equipamiento) > 0 AND array_position(equipamiento, NULL) IS NULL)
);
COMMENT ON TABLE floatmate_objetos.vehiculo IS
  'Superclase conceptual abstracta. SELECT incluye objetos de los tres hijos; ONLY consulta solo el padre.';

CREATE TABLE floatmate_objetos.bus_urbano (
  clase floatmate_objetos.clase_vehiculo DEFAULT 'BUS_URBANO',
  puertas smallint NOT NULL DEFAULT 2 CHECK (puertas BETWEEN 1 AND 4),
  accesible boolean NOT NULL DEFAULT true,
  PRIMARY KEY (oid), UNIQUE (placa),
  CHECK (clase = 'BUS_URBANO'),
  FOREIGN KEY (oid, clase, terminal_codigo, placa) REFERENCES floatmate_objetos.identidad_vehiculo(oid, clase, terminal_codigo, placa)
    DEFERRABLE INITIALLY DEFERRED
) INHERITS (floatmate_objetos.vehiculo);
CREATE TABLE floatmate_objetos.bus_intermunicipal (
  clase floatmate_objetos.clase_vehiculo DEFAULT 'BUS_INTERMUNICIPAL',
  aire_acondicionado boolean NOT NULL DEFAULT true,
  bodega_m3 numeric(5,2) NOT NULL DEFAULT 8 CHECK (bodega_m3 >= 0),
  PRIMARY KEY (oid), UNIQUE (placa),
  CHECK (clase = 'BUS_INTERMUNICIPAL'),
  FOREIGN KEY (oid, clase, terminal_codigo, placa) REFERENCES floatmate_objetos.identidad_vehiculo(oid, clase, terminal_codigo, placa)
    DEFERRABLE INITIALLY DEFERRED
) INHERITS (floatmate_objetos.vehiculo);
CREATE TABLE floatmate_objetos.microbus (
  clase floatmate_objetos.clase_vehiculo DEFAULT 'MICROBUS',
  servicio_especial boolean NOT NULL DEFAULT false,
  PRIMARY KEY (oid), UNIQUE (placa),
  CHECK (clase = 'MICROBUS'),
  FOREIGN KEY (oid, clase, terminal_codigo, placa) REFERENCES floatmate_objetos.identidad_vehiculo(oid, clase, terminal_codigo, placa)
    DEFERRABLE INITIALLY DEFERRED
) INHERITS (floatmate_objetos.vehiculo);

CREATE TABLE floatmate_objetos.conductor (
  oid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  terminal_codigo varchar(3) NOT NULL CHECK (terminal_codigo IN ('NOR','SUR')),
  id_relacional bigint,
  documento text NOT NULL UNIQUE,
  nombre text NOT NULL CHECK (length(trim(nombre)) > 0),
  contacto floatmate_objetos.d_contacto NOT NULL,
  licencia floatmate_objetos.d_licencia NOT NULL,
  estado text NOT NULL CHECK (estado IN ('DISPONIBLE','EN_VIAJE','INACTIVO')),
  UNIQUE (terminal_codigo, id_relacional),
  UNIQUE (oid, terminal_codigo)
);
CREATE TABLE floatmate_objetos.ruta (
  oid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  terminal_codigo varchar(3) NOT NULL CHECK (terminal_codigo IN ('NOR','SUR')),
  id_relacional bigint,
  nombre text NOT NULL,
  origen text NOT NULL, destino text NOT NULL CHECK (destino <> origen),
  distancia_km numeric(8,2) NOT NULL CHECK (distancia_km > 0),
  paradas text[] NOT NULL CHECK (cardinality(paradas) >= 2 AND array_position(paradas, NULL) IS NULL),
  activa boolean NOT NULL DEFAULT true,
  UNIQUE (terminal_codigo, id_relacional),
  UNIQUE (oid, terminal_codigo)
);
CREATE TABLE floatmate_objetos.viaje (
  oid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  terminal_codigo varchar(3) NOT NULL CHECK (terminal_codigo IN ('NOR','SUR')),
  id_relacional bigint,
  vehiculo_oid uuid NOT NULL,
  conductor_oid uuid NOT NULL,
  ruta_oid uuid NOT NULL,
  fecha_programada timestamptz NOT NULL,
  fecha_salida timestamptz, fecha_llegada timestamptz,
  pasajeros smallint NOT NULL CHECK (pasajeros >= 0),
  estado floatmate_objetos.estado_viaje NOT NULL DEFAULT 'PROGRAMADO',
  expediente jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(expediente) = 'object'),
  UNIQUE (terminal_codigo, id_relacional),
  FOREIGN KEY (vehiculo_oid, terminal_codigo) REFERENCES floatmate_objetos.identidad_vehiculo(oid,terminal_codigo),
  FOREIGN KEY (conductor_oid, terminal_codigo) REFERENCES floatmate_objetos.conductor(oid,terminal_codigo),
  FOREIGN KEY (ruta_oid, terminal_codigo) REFERENCES floatmate_objetos.ruta(oid,terminal_codigo),
  CHECK (fecha_llegada IS NULL OR (fecha_salida IS NOT NULL AND fecha_llegada >= fecha_salida))
);
CREATE UNIQUE INDEX ux_obj_viaje_vehiculo_hora ON floatmate_objetos.viaje(vehiculo_oid,fecha_programada)
  WHERE estado <> 'CANCELADO';
CREATE UNIQUE INDEX ux_obj_viaje_conductor_hora ON floatmate_objetos.viaje(conductor_oid,fecha_programada)
  WHERE estado <> 'CANCELADO';
CREATE TABLE floatmate_objetos.mantenimiento (
  oid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  terminal_codigo varchar(3) NOT NULL CHECK (terminal_codigo IN ('NOR','SUR')),
  id_relacional bigint,
  vehiculo_oid uuid NOT NULL,
  tipo text NOT NULL CHECK (tipo IN ('PREVENTIVO','CORRECTIVO')),
  fecha_ingreso date NOT NULL,
  costo numeric(12,2) NOT NULL CHECK (costo >= 0),
  detalle jsonb NOT NULL CHECK (jsonb_typeof(detalle) = 'object'),
  UNIQUE (terminal_codigo, id_relacional),
  FOREIGN KEY (vehiculo_oid, terminal_codigo) REFERENCES floatmate_objetos.identidad_vehiculo(oid,terminal_codigo)
);
CREATE TABLE floatmate_objetos.auditoria (
  evento_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fecha timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  usuario text NOT NULL DEFAULT CURRENT_USER,
  tabla text NOT NULL,
  operacion text NOT NULL CHECK (operacion IN ('INSERT','UPDATE','DELETE')),
  objeto_oid uuid NOT NULL,
  anterior jsonb, nuevo jsonb
);
CREATE TABLE floatmate_objetos.instalacion (
  modulo text PRIMARY KEY,
  version text NOT NULL,
  datos_importados_en timestamptz
);
INSERT INTO floatmate_objetos.instalacion VALUES ('BDOO','1.0',NULL);
COMMIT;
SELECT 'Modelo creado. Siga con 02_metodos_y_reglas.sql.' AS siguiente_paso;
