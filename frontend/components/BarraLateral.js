'use client';

import { useState } from 'react';
import { enviarAccion } from '../lib/api';
import Marca from './Marca';
import IconoOperacion from './IconoOperacion';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

export default function BarraLateral({ usuario }) {
  const ruta = usePathname();
  const [saliendo, setSaliendo] = useState(false);
  const [error, setError] = useState('');
  const despacho = ['Administrador', 'Operador'].includes(usuario.rol);
  const enlaces = usuario.rol === 'Conductor' ? [['mis-viajes','Mis viajes','viajes']] : [['resumen','Resumen']];
  if (despacho) enlaces.push(['vehiculos','Vehículos'], ['viajes','Viajes']);
  if (usuario.rol === 'Administrador') enlaces.push(['catalogos','Catálogos']);
  if (despacho) enlaces.push(['registros','Registros']);
  if (usuario.rol === 'Administrador') enlaces.push(['accesos','Accesos']);

  async function salir() {
    setSaliendo(true);
    setError('');
    try {
      await enviarAccion('logout');
      window.location.replace('/login');
    } catch (fallo) {
      if (fallo.estado === 401) { window.location.replace('/login'); return; }
      setError(fallo.message);
      setSaliendo(false);
    }
  }

  return <aside className="sidebar">
    <Marca />
    <p className="nav-label">OPERACIÓN</p>
    <nav aria-label="Navegación principal">
      {enlaces.map(([seccion, texto, icono = seccion]) => {
        const href = `/${seccion}`;
        return <Link href={href} key={href} prefetch={false} className={ruta===href ? 'active' : ''} aria-current={ruta===href ? 'page' : undefined}><IconoOperacion nombre={icono} />{texto}</Link>;
      })}
    </nav>
    <div className="sidebar-bottom">
      <span className="avatar" aria-hidden="true">{usuario.nombre.split(/\s+/).slice(0, 2).map(palabra => palabra[0]).join('').toUpperCase()}</span>
      <div>{usuario.nombre}<small>{usuario.rol}</small></div>
      <button className="salir" type="button" onClick={salir} disabled={saliendo}><IconoOperacion nombre="salir" />{saliendo ? 'Saliendo…' : 'Salir'}</button>
      {error && <p className="text-danger" role="alert">{error}</p>}
    </div>
  </aside>;
}
