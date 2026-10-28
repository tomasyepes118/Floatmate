import './bootstrap.min.css';
import './globals.css';

export const metadata = {
  title: 'FloatMate',
  description: 'Acceso y resumen de la flota de FloatMate.',
};

export default function RootLayout({ children }) {
  return <html lang="es"><body>{children}</body></html>;
}
