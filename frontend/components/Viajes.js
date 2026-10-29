'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Dialogo from './Dialogo';
import Campo from './Campo';
import { enviarAccion } from '../lib/api';
import { normalizar, fecha, estadosViaje, claseEstado } from '../lib/presentacion';

export default function Viajes({ iniciales }) {
  const router = useRouter();
  const [viajes, setViajes] = useState(iniciales.viajes);
  const { rutas, conductores, vehiculos } = iniciales;
  const [busqueda, setBusqueda] = useState('');
  const [estado, setEstado] = useState('');
  const [abierto, setAbierto] = useState(false);
  const [ocupado, setOcupado] = useState(false);
  const [error, setError] = useState('');
  const [errores, setErrores] = useState({});
  const [mensaje, setMensaje] = useState('');
  const [rutaId, setRutaId] = useState('');
  const [vehiculoId, setVehiculoId] = useState('');
  const ruta = rutas.find(r => r.id===Number(rutaId));
  const vehiculo = vehiculos.find(v => v.id===Number(vehiculoId));
  const campo = nombre => ({ id: nombre, name: nombre, 'aria-invalid': !!errores[nombre], 'aria-describedby': errores[nombre] ? `${nombre}-error` : undefined });
  const lista = viajes.map(v => ({ ...v, ruta: rutas.find(r => r.id===v.ruta_id), vehiculo: vehiculos.find(x => x.id===v.vehiculo_id), conductor: conductores.find(x => x.id===v.conductor_id) }))
    .filter(v => normalizar(`${v.ruta.origen} ${v.ruta.destino} ${v.ruta.codigo} ${v.vehiculo.placa} ${v.conductor.nombre}`).includes(normalizar(busqueda)) && (!estado || v.estado===estado))
    .sort((a,b) => a.salida.localeCompare(b.salida));

  function abrir() { setError(''); setErrores({}); setMensaje(''); setRutaId(''); setVehiculoId(''); setAbierto(true); }
  async function guardar(evento) {
    evento.preventDefault(); if (ocupado) return;
    const form = evento.currentTarget;
    const datos = Object.fromEntries(new FormData(form));
    setOcupado(true); setError(''); setErrores({});
    try {
      const respuesta = await enviarAccion('viajes', datos);
      setViajes(actuales => [...actuales, respuesta.viaje]); setBusqueda(''); setEstado('');
      setAbierto(false); form.reset(); setRutaId(''); setVehiculoId(''); setMensaje(respuesta.message); router.refresh();
    } catch (fallo) { setError(fallo.message); setErrores(fallo.errores || {}); }
    finally { setOcupado(false); }
  }

  return <>
    <div className="page-title"><h1>Viajes</h1><p>Programa recorridos y consulta el estado de cada viaje.</p></div>
    {mensaje && <p className="operation-success" role="status">{mensaje}</p>}
    <div className="toolbar">
      <div className="search"><label htmlFor="buscar-viaje" className="visually-hidden">Buscar viaje</label><input id="buscar-viaje" className="form-control" type="search" placeholder="Buscar ruta, conductor o placa..." value={busqueda} onChange={e => setBusqueda(e.target.value)} /></div>
      <label className="visually-hidden" htmlFor="estado-viaje">Filtrar viajes por estado</label><select id="estado-viaje" className="form-select" value={estado} onChange={e => setEstado(e.target.value)}><option value="">Todos los estados</option>{Object.entries(estadosViaje).map(([v,t]) => <option key={v} value={v}>{t}</option>)}</select>
      <button type="button" className="btn btn-primary" onClick={abrir}>Programar viaje</button>
    </div>
    <article className="panel"><div className="panel-heading"><h2>Programación de viajes</h2><span role="status">{lista.length} {lista.length===1 ? 'viaje' : 'viajes'}</span></div>
      {lista.length ? <div className="table-responsive"><table className="table align-middle"><thead><tr><th>Ruta</th><th>Conductor</th><th>Vehículo</th><th>Salida</th><th>Pasajeros</th><th>Estado</th></tr></thead><tbody>{lista.map(v => <tr key={v.id}><td data-label="Ruta"><strong>{v.ruta.origen} - {v.ruta.destino}</strong><small>{v.ruta.codigo} · V-{v.id}</small></td><td data-label="Conductor">{v.conductor.nombre}</td><td data-label="Vehículo">{v.vehiculo.placa}</td><td data-label="Salida">{fecha(v.salida)}</td><td data-label="Pasajeros">{v.pasajeros}</td><td data-label="Estado"><span className={`status status-${claseEstado(v.estado)}`}>{estadosViaje[v.estado]}</span></td></tr>)}</tbody></table></div> : <p className="empty-state" role="status">No hay viajes que coincidan con la búsqueda.</p>}
    </article>
    <Dialogo abierto={abierto} titulo="Programar viaje" cerrar={() => setAbierto(false)} ocupado={ocupado}>
      <form onSubmit={guardar} onChange={evento => { const nombre=evento.target.name; setError(''); setErrores(actuales => { const copia={...actuales}; delete copia[nombre]; return copia; }); }} aria-busy={ocupado}>
        <fieldset disabled={ocupado}>
          <Campo nombre="ruta_id" etiqueta="Ruta activa" errores={errores}><select {...campo('ruta_id')} className="form-select" required value={rutaId} onChange={e => setRutaId(e.target.value)}><option value="">Selecciona una ruta</option>{rutas.filter(r => r.activa).map(r => <option key={r.id} value={r.id}>{r.origen} - {r.destino}</option>)}</select></Campo>
          {ruta && <p className="route-detail">{ruta.codigo} · {ruta.distancia} km · {ruta.duracion} minutos</p>}
          <Campo nombre="vehiculo_id" etiqueta="Vehículo disponible" errores={errores}><select {...campo('vehiculo_id')} className="form-select" required value={vehiculoId} onChange={e => setVehiculoId(e.target.value)}><option value="">Selecciona un vehículo</option>{vehiculos.filter(v => v.estado==='DISPONIBLE').map(v => <option key={v.id} value={v.id}>{v.placa} · {v.capacidad} pasajeros</option>)}</select></Campo>
          <Campo nombre="conductor_id" etiqueta="Conductor disponible" errores={errores}><select {...campo('conductor_id')} className="form-select" required defaultValue=""><option value="">Selecciona un conductor</option>{conductores.filter(c => c.estado==='DISPONIBLE').map(c => <option key={c.id} value={c.id}>{c.nombre}</option>)}</select></Campo>
          <div className="operation-grid">
            <Campo nombre="salida" etiqueta="Fecha y hora de salida" errores={errores}><input {...campo('salida')} className="form-control" type="datetime-local" required /><small>Hora de Colombia.</small></Campo>
            <Campo nombre="pasajeros" etiqueta="Pasajeros" errores={errores}><input {...campo('pasajeros')} className="form-control" type="number" min={1} max={vehiculo ? vehiculo.capacidad : 80} required />{vehiculo && <small>Capacidad máxima de {vehiculo.capacidad} pasajeros.</small>}</Campo>
          </div>
          <Campo nombre="observaciones" etiqueta="Observaciones" errores={errores}><textarea {...campo('observaciones')} className="form-control" maxLength={250} rows={2} /></Campo>
          <p className="operation-hint">Revisamos la disponibilidad, la capacidad y los cruces de horario antes de confirmar.</p>
          <p className="form-error" role="alert">{error}</p>
          <button type="submit" className="btn btn-primary w-100">{ocupado ? 'Programando viaje…' : 'Confirmar programación'}</button>
        </fieldset>
      </form>
    </Dialogo>
  </>;
}
