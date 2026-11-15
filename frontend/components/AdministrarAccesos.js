'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { enviarAccion } from '../lib/api';
import { numero } from '../lib/presentacion';
import Campo from './Campo';
import Dialogo from './Dialogo';
import { BotonOperacion, EstadoOperacion, PanelOperacion, TablaOperacion, TituloPagina, VacioOperacion } from './InterfazOperacion';

export default function AdministrarAccesos({ accesos, conductores }) {
  const router = useRouter();
  const [formulario, setFormulario] = useState(null);
  const [rol, setRol] = useState('Operador');
  const [ocupado, setOcupado] = useState(false);
  const [actualizando, actualizar] = useTransition();
  const [mensaje, setMensaje] = useState('');
  const [error, setError] = useState('');
  const [errores, setErrores] = useState({});
  const cambiandoClave = !!formulario?.usuario;
  const bloqueado = ocupado || actualizando;
  const sinCuenta = conductores.filter(conductor => !accesos.some(cuenta => cuenta.conductor_id === conductor.id));

  function abrir(cuenta = {}) {
    setFormulario(cuenta);
    setRol('Operador');
    setError('');
    setErrores({});
    setMensaje('');
  }

  async function guardar(datos, cuenta) {
    if (bloqueado) return;
    setOcupado(true);
    setError('');
    setErrores({});
    setMensaje('');
    try {
      const respuesta = await enviarAccion(cuenta ? `accesos/${encodeURIComponent(cuenta)}` : 'accesos', datos, cuenta ? 'PATCH' : 'POST');
      setFormulario(null);
      setMensaje(respuesta.message);
      actualizar(() => router.refresh());
    } catch (fallo) {
      setError(fallo.message);
      setErrores(fallo.errores || {});
    } finally {
      setOcupado(false);
    }
  }

  return <>
    <TituloPagina titulo="Accesos" descripcion="Crea cuentas para el personal de despacho y los conductores de la flota." />
    {mensaje && <p className="operation-success" role="status">{mensaje}</p>}
    {!formulario && error && <p className="form-error" role="alert">{error}</p>}
    <div className="toolbar"><BotonOperacion principal icono="agregar" onClick={() => abrir()} disabled={bloqueado}>Crear cuenta</BotonOperacion></div>
    <PanelOperacion id="cuentas-operativas" titulo="Cuentas operativas" contador={`${numero(accesos.length)} ${accesos.length === 1 ? 'cuenta' : 'cuentas'}`}>
      {accesos.length ? <TablaOperacion etiqueta="cuentas-operativas" columnas={['Usuario', 'Nombre', 'Rol', 'Estado', 'Acciones']}>
        {accesos.map(cuenta => <tr key={cuenta.usuario}>
          <td data-label="Usuario"><strong>{cuenta.usuario}</strong></td>
          <td data-label="Nombre">{cuenta.nombre}</td>
          <td data-label="Rol">{cuenta.rol}</td>
          <td data-label="Estado"><EstadoOperacion estado={cuenta.activo ? 'ACTIVA' : 'INACTIVA'}>{cuenta.activo ? 'Activa' : 'Inactiva'}</EstadoOperacion></td>
          <td data-label="Acciones"><div className="row-actions">
            <BotonOperacion compacto onClick={() => abrir(cuenta)} disabled={bloqueado}>Cambiar contraseña</BotonOperacion>
            <BotonOperacion compacto onClick={() => guardar({ activo:!cuenta.activo }, cuenta.usuario)} disabled={bloqueado}>{cuenta.activo ? 'Desactivar' : 'Reactivar'}</BotonOperacion>
          </div></td>
        </tr>)}
      </TablaOperacion> : <VacioOperacion icono="accesos">Sin cuentas operativas registradas</VacioOperacion>}
    </PanelOperacion>

    <Dialogo abierto={!!formulario} titulo={cambiandoClave ? 'Cambiar contraseña' : 'Crear cuenta'} cerrar={() => setFormulario(null)} ocupado={ocupado}>
      {formulario && <form onSubmit={evento => {
        evento.preventDefault();
        void guardar(Object.fromEntries(new FormData(evento.currentTarget)), formulario.usuario);
      }} aria-busy={ocupado}>
        <fieldset disabled={ocupado}>
          {cambiandoClave ? <p className="route-detail">Usuario {formulario.usuario}</p> : <>
            <div className="operation-grid">
              <Campo nombre="usuario" etiqueta="Usuario" errores={errores}>
                <input id="usuario" name="usuario" className="form-control" autoComplete="off" required minLength={3} maxLength={60} />
              </Campo>
              <Campo nombre="rol" etiqueta="Rol" errores={errores}>
                <select id="rol" name="rol" className="form-select" value={rol} onChange={e => setRol(e.target.value)}>
                  <option>Operador</option><option>Conductor</option>
                </select>
              </Campo>
            </div>
            {rol === 'Operador' ? <Campo nombre="nombre" etiqueta="Nombre completo" errores={errores}>
              <input id="nombre" name="nombre" className="form-control" required maxLength={80} />
            </Campo> : <Campo nombre="conductor_id" etiqueta="Conductor del catálogo" errores={errores}>
              <select id="conductor_id" name="conductor_id" className="form-select" required defaultValue="">
                <option value="">Selecciona un conductor</option>
                {sinCuenta.map(conductor => <option key={conductor.id} value={conductor.id}>{conductor.nombre}</option>)}
              </select>
              {!!sinCuenta.length || <small>No hay conductores sin cuenta. Puedes registrar uno en Catálogos.</small>}
            </Campo>}
          </>}
          <Campo nombre="clave" etiqueta="Nueva contraseña" errores={errores}>
            <input id="clave" name="clave" className="form-control" type="password" required minLength={12} maxLength={72} autoComplete="new-password" aria-describedby="requisito-clave" />
            <small id="requisito-clave">Usa al menos 12 caracteres.</small>
          </Campo>
          {error && <p className="form-error" role="alert">{error}</p>}
          <BotonOperacion principal type="submit">{ocupado ? 'Guardando…' : cambiandoClave ? 'Actualizar contraseña' : 'Guardar cuenta'}</BotonOperacion>
        </fieldset>
      </form>}
    </Dialogo>
  </>;
}
