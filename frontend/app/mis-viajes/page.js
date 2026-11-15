import { redirect } from 'next/navigation';
import { consultarServidor } from '../../lib/servidor';
import MarcoAplicacion from '../../components/MarcoAplicacion';
import MisViajes from '../../components/MisViajes';
import ServicioNoDisponible from '../../components/ServicioNoDisponible';

export const dynamic = 'force-dynamic';

export default async function PaginaMisViajes() {
  const respuesta = await consultarServidor('mis-viajes');
  if (respuesta.estado === 'sin-sesion') redirect('/login');
  if (respuesta.estado === 'sin-permiso') redirect('/resumen');
  if (respuesta.estado !== 'correcto') return <ServicioNoDisponible ruta="/mis-viajes" />;
  const { usuario, viajes } = respuesta.datos;
  return <MarcoAplicacion usuario={usuario}><MisViajes viajes={viajes} /></MarcoAplicacion>;
}
