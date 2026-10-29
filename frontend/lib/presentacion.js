export const estadosVehiculo = { DISPONIBLE: 'Disponible', EN_RUTA: 'En viaje', MANTENIMIENTO: 'Mantenimiento', FUERA_SERVICIO: 'Fuera de servicio' };
export const estadosViaje = { PROGRAMADO: 'Programado', EN_CURSO: 'En curso', FINALIZADO: 'Finalizado', CANCELADO: 'Cancelado' };
export const tiposVehiculo = { BUS_URBANO: 'Bus urbano', BUS_INTERMUNICIPAL: 'Bus intermunicipal', MICROBUS: 'Microbús' };
export const normalizar = valor => String(valor).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim();
export const numero = valor => Number(valor).toLocaleString('es-CO');
export const fecha = valor => new Date(`${valor}:00-05:00`).toLocaleString('es-CO', { timeZone: 'America/Bogota', day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false });
export function claseEstado(estado) {
  return estado==='DISPONIBLE' ? 'available' : estado==='MANTENIMIENTO' ? 'maintenance' : ['EN_RUTA','EN_CURSO','PROGRAMADO'].includes(estado) ? 'moving' : 'done';
}
