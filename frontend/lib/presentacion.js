export const estadosVehiculo = { DISPONIBLE: 'Disponible', EN_RUTA: 'En viaje', MANTENIMIENTO: 'Mantenimiento', FUERA_SERVICIO: 'Fuera de servicio' };
export const estadosViaje = { PROGRAMADO: 'Programado', EN_CURSO: 'En curso', FINALIZADO: 'Finalizado', CANCELADO: 'Cancelado' };
export const tiposVehiculo = { BUS_URBANO: 'Bus urbano', BUS_INTERMUNICIPAL: 'Bus intermunicipal', MICROBUS: 'Microbús' };
export const inicioSesion = rol => rol === 'Conductor' ? '/mis-viajes' : '/resumen';
export const normalizar = valor => String(valor).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim();
export const numero = valor => Number(valor).toLocaleString('es-CO');
export const fecha = valor => new Date(valor.length === 16 ? `${valor}:00-05:00` : valor).toLocaleString('es-CO', { timeZone: 'America/Bogota', day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false });
export function claseEstado(estado) {
  if (['DISPONIBLE', 'ACTIVA'].includes(estado)) return 'available';
  if (estado === 'MANTENIMIENTO') return 'maintenance';
  if (estado === 'PROGRAMADO') return 'scheduled';
  if (['EN_RUTA', 'EN_CURSO', 'EN_VIAJE'].includes(estado)) return 'moving';
  return 'done';
}
