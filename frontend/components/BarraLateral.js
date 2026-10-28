'use client';

import { useState } from 'react';
import { enviarAccion } from '../lib/api';
import Marca from './Marca';

export default function BarraLateral({ usuario }) {
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
      <a href="/resumen" className="active" aria-current="page">Resumen</a>
      <button type="button" disabled title="Disponible en una próxima entrega">Vehículos</button>
      <button type="button" disabled title="Disponible en una próxima entrega">Viajes</button>
    </nav>
    <div className="sidebar-bottom">
      <span className="avatar" aria-hidden="true">TY</span>
      <div>{usuario.nombre}<small>{usuario.rol}</small></div>
      <button className="salir" type="button" onClick={salir} disabled={saliendo}>{saliendo ? 'Saliendo…' : 'Salir'}</button>
      {error && <p className="text-danger" role="alert">{error}</p>}
    </div>
  </aside>;
}
