import { redirect } from 'next/navigation';
import { consultarServidor } from '../../lib/servidor';
import MarcoAplicacion from '../../components/MarcoAplicacion';
import IconoOperacion from '../../components/IconoOperacion';
import { numero } from '../../lib/presentacion';
import { inter } from '../tipografia';
import './resumen.css';

export const dynamic = 'force-dynamic';

export default async function Resumen() {
  const respuesta = await consultarServidor('resumen');
  if (respuesta.estado === 'sin-sesion') redirect('/login');
  if (respuesta.estado === 'no-disponible') {
    return <main className="service-error"><h1>No pudimos cargar el resumen</h1><p>Revisa que Laravel esté iniciado e intenta de nuevo.</p><a href="/resumen" className="btn btn-primary">Reintentar</a><a href="/login" className="btn btn-light">Volver al acceso</a></main>;
  }
  const { usuario, indicadores, viajes, estados, actividad } = respuesta.datos;
  const [proxima] = viajes;
  const totalVehiculos = estados.reduce((total, estado) => total + estado.cantidad, 0);
  const consulta = usuario.rol === 'Consulta';

  return <MarcoAplicacion usuario={usuario} className={`resumen-operacion ${inter.className}`} mostrarIconos>
    <div className="page-title resumen-titulo">
      <h1>Resumen de la flota</h1>
      <p>Revisa la disponibilidad y los próximos viajes de la operación.</p>
    </div>

    <section className="proxima-salida" aria-labelledby="proxima-salida-titulo">
      <div className="proxima-salida-recorrido" aria-hidden="true"><span /><span /></div>
      <div className="proxima-salida-contenido">
        <h2 id="proxima-salida-titulo">Próxima salida</h2>
        {proxima ? <>
          <p className="proxima-salida-ruta">{proxima.ruta.replace(' - ', ' → ')}</p>
          <div className="proxima-salida-datos">
            <time dateTime={proxima.salida_iso}>{proxima.salida.replace(', ', ' · ')}</time>
            <span>{proxima.placa}</span>
          </div>
        </> : <p className="proxima-salida-ruta">Sin salidas programadas</p>}
      </div>
    </section>

    <section className="resumen-metricas" aria-label="Indicadores">
      {indicadores.map(({ codigo, nombre, valor, descripcion }) => <article className="metric" key={codigo} data-indicador={codigo}>
        <span>{nombre}</span>
        <div className="resumen-metrica-icono"><IconoOperacion nombre={codigo === 'disponibles' ? 'vehiculos' : codigo} /></div>
        <strong>{numero(valor)}</strong>
        <small>{descripcion}</small>
      </article>)}
    </section>

    <div className="resumen-operacion-grid">
      <section className="panel resumen-viajes" aria-labelledby="resumen-viajes-titulo">
        <div className="panel-heading">
          <h2 id="resumen-viajes-titulo">Próximos viajes</h2>
          {!consulta && <a href="/viajes">Ver programación <IconoOperacion nombre="flecha" /></a>}
        </div>
        {viajes.length ? <table className="table align-middle">
          <thead><tr><th scope="col">Ruta</th><th scope="col">Salida</th><th scope="col">Vehículo</th><th scope="col">Estado</th></tr></thead>
          <tbody>{viajes.map(viaje => <tr key={viaje.id}>
            <td data-label="Ruta"><strong>{viaje.ruta.replace(' - ', ' → ')}</strong><small>{viaje.conductor}</small></td>
            <td data-label="Salida"><time dateTime={viaje.salida_iso}>{viaje.salida}</time></td>
            <td data-label="Vehículo">{viaje.placa}</td>
            <td data-label="Estado"><span className="status status-moving">{viaje.estado}</span></td>
          </tr>)}</tbody>
        </table> : <p className="empty-state">No hay viajes programados.</p>}
      </section>

      <section className="panel resumen-estados" aria-labelledby="resumen-estados-titulo">
        <h2 id="resumen-estados-titulo">Estado de los vehículos</h2>
        <ul>
          {estados.map(({ codigo, nombre, cantidad }) => <li key={codigo} data-estado={codigo}>
            <span>{nombre}</span>
            <strong>{numero(cantidad)}</strong>
            <div className="resumen-estado-barra" aria-hidden="true">
              <span style={{ width: `${totalVehiculos ? cantidad / totalVehiculos * 100 : 0}%` }} />
            </div>
          </li>)}
        </ul>
      </section>
    </div>

    <section className="panel resumen-actividad" aria-labelledby="resumen-actividad-titulo">
      <div className="panel-heading">
        <h2 id="resumen-actividad-titulo">Actividad registrada</h2>
        <a href={consulta ? '/api/registros/combustible/csv' : '/registros'}>
          {consulta ? 'Descargar combustible' : 'Consultar registros'} <IconoOperacion nombre="flecha" />
        </a>
      </div>
      <dl>
        <div><dt>Combustible</dt><dd>{numero(actividad.litros)} L</dd></div>
        <div><dt>Gasto en combustible</dt><dd>$ {numero(actividad.costo)} COP</dd></div>
        <div><dt>Mantenimientos</dt><dd>{numero(actividad.mantenimientos)}</dd></div>
        <div><dt>Incidentes</dt><dd>{numero(actividad.incidentes)}</dd></div>
      </dl>
    </section>
  </MarcoAplicacion>;
}
