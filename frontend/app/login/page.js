import { redirect } from 'next/navigation';
import localFont from 'next/font/local';
import { consultarServidor } from '../../lib/servidor';
import FormularioAcceso from '../../components/FormularioAcceso';
import Marca from '../../components/Marca';

export const dynamic = 'force-dynamic';

const inter = localFont({
  src: './fonts/InterVariable.woff2',
  weight: '400 800',
  display: 'swap',
  fallback: ['system-ui', 'sans-serif'],
});

export default async function Login() {
  const sesion = await consultarServidor('sesion');
  if (sesion.estado === 'correcto') redirect('/resumen');
  return (
    <main className={`login-layout ${inter.className}`}>
      <section className="login-hero" aria-label="FloatMate">
        <picture className="login-photo">
          <source media="(width < 880px)" srcSet="/images/login/floatmate-bus-mobile.webp" />
          <img src="/images/login/floatmate-bus-desktop.webp" alt="" fetchPriority="high" width={1122} height={1402} />
        </picture>
        <div className="login-hero-content">
          <Marca />
          <p className="login-slogan">Tu flota,<br /><span>en movimiento.</span></p>
          <p className="login-hero-description">Gestiona salidas, recorridos y buses desde un solo lugar.</p>
        </div>
        <div className="login-route">
          <div className="login-route-heading"><span>Recorrido · R12</span><span className="login-route-tag">Ejemplo</span></div>
          <div className="login-route-track" aria-hidden="true"><span /><span /><span /></div>
          <div className="login-route-stops"><span>Terminal</span><span>Estación final</span></div>
        </div>
      </section>
      <section className="login-form-area" aria-labelledby="login-titulo">
        <FormularioAcceso servicioDisponible={sesion.estado !== 'no-disponible'} mostrarCredenciales={process.env.FLOATMATE_HOSTED !== '1'} />
      </section>
    </main>
  );
}
