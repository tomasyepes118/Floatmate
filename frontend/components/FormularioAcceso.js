'use client';

import { useState } from 'react';
import { enviarAccion } from '../lib/api';
import { inicioSesion } from '../lib/presentacion';

export default function FormularioAcceso({ servicioDisponible, mostrarCredenciales }) {
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
      const { usuario } = await enviarAccion('login', { usuario: campos.get('usuario').trim(), clave: campos.get('clave') });
      window.location.assign(inicioSesion(usuario.rol));
    } catch (fallo) {
      setError(fallo.message);
      setEnviando(false);
    }
  }

  return (
    <div className="login-card">
      <h1 id="login-titulo">Iniciar sesión</h1>
      <p className="login-intro">Ingresa para gestionar tu flota.</p>
      <form className="login-form" method="post" onSubmit={ingresar} aria-busy={enviando}>
        <div>
          <label htmlFor="usuario" className="form-label">Usuario</label>
          <input className="form-control" id="usuario" name="usuario" required maxLength={60} autoComplete="username" placeholder="Tu usuario" disabled={enviando} />
        </div>
        <div>
          <label htmlFor="clave" className="form-label">Contraseña</label>
          <div className="login-password">
            <input className="form-control" id="clave" name="clave" type={visible ? 'text' : 'password'} required maxLength={72} autoComplete="current-password" placeholder="Tu contraseña" disabled={enviando} />
            <button className="login-password-toggle" type="button" onClick={() => setVisible(!visible)} aria-label={visible ? 'Ocultar contraseña' : 'Mostrar contraseña'} disabled={enviando}>
              <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                <path d="M2 12s3.6-6 10-6 10 6 10 6-3.6 6-10 6-10-6-10-6Z" />
                <circle cx="12" cy="12" r="2.5" />
                {visible && <path d="m4 4 16 16" />}
              </svg>
            </button>
          </div>
        </div>
        <p className="login-error" role="alert">{error}</p>
        <button className="login-submit" type="submit" disabled={enviando}>
          {enviando ? 'Ingresando…' : 'Ingresar'}
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <path d="M4 12h15m-6-6 6 6-6 6" />
          </svg>
        </button>
      </form>
      <p className="visually-hidden" role="status">{enviando ? 'Ingresando…' : ''}</p>
      <aside className="demo-access" aria-labelledby="demo-titulo">
        <h2 id="demo-titulo">Acceso de demostración</h2>
        <p>Versión de demostración con datos de ejemplo.</p>
        {mostrarCredenciales && <p>Usuario: <code>admin</code> · Contraseña: <code>floatmate123</code></p>}
      </aside>
    </div>
  );
}
