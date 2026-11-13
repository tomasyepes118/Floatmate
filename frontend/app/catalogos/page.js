import { redirect } from 'next/navigation';
import { consultarServidor } from '../../lib/servidor';
import MarcoAplicacion from '../../components/MarcoAplicacion';
import ServicioNoDisponible from '../../components/ServicioNoDisponible';
import GestionOperativa from '../../components/GestionOperativa';

export const dynamic = 'force-dynamic';
export default async function PaginaCatalogos({ searchParams }) {
  const respuesta = await consultarServidor('catalogos');
  if (respuesta.estado === 'sin-sesion') redirect('/login');
  if (respuesta.estado === 'sin-permiso') redirect('/resumen');
  if (respuesta.estado !== 'correcto') return <ServicioNoDisponible ruta="/catalogos" />;
  const { seccion } = await searchParams;
  return <MarcoAplicacion usuario={respuesta.datos.usuario}><GestionOperativa key={String(seccion)} seccion="catalogos" tipoInicial={seccion} datos={respuesta.datos} /></MarcoAplicacion>;
}
