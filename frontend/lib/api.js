export class ErrorApi extends Error {
  constructor(mensaje, estado) {
    super(mensaje);
    this.estado = estado;
  }
}

export async function enviarAccion(ruta, datos = {}) {
  let csrf;
  try {
    const respuesta = await fetch('/api/csrf', { cache: 'no-store', credentials: 'same-origin' });
    if (!respuesta.ok) throw new Error();
    csrf = (await respuesta.json()).token;
  } catch {
    throw new ErrorApi('No pudimos conectar con el servicio. Intenta de nuevo.', 503);
  }

  let respuesta;
  try {
    respuesta = await fetch(`/api/${ruta}`, {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-TOKEN': csrf },
      body: JSON.stringify(datos),
    });
  } catch {
    throw new ErrorApi('No pudimos conectar con el servicio. Intenta de nuevo.', 503);
  }

  const contenido = await respuesta.json().catch(() => ({}));
  if (!respuesta.ok) {
    const mensaje = respuesta.status === 419
      ? 'La sesión venció. Intenta ingresar de nuevo.'
      : respuesta.status === 429
        ? 'Has realizado varios intentos. Espera un minuto y vuelve a intentar.'
        : contenido.message || 'No pudimos completar la solicitud. Intenta de nuevo.';
    throw new ErrorApi(mensaje, respuesta.status);
  }
  return contenido;
}
