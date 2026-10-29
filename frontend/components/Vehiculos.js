'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import Dialogo from './Dialogo';
import Campo from './Campo';
import { enviarAccion } from '../lib/api';
import { estadosVehiculo, tiposVehiculo, normalizar, numero, claseEstado } from '../lib/presentacion';

export default function Vehiculos({ iniciales }) {
  const router = useRouter();
  const [vehiculos, setVehiculos] = useState(iniciales);
  const [busqueda, setBusqueda] = useState('');
  const [estado, setEstado] = useState('');
  const [abierto, setAbierto] = useState(false);
  const [ocupado, setOcupado] = useState(false);
  const [error, setError] = useState('');
  const [errores, setErrores] = useState({});
  const [mensaje, setMensaje] = useState('');
  const campo = nombre => ({ id: nombre, name: nombre, 'aria-invalid': !!errores[nombre], 'aria-describedby': errores[nombre] ? `${nombre}-error` : undefined });
  const lista = vehiculos.filter(v => normalizar(`${v.placa} ${v.codigo} ${v.marca} ${v.modelo}`).includes(normalizar(busqueda)) && (!estado || v.estado===estado));

  function abrir() { setError(''); setErrores({}); setMensaje(''); setAbierto(true); }
  async function guardar(evento) {
    evento.preventDefault();
    if (ocupado) return;
    const form = evento.currentTarget;
    const datos = Object.fromEntries(new FormData(form));
    setOcupado(true); setError(''); setErrores({});
    try {
      const respuesta = await enviarAccion('vehiculos', datos);
      setVehiculos(actuales => [...actuales, respuesta.vehiculo]);
      setBusqueda(''); setEstado(''); setAbierto(false); form.reset(); setMensaje(respuesta.message);
      router.refresh();
    } catch (fallo) { setError(fallo.message); setErrores(fallo.errores || {}); }
    finally { setOcupado(false); }
  }

  return <>
    <div className="page-title"><h1>Vehículos</h1><p>Consulta el inventario y registra los buses de tu flota.</p></div>
    {mensaje && <p role="status" className="operation-success">{mensaje}</p>}
    <div className="toolbar">
      <div className="search"><label htmlFor="buscar-vehiculo" className="visually-hidden">Buscar vehículo</label><input id="buscar-vehiculo" type="search" className="form-control" placeholder="Buscar placa o marca..." value={busqueda} onChange={e => setBusqueda(e.target.value)} /></div>
      <label className="visually-hidden" htmlFor="estado-vehiculo">Filtrar vehículos por estado</label><select id="estado-vehiculo" className="form-select" value={estado} onChange={e => setEstado(e.target.value)}><option value="">Todos los estados</option>{Object.entries(estadosVehiculo).map(([valor,texto]) => <option key={valor} value={valor}>{texto}</option>)}</select>
      <button type="button" className="btn btn-primary" onClick={abrir}>Registrar vehículo</button>
    </div>
    <article className="panel">
      <div className="panel-heading"><h2>Inventario de vehículos</h2><span role="status">{lista.length} {lista.length===1 ? 'vehículo' : 'vehículos'}</span></div>
      {lista.length ? <div className="table-responsive"><table className="table align-middle"><thead><tr><th>Placa</th><th>Modelo</th><th>Capacidad</th><th>Kilometraje</th><th>Estado</th></tr></thead><tbody>{lista.map(v => <tr key={v.id}><td data-label="Placa"><strong>{v.placa}</strong><small>{v.codigo}</small></td><td data-label="Modelo"><div>{v.marca} {v.modelo}<small>{tiposVehiculo[v.tipo]}</small></div></td><td data-label="Capacidad">{v.capacidad} pasajeros</td><td data-label="Kilometraje">{numero(v.kilometraje)} km</td><td data-label="Estado"><span className={`status status-${claseEstado(v.estado)}`}>{estadosVehiculo[v.estado]}</span></td></tr>)}</tbody></table></div> : <p className="empty-state" role="status">No hay vehículos que coincidan con la búsqueda.</p>}
    </article>
    <Dialogo abierto={abierto} titulo="Registrar vehículo" cerrar={() => setAbierto(false)} ocupado={ocupado}>
      <form onSubmit={guardar} onChange={evento => { const nombre=evento.target.name; setError(''); setErrores(actuales => { const copia={...actuales}; delete copia[nombre]; return copia; }); }} aria-busy={ocupado}>
        <fieldset disabled={ocupado}>
          <div className="operation-grid">
            <Campo nombre="placa" etiqueta="Placa" errores={errores}><input {...campo('placa')} className="form-control" required pattern="[A-Za-z]{3}[0-9]{3}" maxLength={6} placeholder="ABC123" autoComplete="off" /></Campo>
            <Campo nombre="codigo" etiqueta="Código interno" errores={errores}><input {...campo('codigo')} className="form-control" required maxLength={15} placeholder="BUS-NOR-006" autoComplete="off" /></Campo>
            <Campo nombre="tipo" etiqueta="Tipo" errores={errores}><select {...campo('tipo')} className="form-select" defaultValue="BUS_URBANO">{Object.entries(tiposVehiculo).map(([v,t]) => <option value={v} key={v}>{t}</option>)}</select></Campo>
            <Campo nombre="marca" etiqueta="Marca y línea" errores={errores}><input {...campo('marca')} className="form-control" required maxLength={40} placeholder="Chevrolet NPR" /></Campo>
            <Campo nombre="modelo" etiqueta="Modelo" errores={errores}><input {...campo('modelo')} className="form-control" type="number" min={2000} max={2035} required placeholder="2026" /></Campo>
            <Campo nombre="capacidad" etiqueta="Capacidad de pasajeros" errores={errores}><input {...campo('capacidad')} className="form-control" type="number" min={10} max={80} required /></Campo>
            <Campo nombre="kilometraje" etiqueta="Kilometraje actual" errores={errores}><input {...campo('kilometraje')} className="form-control" type="number" min={0} max={9999999} step="0.01" required /></Campo>
            <Campo nombre="proximo_mantenimiento" etiqueta="Próximo mantenimiento en km" errores={errores}><input {...campo('proximo_mantenimiento')} className="form-control" type="number" min={0} max={9999999} step="0.01" required /></Campo>
            <Campo nombre="estado" etiqueta="Estado" errores={errores}><select {...campo('estado')} className="form-select" defaultValue="DISPONIBLE">{Object.entries(estadosVehiculo).map(([v,t]) => <option value={v} key={v}>{t}</option>)}</select></Campo>
          </div>
          <p className="form-error" role="alert">{error}</p>
          <button type="submit" className="btn btn-primary w-100">{ocupado ? 'Guardando vehículo…' : 'Guardar vehículo'}</button>
        </fieldset>
      </form>
    </Dialogo>
  </>;
}
