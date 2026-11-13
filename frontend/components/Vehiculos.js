'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import Dialogo from './Dialogo';
import Campo from './Campo';
import { enviarAccion } from '../lib/api';
import { estadosVehiculo, tiposVehiculo, normalizar, numero, claseEstado } from '../lib/presentacion';

export default function Vehiculos({ iniciales, puedeEditar }) {
  const router = useRouter();
  const [actualizando, actualizar] = useTransition();
  const [busqueda, setBusqueda] = useState('');
  const [estado, setEstado] = useState('');
  const [formulario, setFormulario] = useState(null);
  const [ocupado, setOcupado] = useState(false);
  const [error, setError] = useState('');
  const [errores, setErrores] = useState({});
  const [mensaje, setMensaje] = useState('');
  const campo = nombre => ({ id: nombre, name: nombre, 'aria-invalid': !!errores[nombre], 'aria-describedby': errores[nombre] ? `${nombre}-error` : undefined });
  const lista = iniciales.filter(v => normalizar(`${v.placa} ${v.codigo} ${v.marca} ${v.modelo}`).includes(normalizar(busqueda)) && (!estado || v.estado===estado));
  const editando = formulario?.id !== undefined;
  const titulo = editando ? 'Editar vehículo' : 'Registrar vehículo';
  const estadosFormulario = Object.entries(estadosVehiculo).filter(([valor]) => !editando || valor !== 'EN_RUTA');

  function abrir(vehiculo = {}) {
    setError('');
    setErrores({});
    setMensaje('');
    setFormulario(vehiculo);
  }
  async function guardar(evento) {
    evento.preventDefault();
    if (ocupado) return;
    const datos = Object.fromEntries(new FormData(evento.currentTarget));
    const ruta = editando ? `vehiculos/${formulario.id}` : 'vehiculos';
    setOcupado(true); setError(''); setErrores({});
    try {
      const respuesta = await enviarAccion(ruta, datos, editando ? 'PUT' : 'POST');
      setBusqueda('');
      setEstado('');
      setFormulario(null);
      setMensaje(respuesta.message);
      actualizar(() => router.refresh());
    } catch (fallo) {
      setError(fallo.message);
      setErrores(fallo.errores || {});
      if (fallo.estado === 409) actualizar(() => router.refresh());
    }
    finally { setOcupado(false); }
  }

  return <>
    <div className="page-title"><h1>Vehículos</h1><p>Consulta, registra y actualiza los buses de tu flota.</p></div>
    {mensaje && <p role="status" className="operation-success">{mensaje}</p>}
    <div className="toolbar">
      <div className="search"><label htmlFor="buscar-vehiculo" className="visually-hidden">Buscar vehículo</label><input id="buscar-vehiculo" type="search" className="form-control" placeholder="Buscar placa o marca..." value={busqueda} onChange={e => setBusqueda(e.target.value)} /></div>
      <label className="visually-hidden" htmlFor="estado-vehiculo">Filtrar vehículos por estado</label><select id="estado-vehiculo" className="form-select" value={estado} onChange={e => setEstado(e.target.value)}><option value="">Todos los estados</option>{Object.entries(estadosVehiculo).map(([valor,texto]) => <option key={valor} value={valor}>{texto}</option>)}</select>
      {puedeEditar && <button type="button" className="btn btn-primary" onClick={() => abrir()} disabled={actualizando}>Registrar vehículo</button>}
    </div>
    <article className="panel">
      <div className="panel-heading"><h2>Inventario de vehículos</h2><span role="status">{lista.length} {lista.length===1 ? 'vehículo' : 'vehículos'}</span></div>
      {lista.length ? <div className="table-responsive"><table className="table align-middle">
        <thead><tr><th>Placa</th><th>Modelo</th><th>Capacidad</th><th>Kilometraje</th><th>Estado</th>{puedeEditar && <th>Acciones</th>}</tr></thead>
        <tbody>{lista.map(v => <tr key={v.id}>
          <td data-label="Placa"><strong>{v.placa}</strong><small>{v.codigo}</small></td>
          <td data-label="Modelo"><div>{v.marca} {v.modelo}<small>{tiposVehiculo[v.tipo]}</small></div></td>
          <td data-label="Capacidad">{v.capacidad} pasajeros</td>
          <td data-label="Kilometraje">{numero(v.kilometraje)} km</td>
          <td data-label="Estado"><span className={`status status-${claseEstado(v.estado)}`}>{estadosVehiculo[v.estado]}</span></td>
          {puedeEditar && <td data-label="Acciones"><button type="button" className="btn btn-light btn-sm" onClick={() => abrir(v)} disabled={actualizando}>Editar</button></td>}
        </tr>)}</tbody>
      </table></div> : <p className="empty-state" role="status">{iniciales.length === 0
        ? (puedeEditar ? 'Todavía no hay vehículos. Pulsa Registrar vehículo para agregar el primero.' : 'Todavía no hay vehículos registrados.')
        : 'No hay vehículos que coincidan con la búsqueda.'}</p>}
    </article>
    <Dialogo abierto={!!formulario} titulo={titulo} cerrar={() => setFormulario(null)} ocupado={ocupado}>
      {formulario && <form onSubmit={guardar} onChange={evento => { const nombre=evento.target.name; setError(''); setErrores(actuales => { const copia={...actuales}; delete copia[nombre]; return copia; }); }} aria-busy={ocupado}>
        <fieldset disabled={ocupado}>
          {editando && <input type="hidden" name="revision" value={formulario.revision ?? 0} />}
          <div className="operation-grid">
            <Campo nombre="placa" etiqueta="Placa" errores={errores}><input {...campo('placa')} defaultValue={formulario.placa} className="form-control" required pattern="[A-Za-z]{3}[0-9]{3}" maxLength={6} placeholder="ABC123" autoComplete="off" /></Campo>
            <Campo nombre="codigo" etiqueta="Código interno" errores={errores}><input {...campo('codigo')} defaultValue={formulario.codigo} className="form-control" required maxLength={15} placeholder="BUS-NOR-006" autoComplete="off" /></Campo>
            <Campo nombre="tipo" etiqueta="Tipo" errores={errores}><select {...campo('tipo')} className="form-select" defaultValue={formulario.tipo ?? 'BUS_URBANO'}>{Object.entries(tiposVehiculo).map(([v,t]) => <option value={v} key={v}>{t}</option>)}</select></Campo>
            <Campo nombre="marca" etiqueta="Marca y línea" errores={errores}><input {...campo('marca')} defaultValue={formulario.marca} className="form-control" required maxLength={40} placeholder="Chevrolet NPR" /></Campo>
            <Campo nombre="modelo" etiqueta="Modelo" errores={errores}><input {...campo('modelo')} defaultValue={formulario.modelo} className="form-control" type="number" min={2000} max={2035} required placeholder="2026" /></Campo>
            <Campo nombre="capacidad" etiqueta="Capacidad de pasajeros" errores={errores}><input {...campo('capacidad')} defaultValue={formulario.capacidad} className="form-control" type="number" min={10} max={80} required /></Campo>
            <Campo nombre="kilometraje" etiqueta="Kilometraje actual" errores={errores}><input {...campo('kilometraje')} defaultValue={formulario.kilometraje} className="form-control" type="number" min={0} max={9999999} step="0.01" required /></Campo>
            <Campo nombre="proximo_mantenimiento" etiqueta="Próximo mantenimiento en km" errores={errores}><input {...campo('proximo_mantenimiento')} defaultValue={formulario.proximo_mantenimiento} className="form-control" type="number" min={0} max={9999999} step="0.01" required /></Campo>
            <Campo nombre="estado" etiqueta="Estado" errores={errores}>
              <select {...campo('estado')} className="form-select" defaultValue={formulario.estado === 'EN_RUTA' && editando ? '' : formulario.estado ?? 'DISPONIBLE'} required>
                {editando && formulario.estado === 'EN_RUTA' && <option value="" disabled>Selecciona un estado</option>}
                {estadosFormulario.map(([v,t]) => <option value={v} key={v}>{t}</option>)}
              </select>
              {editando && <small>Usa Fuera de servicio para retirar un bus del listado de asignación.</small>}
            </Campo>
          </div>
          <p className="form-error" role="alert">{error}</p>
          <button type="submit" className="btn btn-primary w-100">{ocupado ? 'Guardando vehículo…' : editando ? 'Guardar cambios' : 'Guardar vehículo'}</button>
        </fieldset>
      </form>}
    </Dialogo>
  </>;
}
