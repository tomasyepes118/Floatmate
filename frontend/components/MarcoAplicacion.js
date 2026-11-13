import BarraLateral from './BarraLateral';
import Link from 'next/link';

export default function MarcoAplicacion({ usuario, children }) {
  return <>
    <a href="#contenido" className="skip-link">Ir al contenido</a>
    <BarraLateral usuario={usuario} />
    <div className="workspace">
      <header className="topbar">
        <span>Centro de operaciones</span>
        <div className="topbar-actions">
          <Link href="/recorrido" prefetch={false}>Recorrido guiado</Link>
          <span className="demo">Datos de demostración</span>
        </div>
      </header>
      <main id="contenido">{children}</main>
      <footer>FloatMate · Prototipo académico · Programación Web</footer>
    </div>
  </>;
}
