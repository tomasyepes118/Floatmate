'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';

const pasos = [
  {
    id: 'resumen', titulo: 'Resumen de la flota', enlace: '/resumen',
    uso: 'Aquí ves cuántos buses hay, cuáles están disponibles, qué viajes están programados y qué actividad se ha registrado.',
    accion: 'Abre Resumen antes de empezar. Si la flota está vacía, verás los indicadores en cero. Vuelve después de crear tu primer viaje para comparar.',
  },
  {
    id: 'rutas', titulo: 'Rutas', enlace: '/catalogos?seccion=rutas', admin: true,
    uso: 'Una ruta reúne origen, destino, distancia y duración. FloatMate usa esos datos para validar el horario y el kilometraje del viaje.',
    accion: 'En Catálogos, pulsa Registrar ruta. Usa el código R-001, Medellín como origen, Rionegro como destino, 42 km y 60 minutos. Déjala activa.',
  },
  {
    id: 'conductores', titulo: 'Conductores', enlace: '/catalogos?seccion=conductores', admin: true,
    uso: 'El catálogo indica quién está disponible y hasta cuándo tiene licencia vigente. El conductor queda ocupado al iniciar un viaje.',
    accion: 'Pulsa Registrar conductor. Usa un nombre ficticio, una fecha de vencimiento posterior al viaje y el estado Disponible.',
  },
  {
    id: 'vehiculos', titulo: 'Vehículos', enlace: '/vehiculos',
    uso: 'El inventario guarda la placa, capacidad, kilometraje y próximo mantenimiento. Esos datos determinan qué buses pueden asignarse.',
    accion: 'Pulsa Registrar vehículo. Para el ejemplo usa ABC123, código BUS-001, Chevrolet NPR, modelo 2024, 30 pasajeros, 34.958 km actuales y mantenimiento a los 35.000 km. Déjalo Disponible.',
    operador: 'Consulta qué bus está disponible y revisa su capacidad, kilometraje y próximo mantenimiento.',
  },
  {
    id: 'viajes', titulo: 'Programación de viajes', enlace: '/viajes',
    uso: 'La programación asigna una ruta, un bus y un conductor. FloatMate comprueba la capacidad, la licencia, el kilometraje previsto y los cruces de horario.',
    accion: 'Pulsa Programar viaje. Selecciona la ruta, el vehículo y el conductor, elige una fecha y hora futuras e indica 20 pasajeros. Pulsa Revisar elegibilidad para ver si la asignación cumple y luego confirma.',
  },
  {
    id: 'despacho', titulo: 'Control de salida y llegada', enlace: '/viajes',
    uso: 'Un control aprobado habilita el inicio. Al cerrar el viaje, FloatMate actualiza el kilometraje, libera al conductor y revisa si el bus debe pasar a mantenimiento.',
    accion: 'En el viaje programado, registra un ticket ficticio y una medición de 0 mg/L para este ensayo. Inicia el viaje y luego registra 35000 como kilometraje de llegada. Con los datos del ejemplo, el bus pasa a Mantenimiento.',
  },
  {
    id: 'combustible', titulo: 'Combustible', enlace: '/registros?seccion=combustible',
    uso: 'Guarda cuánto combustible se cargó y cuánto costó. El resumen acumula los litros y el gasto.',
    accion: 'Pulsa Registrar abastecimiento, elige el bus e ingresa 20 litros a 10.000 COP por litro. Añade un detalle y comprueba que el total sea 200.000 COP.',
  },
  {
    id: 'mantenimientos', titulo: 'Mantenimientos', enlace: '/registros?seccion=mantenimientos',
    uso: 'Guarda el servicio realizado y actualiza el próximo mantenimiento. Si el bus estaba en Mantenimiento, un servicio válido lo devuelve a Disponible.',
    accion: 'Registra el servicio del bus del ejemplo a 35.000 km y fija el próximo a 40.000 km. Luego busca la misma placa en Vehículos.',
  },
  {
    id: 'incidentes', titulo: 'Incidentes', enlace: '/registros?seccion=incidentes',
    uso: 'Vincula una novedad a un viaje en curso o finalizado y al vehículo correspondiente.',
    accion: 'Pulsa Registrar incidente. Selecciona el viaje del ejemplo, elige su gravedad y escribe una novedad ficticia.',
  },
  {
    id: 'reportes', titulo: 'Resumen y reportes', enlace: '/resumen',
    uso: 'El resumen reúne los cambios de la operación. Cada módulo de Registros permite descargar su historial en CSV.',
    accion: 'Vuelve a Resumen y compara los indicadores con los del inicio. En Registros, selecciona un módulo y pulsa Descargar CSV.',
    consulta: 'Abre Resumen para ver la actividad. Usa Descargar combustible para guardar el reporte en CSV.',
  },
];

export default function Recorrido({ rol, pasoInicial }) {
  const disponibles = pasos.filter(paso => rol === 'Administrador'
    || (rol === 'Operador' ? !paso.admin : ['resumen', 'reportes'].includes(paso.id)));
  const [indice, setIndice] = useState(() => Math.max(0, disponibles.findIndex(paso => paso.id === pasoInicial)));
  useEffect(() => {
    if (pasoInicial) return;
    try {
      const guardado = sessionStorage.getItem('floatmate-paso-recorrido');
      const posicion = disponibles.findIndex(paso => paso.id === guardado);
      if (posicion >= 0) setIndice(posicion);
    } catch {
      // El recorrido funciona aunque el navegador bloquee el almacenamiento.
    }
  }, [rol, pasoInicial]); // Los pasos disponibles dependen únicamente del rol.

  function seleccionar(posicion) {
    setIndice(posicion);
    try { sessionStorage.setItem('floatmate-paso-recorrido', disponibles[posicion].id); } catch {}
  }
  const paso = disponibles[indice];
  const accion = (rol === 'Consulta' ? paso.consulta : rol === 'Operador' ? paso.operador : null) || paso.accion;

  return <>
    <div className="page-title">
      <h1>Recorrido guiado</h1>
      <p>Prepara una flota desde cero y sigue lo que cambia cuando programas, inicias y cierras un viaje.</p>
    </div>
    <div className="tour-layout">
      <nav className="panel tour-index" aria-label="Pasos del recorrido">
        <ol>
          {disponibles.map((item, posicion) => <li key={item.id}>
            <button type="button" aria-current={posicion === indice ? 'step' : undefined} onClick={() => seleccionar(posicion)}>
              <span>{posicion + 1}.</span> {item.titulo}
            </button>
          </li>)}
        </ol>
      </nav>
      <article className="panel tour-step" aria-labelledby="titulo-paso">
        <div aria-live="polite">
          <p className="tour-progress">Paso {indice + 1} de {disponibles.length}</p>
          <h2 id="titulo-paso">{paso.titulo}</h2>
          <p>{paso.uso}</p>
          <h3>Prueba este paso</h3>
          <p>{accion}</p>
        </div>
        <p><Link className="btn btn-primary" href={paso.enlace} prefetch={false} onClick={() => seleccionar(indice)}>Abrir sección</Link></p>
        <div className="tour-controls">
          <button type="button" className="btn btn-light" disabled={indice === 0} onClick={() => seleccionar(indice - 1)}>Anterior</button>
          {indice === disponibles.length - 1
            ? <button type="button" className="btn btn-light" onClick={() => seleccionar(0)}>Volver al inicio</button>
            : <button type="button" className="btn btn-light" onClick={() => seleccionar(indice + 1)}>Siguiente</button>}
        </div>
      </article>
    </div>
  </>;
}
