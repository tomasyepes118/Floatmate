export default function ServicioNoDisponible({ ruta }) {
  return <main className="service-error"><h1>No pudimos cargar la información</h1><p>Revisa que Laravel esté iniciado e intenta de nuevo.</p><a href={ruta} className="btn btn-primary">Reintentar</a><a href="/login" className="btn btn-light">Volver al acceso</a></main>;
}
