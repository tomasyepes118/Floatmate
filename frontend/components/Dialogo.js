'use client';

import { useEffect, useRef } from 'react';

export default function Dialogo({ abierto, titulo, cerrar, ocupado, children }) {
  const ref = useRef(null);
  useEffect(() => {
    const dialogo = ref.current;
    if (abierto && !dialogo.open) {
      dialogo.showModal();
      dialogo.querySelector('[data-close]')?.focus({ preventScroll: true });
      dialogo.scrollTop=0;
    }
    if (!abierto && dialogo.open) dialogo.close();
  }, [abierto]);
  return <dialog ref={ref} className="operation-dialog" aria-label={titulo} onCancel={evento => { evento.preventDefault(); if (!ocupado) cerrar(); }}>
    <div className="panel-heading"><h2>{titulo}</h2><button type="button" className="btn btn-light" data-close onClick={cerrar} disabled={ocupado}>Cerrar</button></div>
    {children}
  </dialog>;
}
