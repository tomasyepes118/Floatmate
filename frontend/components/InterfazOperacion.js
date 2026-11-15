import IconoOperacion from './IconoOperacion';
import { claseEstado } from '../lib/presentacion';

export function TituloPagina({ titulo, descripcion }) {
  return <header className="page-title"><h1>{titulo}</h1><p>{descripcion}</p></header>;
}

export function BuscarOperacion({ id, etiqueta, placeholder, value, onChange }) {
  return <div className="search">
    <label htmlFor={id} className="visually-hidden">{etiqueta}</label>
    <IconoOperacion nombre="buscar" />
    <input id={id} type="search" className="form-control" placeholder={placeholder} value={value} onChange={onChange} />
  </div>;
}

export function FiltroEstado({ id, etiqueta, opciones, value, onChange }) {
  return <>
    <label htmlFor={id} className="visually-hidden">{etiqueta}</label>
    <select id={id} className="form-select" value={value} onChange={onChange}>
      <option value="">Todos los estados</option>
      {Object.entries(opciones).map(([valor, texto]) => <option key={valor} value={valor}>{texto}</option>)}
    </select>
  </>;
}

export function BotonOperacion({ href, principal = false, compacto = false, icono, children, ...props }) {
  const clase = `btn ${principal ? 'btn-primary' : 'btn-light'}${compacto ? ' btn-sm' : ''}`;
  const contenido = <>{icono && <IconoOperacion nombre={icono} />}{children}</>;
  return href ? <a className={clase} href={href} {...props}>{contenido}</a>
    : <button className={clase} type="button" {...props}>{contenido}</button>;
}

export function PanelOperacion({ id, titulo, contador, accion, className = '', children }) {
  return <section className={`panel ${className}`} aria-labelledby={id}>
    <div className="panel-heading">
      <h2 id={id}>{titulo}</h2>
      {contador && <span role="status">{contador}</span>}
      {accion}
    </div>
    {children}
  </section>;
}

export function TablaOperacion({ columnas, etiqueta, children }) {
  return <div className="tabla-operacion">
    <table className="table align-middle" aria-labelledby={etiqueta} role="table">
      <thead role="rowgroup"><tr role="row">{columnas.map(columna => <th scope="col" key={columna}>{columna}</th>)}</tr></thead>
      <tbody role="rowgroup">{children}</tbody>
    </table>
  </div>;
}

export function EstadoOperacion({ estado, children }) {
  return <span className={`status status-${claseEstado(estado)}`}>{children}</span>;
}

export function VacioOperacion({ icono, children }) {
  return <div className="empty-state operacion-vacia" role="status">
    {icono && <span><IconoOperacion nombre={icono} /></span>}
    <p>{children}</p>
  </div>;
}
