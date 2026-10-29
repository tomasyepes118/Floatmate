'use client';

import { useState } from 'react';
import { enviarAccion } from '../lib/api';
import Marca from './Marca';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

export default function BarraLateral({ usuario }) {
  const ruta = usePathname();
  const [saliendo, setSaliendo] = useState(false);
  const [error, setError] = useState('');

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
      {[['/resumen','Resumen'],['/vehiculos','Vehículos'],['/viajes','Viajes']].map(([href,texto]) => <Link href={href} key={href} prefetch={false} className={ruta===href ? 'active' : ''} aria-current={ruta===href ? 'page' : undefined}>{texto}</Link>)}
    </nav>
    <div className="sidebar-bottom">
      <span className="avatar" aria-hidden="true">TY</span>
      <div>{usuario.nombre}<small>{usuario.rol}</small></div>
      <button className="salir" type="button" onClick={salir} disabled={saliendo}>{saliendo ? 'Saliendo…' : 'Salir'}</button>
      {error && <p className="text-danger" role="alert">{error}</p>}
    </div>
  </aside>;
}
