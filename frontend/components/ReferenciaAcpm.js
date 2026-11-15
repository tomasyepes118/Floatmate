'use client';

import { useEffect, useState } from 'react';
import { numero } from '../lib/presentacion';

const fechaCorta = new Intl.DateTimeFormat('es-CO', { dateStyle:'medium', timeZone:'UTC' });

export default function ReferenciaAcpm({ aplicar }) {
  const [precio, setPrecio] = useState(undefined);

  useEffect(() => {
    const solicitud = new AbortController();
    async function consultar() {
      try {
        const respuesta = await fetch('/api/registros/combustible/acpm', {
          headers: { Accept:'application/json' }, cache:'no-store', signal:solicitud.signal,
        });
        if (!respuesta.ok) throw new Error();
        const referencia = await respuesta.json();
        if (!solicitud.signal.aborted) setPrecio(referencia);
      } catch {
        if (!solicitud.signal.aborted) setPrecio(null);
      }
    }
    void consultar();
    return () => solicitud.abort();
  }, []);

  return <div className="referencia-acpm">
    <div role="status">
      {precio === undefined && <p>Consultando el precio de referencia del ACPM…</p>}
      {precio === null && <p>Referencia de ACPM no disponible. Puedes ingresar el precio de la factura.</p>}
      {precio && <>
        <p><strong>ACPM en {precio.ciudad} · $ {numero(precio.precio_galon)} COP por galón</strong></p>
        <p>Precio de referencia de la <a href={precio.fuente}>CREG</a> vigente desde <time dateTime={precio.vigente_desde}>{fechaCorta.format(new Date(precio.vigente_desde))}</time>.</p>
      </>}
    </div>
    {precio && <button type="button" className="btn btn-light btn-sm" onClick={evento => aplicar(evento.currentTarget.form.elements.precio_litro, precio.precio_litro)}>
      Usar $ {numero(precio.precio_litro)} COP por litro
    </button>}
  </div>;
}
