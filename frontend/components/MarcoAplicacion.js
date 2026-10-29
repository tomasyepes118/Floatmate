import BarraLateral from './BarraLateral';

export default function MarcoAplicacion({ usuario, children }) {
  return <>
    <a href="#contenido" className="skip-link">Ir al contenido</a>
    <BarraLateral usuario={usuario} />
    <div className="workspace">
      <header className="topbar"><span>Centro de operaciones</span><span className="demo">Datos de demostración</span></header>
      <main id="contenido">{children}</main>
      <footer>FloatMate · Prototipo académico · Programación Web</footer>
    </div>
  </>;
}
