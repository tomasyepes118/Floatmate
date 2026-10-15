/* NORTE > floatmate_norte. Ejecutar despues de 02.
   Esquema dedicado: dwh. Modelo estrella con cinco tablas de hechos.
   Las stg_* guardan la copia de las nueve entidades fuente.
   No borra ni modifica los esquemas operativos. */
BEGIN;
DO $$ BEGIN
 IF current_database() <> 'floatmate_norte' THEN
   RAISE EXCEPTION 'Ejecutar en NORTE > floatmate_norte';
 END IF;
END $$;
CREATE SCHEMA IF NOT EXISTS dwh;
COMMENT ON SCHEMA dwh IS 'Data Warehouse academico de FloatMate: staging, dimensiones, hechos y bitacora ETL.';
CREATE TABLE IF NOT EXISTS dwh.etl_ejecucion (
 ejecucion_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 iniciado_en timestamptz NOT NULL,
 finalizado_en timestamptz NOT NULL,
 conteos jsonb NOT NULL
);
CREATE TABLE IF NOT EXISTS dwh.dim_terminal (
 terminal_codigo varchar(3) PRIMARY KEY CHECK (terminal_codigo IN ('NOR','SUR')),
 nombre text NOT NULL
);
CREATE TABLE IF NOT EXISTS dwh.dim_fecha (
 fecha date PRIMARY KEY, anio integer NOT NULL, trimestre integer NOT NULL,
 mes integer NOT NULL, dia integer NOT NULL, dia_semana_iso integer NOT NULL
);
CREATE TABLE IF NOT EXISTS dwh.stg_usuarios AS SELECT * FROM floatmate_global.usuarios WITH NO DATA;
CREATE TABLE IF NOT EXISTS dwh.stg_vehiculos AS SELECT * FROM floatmate_global.vehiculos WITH NO DATA;
CREATE TABLE IF NOT EXISTS dwh.stg_conductores AS SELECT * FROM floatmate_global.conductores WITH NO DATA;
CREATE TABLE IF NOT EXISTS dwh.stg_rutas AS SELECT * FROM floatmate_global.rutas WITH NO DATA;
CREATE TABLE IF NOT EXISTS dwh.stg_viajes AS SELECT * FROM floatmate_global.viajes WITH NO DATA;
CREATE TABLE IF NOT EXISTS dwh.stg_controles_salida AS SELECT * FROM floatmate_global.controles_salida WITH NO DATA;
CREATE TABLE IF NOT EXISTS dwh.stg_abastecimientos AS SELECT * FROM floatmate_global.abastecimientos WITH NO DATA;
CREATE TABLE IF NOT EXISTS dwh.stg_mantenimientos AS SELECT * FROM floatmate_federacion.mantenimientos_federados WITH NO DATA;
CREATE TABLE IF NOT EXISTS dwh.stg_incidentes AS SELECT * FROM floatmate_global.incidentes WITH NO DATA;
CREATE TABLE IF NOT EXISTS dwh.dim_usuario (
 usuario_sk bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 terminal_codigo varchar(3) NOT NULL REFERENCES dwh.dim_terminal,
 usuario_id bigint NOT NULL,
 documento text NOT NULL,
 nombres text NOT NULL,
 apellidos text NOT NULL,
 rol text NOT NULL,
 activo boolean NOT NULL,
 UNIQUE (terminal_codigo, usuario_id)
);
CREATE TABLE IF NOT EXISTS dwh.dim_vehiculo (
 vehiculo_sk bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 terminal_codigo varchar(3) NOT NULL REFERENCES dwh.dim_terminal,
 vehiculo_id bigint NOT NULL,
 placa text NOT NULL,
 tipo text NOT NULL,
 marca text NOT NULL,
 modelo smallint NOT NULL,
 capacidad_pasajeros smallint NOT NULL,
 UNIQUE (terminal_codigo, vehiculo_id)
);
CREATE TABLE IF NOT EXISTS dwh.dim_conductor (
 conductor_sk bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 terminal_codigo varchar(3) NOT NULL REFERENCES dwh.dim_terminal,
 conductor_id bigint NOT NULL,
 documento text NOT NULL,
 nombres text NOT NULL,
 apellidos text NOT NULL,
 categoria_licencia text NOT NULL,
 UNIQUE (terminal_codigo, conductor_id)
);
CREATE TABLE IF NOT EXISTS dwh.dim_ruta (
 ruta_sk bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 terminal_codigo varchar(3) NOT NULL REFERENCES dwh.dim_terminal,
 ruta_id bigint NOT NULL,
 codigo text NOT NULL,
 nombre text NOT NULL,
 origen text NOT NULL,
 destino text NOT NULL,
 tipo text NOT NULL,
 distancia_km numeric(8,2) NOT NULL,
 UNIQUE (terminal_codigo, ruta_id)
);

CREATE TABLE IF NOT EXISTS dwh.fact_viaje (
 terminal_codigo varchar(3) NOT NULL REFERENCES dwh.dim_terminal,
 viaje_id bigint NOT NULL,
 fecha date NOT NULL REFERENCES dwh.dim_fecha,
 vehiculo_sk bigint NOT NULL REFERENCES dwh.dim_vehiculo,
 conductor_sk bigint NOT NULL REFERENCES dwh.dim_conductor,
 ruta_sk bigint NOT NULL REFERENCES dwh.dim_ruta,
 fecha_programada timestamptz NOT NULL,
 fecha_salida timestamptz, fecha_llegada timestamptz,
 estado text NOT NULL,
 pasajeros integer NOT NULL CHECK (pasajeros >= 0),
 capacidad integer NOT NULL CHECK (capacidad > 0 AND pasajeros <= capacidad),
 distancia_programada_km numeric(8,2) NOT NULL CHECK (distancia_programada_km > 0),
 duracion_real_minutos numeric CHECK (duracion_real_minutos >= 0),
 PRIMARY KEY (terminal_codigo,viaje_id)
);
CREATE TABLE IF NOT EXISTS dwh.fact_abastecimiento (
 terminal_codigo varchar(3) NOT NULL REFERENCES dwh.dim_terminal,
 abastecimiento_id bigint NOT NULL,
 fecha date NOT NULL REFERENCES dwh.dim_fecha,
 vehiculo_sk bigint NOT NULL REFERENCES dwh.dim_vehiculo,
 usuario_sk bigint NOT NULL REFERENCES dwh.dim_usuario,
 viaje_id bigint,
 litros numeric(8,2) NOT NULL CHECK (litros > 0),
 valor_litro numeric(10,2) NOT NULL CHECK (valor_litro > 0),
 costo_cop numeric(12,2) NOT NULL CHECK (costo_cop = round(litros * valor_litro,2)),
 kilometraje numeric(12,2) NOT NULL CHECK (kilometraje >= 0),
 PRIMARY KEY (terminal_codigo,abastecimiento_id)
);
CREATE TABLE IF NOT EXISTS dwh.fact_mantenimiento (
 fuente text NOT NULL CHECK (fuente IN ('POSTGRESQL','CSV_LOCAL')),
 terminal_codigo varchar(3) NOT NULL REFERENCES dwh.dim_terminal,
 registro_origen text NOT NULL,
 fecha date NOT NULL REFERENCES dwh.dim_fecha,
 vehiculo_sk bigint NOT NULL REFERENCES dwh.dim_vehiculo,
 usuario_sk bigint REFERENCES dwh.dim_usuario,
 tipo text NOT NULL CHECK (tipo IN ('PREVENTIVO','CORRECTIVO')),
 estado text NOT NULL CHECK (estado IN ('PROGRAMADO','EN_PROCESO','FINALIZADO')),
 proveedor text NOT NULL, fecha_salida date,
 kilometraje numeric(12,2) NOT NULL CHECK (kilometraje >= 0),
 costo_cop numeric(12,2) NOT NULL CHECK (costo_cop >= 0),
 PRIMARY KEY (fuente,terminal_codigo,registro_origen),
 CHECK (fecha_salida IS NULL OR fecha_salida >= fecha)
);
CREATE TABLE IF NOT EXISTS dwh.fact_control_salida (
 terminal_codigo varchar(3) NOT NULL REFERENCES dwh.dim_terminal,
 control_id bigint NOT NULL, viaje_id bigint NOT NULL,
 fecha date NOT NULL REFERENCES dwh.dim_fecha,
 vehiculo_sk bigint NOT NULL REFERENCES dwh.dim_vehiculo,
 usuario_sk bigint NOT NULL REFERENCES dwh.dim_usuario,
 resultado text NOT NULL,
 alcoholemia_mg_l numeric(5,3) NOT NULL CHECK (alcoholemia_mg_l >= 0),
 PRIMARY KEY (terminal_codigo,control_id)
);
CREATE TABLE IF NOT EXISTS dwh.fact_incidente (
 terminal_codigo varchar(3) NOT NULL REFERENCES dwh.dim_terminal,
 incidente_id bigint NOT NULL, viaje_id bigint NOT NULL,
 fecha date NOT NULL REFERENCES dwh.dim_fecha,
 vehiculo_sk bigint NOT NULL REFERENCES dwh.dim_vehiculo,
 usuario_sk bigint NOT NULL REFERENCES dwh.dim_usuario,
 tipo text NOT NULL, severidad text NOT NULL, estado text NOT NULL,
 tiene_evidencia boolean NOT NULL,
 PRIMARY KEY (terminal_codigo,incidente_id)
);
CREATE INDEX IF NOT EXISTS ix_dwh_viaje_fecha ON dwh.fact_viaje(fecha,terminal_codigo);
CREATE INDEX IF NOT EXISTS ix_dwh_abastecimiento_fecha ON dwh.fact_abastecimiento(fecha,terminal_codigo);
CREATE INDEX IF NOT EXISTS ix_dwh_mantenimiento_fecha ON dwh.fact_mantenimiento(fecha,terminal_codigo);
COMMIT;
