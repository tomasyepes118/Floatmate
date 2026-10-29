import { redirect } from 'next/navigation';
import { consultarServidor } from '../../lib/servidor';
import BarraLateral from '../../components/BarraLateral';

export const dynamic = 'force-dynamic';

export default async function Resumen() {
  const respuesta = await consultarServidor('resumen');
  if (respuesta.estado === 'sin-sesion') redirect('/login');
  if (respuesta.estado === 'no-disponible') {
    return <main className="service-error"><h1>No pudimos cargar el resumen</h1><p>Revisa que Laravel esté iniciado e intenta de nuevo.</p><a href="/resumen" className="btn btn-primary">Reintentar</a><a href="/login" className="btn btn-light">Volver al acceso</a></main>;
  }
  const { usuario, indicadores, viajes, estados } = respuesta.datos;
  return <>
    <a href="#contenido" className="skip-link">Ir al contenido</a>
    <BarraLateral usuario={usuario} />
    <div className="workspace">
      <header className="topbar"><span>Centro de operaciones</span><span className="demo">Datos de demostración</span></header>
      <main id="contenido">
        <div className="page-title"><h1>Resumen de la flota</h1><p>Revisa la disponibilidad y los próximos viajes de la operación.</p></div>
        <section className="row g-3 mb-4" aria-label="Indicadores">
          {indicadores.map(indicador => <div className="col-6 col-xl-3" key={indicador.nombre}><article className="metric"><span>{indicador.nombre}</span><strong>{indicador.valor}</strong><small>{indicador.descripcion}</small></article></div>)}
        </section>
        <section className="row g-4" aria-label="Operación de la flota">
          <div className="col-xl-8"><article className="panel">
            <div className="panel-heading"><h2>Próximos viajes</h2><a href="/viajes">Ver programación</a></div>
            <div className="table-responsive"><table className="table align-middle"><thead><tr><th>Ruta</th><th>Salida</th><th>Vehículo</th><th>Estado</th></tr></thead>
              <tbody>{viajes.map(viaje => <tr key={viaje.id}><td data-label="Ruta"><strong>{viaje.ruta}</strong><small>{viaje.conductor}</small></td><td data-label="Salida">{viaje.salida}</td><td data-label="Vehículo">{viaje.placa}</td><td data-label="Estado"><span className="status status-moving">{viaje.estado}</span></td></tr>)}</tbody>
            </table></div>
          </article></div>
          <div className="col-xl-4"><article className="panel mb-4"><h2>Estado de los vehículos</h2>
            {estados.map(estado => <div className="state-row" key={estado.nombre}><div><span>{estado.nombre}</span><strong>{estado.cantidad}</strong></div><div className="progress" role="progressbar" aria-label={estado.nombre} aria-valuenow={estado.cantidad} aria-valuemin={0} aria-valuemax={indicadores[0].valor}><div className="progress-bar" style={{ width: `${indicadores[0].valor ? estado.cantidad / indicadores[0].valor * 100 : 0}%` }} /></div></div>)}
          </article><article className="quick-panel"><h2>Organiza tu operación</h2><p>Consulta los buses y prepara la programación de la flota.</p><a className="btn btn-light" href="/vehiculos">Consultar vehículos</a></article></div>
        </section>
      </main>
      <footer>FloatMate · Prototipo académico · Programación Web</footer>
    </div>
  </>;
}
