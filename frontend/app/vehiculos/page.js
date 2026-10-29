import { redirect } from 'next/navigation';
import { consultarServidor } from '../../lib/servidor';
import MarcoAplicacion from '../../components/MarcoAplicacion';
import ServicioNoDisponible from '../../components/ServicioNoDisponible';
import Vehiculos from '../../components/Vehiculos';

export const dynamic = 'force-dynamic';
export default async function PaginaVehiculos() {
  const respuesta = await consultarServidor('vehiculos');
  if (respuesta.estado==='sin-sesion') redirect('/login');
  if (respuesta.estado!=='correcto') return <ServicioNoDisponible ruta="/vehiculos" />;
  return <MarcoAplicacion usuario={respuesta.datos.usuario}><Vehiculos iniciales={respuesta.datos.vehiculos} /></MarcoAplicacion>;
}
