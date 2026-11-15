import { redirect } from 'next/navigation';
import { consultarServidor } from '../../lib/servidor';
import AdministrarAccesos from '../../components/AdministrarAccesos';
import MarcoAplicacion from '../../components/MarcoAplicacion';
import ServicioNoDisponible from '../../components/ServicioNoDisponible';

export const dynamic = 'force-dynamic';

export default async function PaginaAccesos() {
  const respuesta = await consultarServidor('accesos');
  if (respuesta.estado === 'sin-sesion') redirect('/login');
  if (respuesta.estado === 'sin-permiso') redirect('/resumen');
  if (respuesta.estado !== 'correcto') return <ServicioNoDisponible ruta="/accesos" />;
  const { usuario, accesos, conductores } = respuesta.datos;
  return <MarcoAplicacion usuario={usuario}><AdministrarAccesos accesos={accesos} conductores={conductores} /></MarcoAplicacion>;
}
