import { redirect } from 'next/navigation';
import { consultarServidor } from '../../lib/servidor';
import FormularioAcceso from '../../components/FormularioAcceso';

export const dynamic = 'force-dynamic';

export default async function Login() {
  const sesion = await consultarServidor('sesion');
  if (sesion.estado === 'correcto') redirect('/resumen');
  return <FormularioAcceso servicioDisponible={sesion.estado !== 'no-disponible'} />;
}
