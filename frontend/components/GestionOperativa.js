'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import Campo from './Campo';
import Dialogo from './Dialogo';
import { enviarAccion } from '../lib/api';
import { normalizar, numero } from '../lib/presentacion';

const dinero = valor => `$${numero(valor)} COP`;
const fechaLocal = () => new Intl.DateTimeFormat('sv-SE', { timeZone:'America/Bogota' }).format(new Date());
const opciones = mapa => Object.entries(mapa);
const estadosConductor = { DISPONIBLE:'Disponible', INACTIVO:'Inactivo', EN_VIAJE:'En viaje' };
const gravedad = { BAJA:'Baja', MEDIA:'Media', ALTA:'Alta' };
const vehiculos = datos => datos.vehiculos.map(bus => [bus.id, `${bus.placa} · ${bus.marca}`]);
const viajes = datos => datos.viajes.filter(viaje => ['EN_CURSO','FINALIZADO'].includes(viaje.estado))
  .map(viaje => [viaje.id, `V-${viaje.id} · ${datos.vehiculos.find(bus => bus.id === viaje.vehiculo_id)?.placa ?? ''}`]);
const fechaRegistro = { id:'fecha', etiqueta:'Fecha del registro', tipo:'date', inicial:fechaLocal, max:fechaLocal };
const detalle = { id:'detalle', etiqueta:'Detalle', tipo:'textarea', maxLength:500 };
const vehiculo = { id:'vehiculo_id', etiqueta:'Vehículo', opciones:vehiculos };
const distancia = { id:'distancia', etiqueta:'Distancia en km', tipo:'number', min:0.01, max:5000, step:0.01 };

const modulos = {
  rutas: {
    titulo:'Rutas', crear:'Registrar ruta',
    columnas:['Código','Recorrido','Distancia','Duración','Estado'],
    fila:ruta => [ruta.codigo, `${ruta.origen} – ${ruta.destino}`, `${numero(ruta.distancia)} km`, `${ruta.duracion} min`, ruta.activa ? 'Activa' : 'Inactiva'],
    campos:[
      { id:'codigo', etiqueta:'Código de ruta', maxLength:15, pattern:'[A-Za-z0-9\\-]+' },
      { id:'origen', etiqueta:'Origen', maxLength:60 }, { id:'destino', etiqueta:'Destino', maxLength:60 },
      distancia, { id:'duracion', etiqueta:'Duración en minutos', tipo:'number', min:1, max:4320 },
      { id:'activa', etiqueta:'Estado', opciones:() => [['1','Activa'],['0','Inactiva']], valor:ruta => ruta.activa === false ? '0' : '1' },
    ],
  },
  conductores: {
    titulo:'Conductores', crear:'Registrar conductor',
    columnas:['Nombre','Licencia vigente hasta','Estado'],
    fila:conductor => [conductor.nombre, conductor.licencia_vence, estadosConductor[conductor.estado]],
    campos:[
      { id:'nombre', etiqueta:'Nombre completo', maxLength:80 },
      { id:'licencia_vence', etiqueta:'Vencimiento de la licencia', tipo:'date' },
      { id:'estado', etiqueta:'Estado', opciones:() => opciones({ DISPONIBLE:'Disponible', INACTIVO:'Inactivo' }), valor:conductor => conductor.estado === 'INACTIVO' ? 'INACTIVO' : 'DISPONIBLE' },
    ],
  },
  combustible: {
    titulo:'Combustible', crear:'Registrar abastecimiento',
    columnas:['Fecha','Placa','Litros','Precio por litro','Total','Detalle'],
    fila:registro => [registro.fecha, registro.placa, numero(registro.litros), dinero(registro.precio_litro), dinero(registro.total), registro.detalle],
    campos:[vehiculo, fechaRegistro,
      { id:'litros', etiqueta:'Litros', tipo:'number', min:0.01, max:2000, step:0.01 },
      { id:'precio_litro', etiqueta:'Precio por litro en COP', tipo:'number', min:0.01, max:1000000, step:0.01 },
      detalle,
    ],
  },
  mantenimientos: {
    titulo:'Mantenimientos', crear:'Registrar mantenimiento',
    columnas:['Fecha','Placa','Kilometraje','Próximo servicio','Detalle'],
    fila:registro => [registro.fecha, registro.placa, `${numero(registro.kilometraje)} km`, `${numero(registro.proximo_mantenimiento)} km`, registro.detalle],
    campos:[vehiculo, fechaRegistro,
      { id:'kilometraje', etiqueta:'Kilometraje del servicio', tipo:'number', min:0, max:9999999, step:0.01 },
      { id:'proximo_mantenimiento', etiqueta:'Próximo mantenimiento en km', tipo:'number', min:0.01, max:9999999, step:0.01 },
      detalle,
    ],
  },
  incidentes: {
    titulo:'Incidentes', crear:'Registrar incidente',
    columnas:['Fecha','Placa','Viaje','Gravedad','Detalle'],
    fila:registro => [registro.fecha, registro.placa, `V-${registro.viaje_id}`, gravedad[registro.gravedad], registro.detalle],
    campos:[
      { id:'viaje_id', etiqueta:'Viaje', opciones:viajes }, fechaRegistro,
      { id:'gravedad', etiqueta:'Gravedad', opciones:() => opciones(gravedad) }, detalle,
    ],
  },
};

export default function GestionOperativa({ seccion, tipoInicial, datos }) {
  const router = useRouter();
  const esCatalogo = seccion === 'catalogos';
  const tipos = esCatalogo ? ['rutas','conductores'] : ['combustible','mantenimientos','incidentes'];
  const [tipo, setTipo] = useState(tipos.includes(tipoInicial) ? tipoInicial : tipos[0]);
  const [busqueda, setBusqueda] = useState('');
  const [formulario, setFormulario] = useState(null);
  const [ocupado, setOcupado] = useState(false);
  const [actualizando, actualizar] = useTransition();
  const [mensaje, setMensaje] = useState('');
  const [error, setError] = useState('');
  const [errores, setErrores] = useState({});
  const modulo = modulos[tipo];
  const editando = formulario?.id !== undefined;
  const titulo = editando ? (tipo === 'rutas' ? 'Editar ruta' : 'Editar conductor') : modulo.crear;
  const filas = datos[tipo].map(item => ({ item, celdas:modulo.fila(item) }))
    .filter(({ celdas }) => normalizar(celdas.join(' ')).includes(normalizar(busqueda)));

  function abrir(item = {}) {
    setMensaje('');
    setError('');
    setErrores({});
    setFormulario(item);
  }

  async function guardar(evento) {
    evento.preventDefault();
    if (ocupado) return;
    const entrada = Object.fromEntries(new FormData(evento.currentTarget));
    const ruta = `${seccion}/${tipo}${editando ? `/${formulario.id}` : ''}`;
    setOcupado(true);
    setError('');
    setErrores({});
    try {
      const respuesta = await enviarAccion(ruta, entrada, editando ? 'PUT' : 'POST');
      setFormulario(null);
      setBusqueda('');
      setMensaje(respuesta.message);
      actualizar(() => router.refresh());
    } catch (fallo) {
      setError(fallo.message);
      setErrores(fallo.errores || {});
      if (fallo.estado === 409) actualizar(() => router.refresh());
    } finally {
      setOcupado(false);
    }
  }

  return <>
    <div className="page-title">
      <h1>{esCatalogo ? 'Catálogos' : 'Registros de operación'}</h1>
      <p>{esCatalogo ? 'Administra los recorridos y conductores que se usan al programar un viaje.' : 'Consulta los abastecimientos, servicios e incidentes de la flota.'}</p>
    </div>
    <nav className="module-nav" aria-label={esCatalogo ? 'Catálogos' : 'Tipos de registro'}>
      {tipos.map(clave => <button type="button" key={clave} className="btn btn-light" aria-pressed={tipo === clave} onClick={() => {
        setTipo(clave);
        setBusqueda('');
        setMensaje('');
      }}>{modulos[clave].titulo}</button>)}
    </nav>
    {mensaje && <p className="operation-success" role="status">{mensaje}</p>}
    <div className="toolbar">
      <div className="search">
        <label htmlFor="buscar-registro" className="visually-hidden">Buscar en {modulo.titulo.toLowerCase()}</label>
        <input id="buscar-registro" type="search" className="form-control" placeholder={`Buscar en ${modulo.titulo.toLowerCase()}`} value={busqueda} onChange={evento => setBusqueda(evento.target.value)} />
      </div>
      {!esCatalogo && <a className="btn btn-light" href={`/api/registros/${tipo}/csv`}>Descargar CSV</a>}
      <button type="button" className="btn btn-primary" onClick={() => abrir()} disabled={actualizando}>{modulo.crear}</button>
    </div>
    <article className="panel">
      <div className="panel-heading"><h2>{modulo.titulo}</h2><span>{filas.length} {filas.length === 1 ? 'registro' : 'registros'}</span></div>
      {filas.length ? <div className="table-responsive"><table className="table align-middle">
        <thead><tr>{modulo.columnas.map(columna => <th key={columna} scope="col">{columna}</th>)}{esCatalogo && <th scope="col">Acciones</th>}</tr></thead>
        <tbody>{filas.map(({ item, celdas }) => <tr key={item.id}>
          {celdas.map((valor, indice) => <td key={modulo.columnas[indice]} data-label={modulo.columnas[indice]}>
            {indice === 0 ? <strong>{valor}</strong> : <span className={modulo.columnas[indice] === 'Detalle' ? 'record-detail' : undefined}>{valor}</span>}
          </td>)}
          {esCatalogo && <td data-label="Acciones"><button type="button" className="btn btn-light btn-sm" disabled={actualizando} onClick={() => abrir(item)}>Editar</button></td>}
        </tr>)}</tbody>
      </table></div> : <p className="empty-state" role="status">{busqueda ? 'No hay registros que coincidan con la búsqueda.' : 'Todavía no hay registros en esta sección.'}</p>}
    </article>
    <Dialogo abierto={!!formulario} titulo={titulo} ocupado={ocupado} cerrar={() => setFormulario(null)}>
      {formulario && <form onSubmit={guardar} aria-busy={ocupado}>
        <fieldset disabled={ocupado}>
          {editando && <input type="hidden" name="revision" value={formulario.revision ?? 0} />}
          {tipo === 'conductores' && formulario.estado === 'EN_VIAJE' && <p className="operation-hint">El conductor conserva el estado En viaje hasta que se registre la llegada.</p>}
          <div className="operation-grid">
            {modulo.campos.map(({ id, etiqueta, tipo:control = 'text', opciones:lista, valor, inicial, max, ...limites }) => {
              const atributos = {
                id, name:id, required:true,
                defaultValue:valor ? valor(formulario) : formulario[id] ?? inicial?.() ?? '',
                'aria-invalid':!!errores[id],
                'aria-describedby':errores[id] ? `${id}-error` : undefined,
              };
              return <Campo key={id} nombre={id} etiqueta={etiqueta} errores={errores}>
                {lista ? <select className="form-select" {...atributos}><option value="">Selecciona</option>
                  {lista(datos).map(([clave, texto]) => <option key={clave} value={clave}>{texto}</option>)}
                </select> : control === 'textarea' ? <textarea className="form-control" rows={3} {...atributos} {...limites} />
                  : <input className="form-control" type={control} max={typeof max === 'function' ? max() : max} {...atributos} {...limites} />}
              </Campo>;
            })}
          </div>
          {error && <p className="form-error" role="alert">{error}</p>}
          <button type="submit" className="btn btn-primary">{ocupado ? 'Guardando…' : 'Guardar'}</button>
        </fieldset>
      </form>}
    </Dialogo>
  </>;
}
