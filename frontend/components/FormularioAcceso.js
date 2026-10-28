'use client';

import { useState } from 'react';
import { enviarAccion } from '../lib/api';
import Marca from './Marca';

export default function FormularioAcceso({ servicioDisponible }) {
  const [visible, setVisible] = useState(false);
  const [enviando, setEnviando] = useState(false);
  const [error, setError] = useState(servicioDisponible ? '' : 'No pudimos conectar con el servicio. Revisa que Laravel esté iniciado.');

  async function ingresar(evento) {
    evento.preventDefault();
    if (enviando) return;
    setError('');
    setEnviando(true);
    const campos = new FormData(evento.currentTarget);
    try {
      await enviarAccion('login', { usuario: campos.get('usuario').trim(), clave: campos.get('clave') });
      window.location.assign('/resumen');
    } catch (fallo) {
      setError(fallo.message);
      setEnviando(false);
    }
  }

  return (
    <main className="login-layout">
      <section className="login-brand" aria-label="FloatMate"><Marca /></section>
      <section className="login-form-area">
        <form className="login-card" onSubmit={ingresar} aria-busy={enviando}>
          <h1>Iniciar sesión</h1>
          <p className="text-secondary mb-4">Ingresa para consultar tu flota.</p>
          <label htmlFor="usuario" className="form-label">Usuario</label>
          <input className="form-control mb-3" id="usuario" name="usuario" required maxLength={60} autoComplete="username" placeholder="Tu usuario" disabled={enviando} />
          <label htmlFor="clave" className="form-label">Contraseña</label>
          <div className="input-group mb-4">
            <input className="form-control" id="clave" name="clave" type={visible ? 'text' : 'password'} required maxLength={128} autoComplete="current-password" placeholder="Tu contraseña" disabled={enviando} />
            <button className="btn btn-outline-secondary" type="button" onClick={() => setVisible(!visible)} aria-label={visible ? 'Ocultar contraseña' : 'Mostrar contraseña'} aria-pressed={visible} disabled={enviando}>{visible ? 'Ocultar' : 'Ver'}</button>
          </div>
          <p className="text-danger login-error" role="alert">{error}</p>
          <button className="btn btn-primary w-100" type="submit" disabled={enviando}>{enviando ? 'Ingresando…' : 'Ingresar'}</button>
          <div className="demo-access">
            <strong>Acceso de demostración</strong>
            <p>Usuario: <code>admin</code> · Contraseña: <code>floatmate123</code></p>
            <small>Versión de demostración con datos de ejemplo.</small>
          </div>
        </form>
      </section>
    </main>
  );
}
