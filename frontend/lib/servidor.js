import { cookies } from 'next/headers';

/** Las cookies de sesión se verifican en Laravel, también al recargar una página. */
export async function consultarServidor(ruta) {
  const cookieStore = await cookies();
  try {
    const respuesta = await fetch(`${process.env.LARAVEL_URL || 'http://127.0.0.1:8000'}/api/${ruta}`, {
      headers: { Accept: 'application/json', Cookie: cookieStore.toString() },
      cache: 'no-store',
      signal: AbortSignal.timeout(5000),
    });
    if (respuesta.status === 401) return { estado: 'sin-sesion' };
    if (!respuesta.ok) return { estado: 'no-disponible' };
    return { estado: 'correcto', datos: await respuesta.json() };
  } catch {
    return { estado: 'no-disponible' };
  }
}
