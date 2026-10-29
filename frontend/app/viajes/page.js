import { redirect } from 'next/navigation';
import { consultarServidor } from '../../lib/servidor';
import MarcoAplicacion from '../../components/MarcoAplicacion';
import ServicioNoDisponible from '../../components/ServicioNoDisponible';
import Viajes from '../../components/Viajes';

export const dynamic = 'force-dynamic';
export default async function PaginaViajes() {
  const respuesta = await consultarServidor('viajes');
  if (respuesta.estado==='sin-sesion') redirect('/login');
  if (respuesta.estado!=='correcto') return <ServicioNoDisponible ruta="/viajes" />;
  return <MarcoAplicacion usuario={respuesta.datos.usuario}><Viajes iniciales={respuesta.datos} /></MarcoAplicacion>;
}
