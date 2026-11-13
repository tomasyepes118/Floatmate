'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import Dialogo from './Dialogo';
import Campo from './Campo';
import { enviarAccion } from '../lib/api';
import { normalizar, fecha, numero, estadosViaje, claseEstado } from '../lib/presentacion';

const acciones = {
  control: { titulo: 'Registrar control de salida', confirmar: 'Guardar control' },
  EN_CURSO: { titulo: 'Iniciar viaje', confirmar: 'Confirmar inicio', detalle: 'Se guardará la hora de salida y se ocuparán el vehículo y el conductor.' },
  FINALIZADO: { titulo: 'Finalizar viaje', confirmar: 'Confirmar llegada', detalle: 'Se guardará la hora de llegada y se actualizará la disponibilidad.' },
  CANCELADO: { titulo: 'Cancelar viaje', confirmar: 'Confirmar cancelación', detalle: 'El viaje quedará en el historial y su horario quedará libre.' },
};

export default function Viajes({ iniciales }) {
  const router = useRouter();
  const [actualizando, actualizar] = useTransition();
  const { viajes, rutas, conductores, vehiculos } = iniciales;
  const [busqueda, setBusqueda] = useState('');
  const [estado, setEstado] = useState('');
  const [abierto, setAbierto] = useState(false);
  const [accion, setAccion] = useState(null);
  const [ocupado, setOcupado] = useState(false);
  const [error, setError] = useState('');
  const [errores, setErrores] = useState({});
  const [mensaje, setMensaje] = useState('');
  const [rutaId, setRutaId] = useState('');
  const [vehiculoId, setVehiculoId] = useState('');
  const [revision, setRevision] = useState(null);
  const [revisando, setRevisando] = useState(false);
  const ruta = rutas.find(r => r.id===Number(rutaId));
  const vehiculo = vehiculos.find(v => v.id===Number(vehiculoId));
  const faltantes = [
    !rutas.some(r => r.activa) && 'una ruta activa',
    !vehiculos.some(v => v.estado === 'DISPONIBLE') && 'un vehículo disponible',
    !conductores.some(c => c.estado === 'DISPONIBLE') && 'un conductor disponible',
  ].filter(Boolean);
  const campo = nombre => ({ id: nombre, name: nombre, 'aria-invalid': !!errores[nombre], 'aria-describedby': errores[nombre] ? `${nombre}-error` : undefined });
  const lista = viajes.map(v => ({ ...v, ruta: rutas.find(r => r.id===v.ruta_id), vehiculo: vehiculos.find(x => x.id===v.vehiculo_id), conductor: conductores.find(x => x.id===v.conductor_id) }))
    .filter(v => normalizar(`${v.ruta.origen} ${v.ruta.destino} ${v.ruta.codigo} ${v.vehiculo.placa} ${v.conductor.nombre}`).includes(normalizar(busqueda)) && (!estado || v.estado===estado))
    .sort((a,b) => a.salida.localeCompare(b.salida));

  function limpiarMensajes() {
    setError('');
    setErrores({});
    setMensaje('');
  }

  function abrir() {
    limpiarMensajes();
    setRevision(null);
    setRutaId('');
    setVehiculoId('');
    setAbierto(true);
  }

  function abrirAccion(tipo, viaje) {
    limpiarMensajes();
    setAccion({ tipo, viaje });
  }

  function corregir(evento) {
    const nombre = evento.target.name;
    if (!accion) setRevision(null);
    setError('');
    setErrores(actuales => {
      const copia = { ...actuales };
      delete copia[nombre];
      return copia;
    });
  }

  async function revisarElegibilidad(evento) {
    const formulario = evento.currentTarget.form;
    if (ocupado || revisando || !formulario.reportValidity()) return;
    const datos = Object.fromEntries(new FormData(formulario));
    setRevision(null);
    setError('');
    setErrores({});
    setRevisando(true);
    try {
      setRevision(await enviarAccion('viajes/elegibilidad', datos));
    } catch (fallo) {
      setError(fallo.message);
      setErrores(fallo.errores || {});
    } finally {
      setRevisando(false);
    }
  }

  async function guardar(evento) {
    evento.preventDefault(); if (ocupado || revisando) return;
    const datos = Object.fromEntries(new FormData(evento.currentTarget));
    setOcupado(true); setError(''); setErrores({});
    try {
      let respuesta;
      if (accion) {
        const rutaViaje = `viajes/${accion.viaje.id}`;
        respuesta = accion.tipo === 'control'
          ? await enviarAccion(`${rutaViaje}/control`, datos)
          : await enviarAccion(`${rutaViaje}/estado`, { ...datos, estado: accion.tipo }, 'PATCH');
      } else {
        respuesta = await enviarAccion('viajes', datos);
        setBusqueda('');
      }
      setEstado('');
      setAbierto(false);
      setAccion(null);
      setMensaje(respuesta.message);
      actualizar(() => router.refresh());
    } catch (fallo) {
      if (!accion) setRevision(null);
      setError(fallo.message);
      setErrores(fallo.errores || {});
      if (accion) actualizar(() => router.refresh());
    }
    finally { setOcupado(false); }
  }

  return <>
    <div className="page-title"><h1>Viajes</h1><p>Programa recorridos y registra sus controles, salidas y llegadas.</p></div>
    {mensaje && <p className="operation-success" role="status">{mensaje}</p>}
    <div className="toolbar">
      <div className="search"><label htmlFor="buscar-viaje" className="visually-hidden">Buscar viaje</label><input id="buscar-viaje" className="form-control" type="search" placeholder="Buscar ruta, conductor o placa..." value={busqueda} onChange={e => setBusqueda(e.target.value)} /></div>
      <label className="visually-hidden" htmlFor="estado-viaje">Filtrar viajes por estado</label><select id="estado-viaje" className="form-select" value={estado} onChange={e => setEstado(e.target.value)}><option value="">Todos los estados</option>{Object.entries(estadosViaje).map(([v,t]) => <option key={v} value={v}>{t}</option>)}</select>
      <button type="button" className="btn btn-primary" onClick={abrir} disabled={actualizando || faltantes.length > 0} aria-describedby={faltantes.length ? 'requisitos-viaje' : undefined}>Programar viaje</button>
    </div>
    {faltantes.length > 0 && <p id="requisitos-viaje" className="operation-hint">Para programar un viaje necesitas {faltantes.join(', ')}. <a href="/recorrido?paso=viajes">Ver el recorrido</a></p>}
    <article className="panel"><div className="panel-heading"><h2>Programación de viajes</h2><span role="status">{lista.length} {lista.length===1 ? 'viaje' : 'viajes'}</span></div>
      {lista.length ? <div className="table-responsive"><table className="table align-middle">
        <thead><tr><th>Ruta</th><th>Conductor</th><th>Vehículo</th><th>Salida prevista</th><th>Pasajeros</th><th>Estado</th><th>Acciones</th></tr></thead>
        <tbody>{lista.map(v => <tr key={v.id}>
          <td data-label="Ruta"><strong>{v.ruta.origen} - {v.ruta.destino}</strong><small>{v.ruta.codigo} · V-{v.id}</small></td>
          <td data-label="Conductor">{v.conductor.nombre}</td>
          <td data-label="Vehículo">{v.vehiculo.placa}</td>
          <td data-label="Salida prevista">
            <div>{fecha(v.salida)}
              {v.salida_real && <small>Salió {fecha(v.salida_real)}</small>}
              {v.llegada_real && <small>Llegó {fecha(v.llegada_real)}</small>}
            </div>
          </td>
          <td data-label="Pasajeros">{v.pasajeros}</td>
          <td data-label="Estado">
            <div className="trip-status">
              <span className={`status status-${claseEstado(v.estado)}`}>{estadosViaje[v.estado]}</span>
              {v.control_salida && <small className={v.control_salida.resultado === 'RECHAZADO' ? 'field-error' : ''}>
                Control {v.control_salida.resultado.toLowerCase()}<br />Ticket {v.control_salida.numero_ticket}
              </small>}
            </div>
          </td>
          <td data-label="Acciones">
            <div className="row-actions">
              {v.estado === 'PROGRAMADO' && !v.control_salida && <button type="button" className="btn btn-light btn-sm" onClick={() => abrirAccion('control', v)} disabled={actualizando}>Registrar control</button>}
              {v.estado === 'PROGRAMADO' && v.control_salida?.resultado === 'APROBADO' && <button type="button" className="btn btn-primary btn-sm" onClick={() => abrirAccion('EN_CURSO', v)} disabled={actualizando}>Iniciar viaje</button>}
              {v.estado === 'PROGRAMADO' && <button type="button" className="btn btn-light btn-sm" onClick={() => abrirAccion('CANCELADO', v)} disabled={actualizando}>Cancelar viaje</button>}
              {v.estado === 'EN_CURSO' && <button type="button" className="btn btn-primary btn-sm" onClick={() => abrirAccion('FINALIZADO', v)} disabled={actualizando}>Finalizar viaje</button>}
              {['FINALIZADO', 'CANCELADO'].includes(v.estado) && <span aria-label="Sin acciones">—</span>}
            </div>
          </td>
        </tr>)}</tbody>
      </table></div> : <p className="empty-state" role="status">{viajes.length === 0 ? 'Todavía no hay viajes programados.' : 'No hay viajes que coincidan con la búsqueda.'}</p>}
    </article>
    <Dialogo abierto={abierto} titulo="Programar viaje" cerrar={() => setAbierto(false)} ocupado={ocupado || revisando}>
      {abierto && <form onSubmit={guardar} onChange={corregir} aria-busy={ocupado || revisando}>
        <fieldset disabled={ocupado || revisando}>
          <Campo nombre="ruta_id" etiqueta="Ruta activa" errores={errores}><select {...campo('ruta_id')} className="form-select" required value={rutaId} onChange={e => setRutaId(e.target.value)}><option value="">Selecciona una ruta</option>{rutas.filter(r => r.activa).map(r => <option key={r.id} value={r.id}>{r.origen} - {r.destino}</option>)}</select></Campo>
          {ruta && <p className="route-detail">{ruta.codigo} · {ruta.distancia} km · {ruta.duracion} minutos</p>}
          <Campo nombre="vehiculo_id" etiqueta="Vehículo disponible" errores={errores}><select {...campo('vehiculo_id')} className="form-select" required value={vehiculoId} onChange={e => setVehiculoId(e.target.value)}><option value="">Selecciona un vehículo</option>{vehiculos.filter(v => v.estado==='DISPONIBLE').map(v => <option key={v.id} value={v.id}>{v.placa} · {v.capacidad} pasajeros</option>)}</select></Campo>
          <Campo nombre="conductor_id" etiqueta="Conductor disponible" errores={errores}><select {...campo('conductor_id')} className="form-select" required defaultValue=""><option value="">Selecciona un conductor</option>{conductores.filter(c => c.estado==='DISPONIBLE').map(c => <option key={c.id} value={c.id}>{c.nombre}</option>)}</select></Campo>
          <div className="operation-grid">
            <Campo nombre="salida" etiqueta="Fecha y hora de salida" errores={errores}><input {...campo('salida')} className="form-control" type="datetime-local" required /><small>Hora de Colombia.</small></Campo>
            <Campo nombre="pasajeros" etiqueta="Pasajeros" errores={errores}><input {...campo('pasajeros')} className="form-control" type="number" min={1} max={80} required />{vehiculo && <small>Capacidad máxima de {vehiculo.capacidad} pasajeros.</small>}</Campo>
          </div>
          <Campo nombre="observaciones" etiqueta="Observaciones" errores={errores}><textarea {...campo('observaciones')} className="form-control" maxLength={250} rows={2} /></Campo>
          <button type="button" className="btn btn-light mb-3" onClick={revisarElegibilidad}>{revisando ? 'Revisando…' : 'Revisar elegibilidad'}</button>
          <div aria-live="polite">
            {revision && <div className="route-detail eligibility-result">
              <p><strong>{revision.problemas.length ? 'La asignación necesita cambios' : 'La asignación cumple las condiciones de programación'}</strong></p>
              {revision.kilometraje && <p>La ruta requiere {numero(revision.kilometraje.distancia)} km. Al vehículo le quedan {numero(Math.max(0, revision.kilometraje.disponible))} km antes del mantenimiento. Llegada estimada a {numero(revision.kilometraje.llegada)} km, con un límite de {numero(revision.kilometraje.limite)} km.</p>}
              {revision.problemas.length > 0 && <ul>{revision.problemas.map(problema => <li key={problema.mensaje}>{problema.mensaje}</li>)}</ul>}
              {revision.alternativas.length > 0 && <div className="row-actions">
                <span>Vehículos compatibles</span>
                {revision.alternativas.map(opcion => <button type="button" key={opcion.id} className="btn btn-light" onClick={() => {
                  setVehiculoId(String(opcion.id));
                  setRevision(null);
                }}>Usar {opcion.placa}</button>)}
              </div>}
              {!revision.problemas.length && revision.kilometraje?.llegada === revision.kilometraje?.limite
                && <p>Si la llegada se registra con ese kilometraje, el bus pasará a Mantenimiento.</p>}
              {!revision.problemas.length && <p>El control de salida se registra después de programar.</p>}
            </div>}
          </div>
          <p className="form-error" role="alert">{error}</p>
          <button type="submit" className="btn btn-primary w-100">{ocupado ? 'Programando viaje…' : 'Confirmar programación'}</button>
        </fieldset>
      </form>}
    </Dialogo>
    <Dialogo abierto={!!accion} titulo={acciones[accion?.tipo]?.titulo} cerrar={() => setAccion(null)} ocupado={ocupado}>
      {accion && <form onSubmit={guardar} onChange={corregir} aria-busy={ocupado}>
        <fieldset disabled={ocupado}>
          <p className="route-detail">V-{accion.viaje.id} · {accion.viaje.ruta.origen} - {accion.viaje.ruta.destino} · {accion.viaje.vehiculo.placa}</p>
          {accion.tipo === 'control' && <>
            <Campo nombre="numero_ticket" etiqueta="Número de ticket" errores={errores}>
              <input {...campo('numero_ticket')} className="form-control" maxLength={40} required />
            </Campo>
            <Campo nombre="alcoholemia_mg_l" etiqueta="Alcoholemia en mg/L" errores={errores}>
              <input {...campo('alcoholemia_mg_l')} className="form-control" type="number" min={0} max={99.999} step="0.001" required />
              <small>El control se registra una vez. Un resultado de 0 mg/L habilita el inicio.</small>
            </Campo>
          </>}
          {accion.tipo === 'FINALIZADO' && <Campo nombre="kilometraje_llegada" etiqueta="Kilometraje de llegada" errores={errores}>
            <input {...campo('kilometraje_llegada')} className="form-control" type="number" min={accion.viaje.vehiculo.kilometraje} max={9999999} step="0.01" required />
            <small>Último kilometraje registrado: {numero(accion.viaje.vehiculo.kilometraje)} km.</small>
          </Campo>}
          {acciones[accion.tipo].detalle && <p className="operation-hint">{acciones[accion.tipo].detalle}</p>}
          <p className="form-error" role="alert">{error}</p>
          <button type="submit" className="btn btn-primary w-100">{ocupado ? 'Guardando…' : acciones[accion.tipo].confirmar}</button>
        </fieldset>
      </form>}
    </Dialogo>
  </>;
}
