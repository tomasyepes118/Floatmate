import { redirect } from 'next/navigation';
import { consultarServidor } from '../../lib/servidor';
import MarcoAplicacion from '../../components/MarcoAplicacion';
import ServicioNoDisponible from '../../components/ServicioNoDisponible';
import Recorrido from '../../components/Recorrido';

export const dynamic = 'force-dynamic';

export default async function PaginaRecorrido({ searchParams }) {
  const respuesta = await consultarServidor('sesion');
  if (respuesta.estado === 'sin-sesion') redirect('/login');
  if (respuesta.estado !== 'correcto') return <ServicioNoDisponible ruta="/recorrido" />;
  const { paso } = await searchParams;
  const { usuario } = respuesta.datos;
  return <MarcoAplicacion usuario={usuario}><Recorrido rol={usuario.rol} pasoInicial={paso} /></MarcoAplicacion>;
}
