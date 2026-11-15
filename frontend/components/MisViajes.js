'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { enviarAccion } from '../lib/api';
import { estadosViaje, fecha, numero } from '../lib/presentacion';
import Campo from './Campo';
import Dialogo from './Dialogo';
import { BotonOperacion, EstadoOperacion, TituloPagina, VacioOperacion } from './InterfazOperacion';

const acciones = {
  confirmar: { titulo:'Confirmar asignación', metodo:'POST' },
  llegada: { titulo:'Registrar llegada', metodo:'PATCH' },
  incidentes: { titulo:'Reportar novedad', metodo:'POST' },
};

export default function MisViajes({ viajes }) {
  const router = useRouter();
  const [dialogo, setDialogo] = useState(null);
  const [ocupado, setOcupado] = useState(false);
  const [actualizando, actualizar] = useTransition();
  const [mensaje, setMensaje] = useState('');
  const [error, setError] = useState('');
  const [errores, setErrores] = useState({});
  const bloqueado = ocupado || actualizando;
  const enCurso = viajes.filter(viaje => viaje.estado === 'EN_CURSO');
  const programados = viajes.filter(viaje => viaje.estado === 'PROGRAMADO').reverse();
  const historial = viajes.filter(viaje => ['FINALIZADO', 'CANCELADO'].includes(viaje.estado));

  function abrir(accion, viaje) {
    setDialogo({ accion, viaje });
    setMensaje('');
    setError('');
    setErrores({});
  }

  async function guardar(evento) {
    evento.preventDefault();
    if (bloqueado) return;
    const { accion, viaje } = dialogo;
    const datos = Object.fromEntries(new FormData(evento.currentTarget));
    setOcupado(true);
    setError('');
    setErrores({});
    try {
      const respuesta = await enviarAccion(`mis-viajes/${viaje.id}/${accion}`, datos, acciones[accion].metodo);
      setDialogo(null);
      setMensaje(accion === 'incidentes' ? 'Novedad registrada.' : respuesta.message);
      actualizar(() => router.refresh());
    } catch (fallo) {
      setError(fallo.message);
      setErrores(fallo.errores || {});
      actualizar(() => router.refresh());
    } finally {
      setOcupado(false);
    }
  }

  return <>
    <TituloPagina titulo="Mis viajes" descripcion="Consulta tus asignaciones, confirma que las recibiste y registra la llegada o una novedad." />
    {mensaje && <p className="operation-success" role="status">{mensaje}</p>}
    {viajes.length ? <div className="viajes-conductor">
      {[...enCurso, ...programados, ...historial].map(viaje => <article className="panel viaje-conductor" key={viaje.id}>
        <div className="viaje-conductor-encabezado">
          <div><p className="operation-hint">Viaje V-{viaje.id}</p><h2>{viaje.origen} → {viaje.destino}</h2></div>
          <EstadoOperacion estado={viaje.estado}>{estadosViaje[viaje.estado]}</EstadoOperacion>
        </div>
        <dl>
          <div><dt>Salida prevista</dt><dd>{fecha(viaje.salida)}</dd></div>
          <div><dt>Placa</dt><dd>{viaje.placa}</dd></div>
          {viaje.llegada_real && <div><dt>Llegada</dt><dd>{fecha(viaje.llegada_real)}</dd></div>}
          {viaje.kilometraje_llegada !== null && <div><dt>Kilometraje de llegada</dt><dd>{numero(viaje.kilometraje_llegada)} km</dd></div>}
        </dl>
        {viaje.observaciones && <p className="viaje-conductor-nota">{viaje.observaciones}</p>}
        {viaje.confirmado_en && <p className="viaje-conductor-confirmado">Asignación confirmada</p>}
        <div className="row-actions">
          {viaje.estado === 'PROGRAMADO' && !viaje.confirmado_en && <BotonOperacion principal onClick={() => abrir('confirmar', viaje)} disabled={bloqueado}>Confirmar asignación</BotonOperacion>}
          {viaje.estado === 'EN_CURSO' && <BotonOperacion principal onClick={() => abrir('llegada', viaje)} disabled={bloqueado}>Registrar llegada</BotonOperacion>}
          {['EN_CURSO', 'FINALIZADO'].includes(viaje.estado) && <BotonOperacion onClick={() => abrir('incidentes', viaje)} disabled={bloqueado}>Reportar novedad</BotonOperacion>}
        </div>
      </article>)}
    </div> : <div className="panel"><VacioOperacion icono="viajes">Todavía no tienes viajes asignados.</VacioOperacion></div>}

    <Dialogo abierto={!!dialogo} titulo={dialogo ? acciones[dialogo.accion].titulo : 'Viaje'} cerrar={() => setDialogo(null)} ocupado={ocupado}>
      {dialogo && <form onSubmit={guardar} aria-busy={ocupado}>
        <fieldset disabled={bloqueado}>
          <p className="route-detail">V-{dialogo.viaje.id} · {dialogo.viaje.origen} → {dialogo.viaje.destino} · {dialogo.viaje.placa}</p>
          {dialogo.accion === 'confirmar' && <p>Confirma que recibiste esta asignación.</p>}
          {dialogo.accion === 'llegada' && <Campo nombre="kilometraje_llegada" etiqueta="Kilometraje de llegada" errores={errores}>
            <input id="kilometraje_llegada" name="kilometraje_llegada" className="form-control" type="number" inputMode="decimal" min={dialogo.viaje.kilometraje_minimo} max={9999999} step="0.01" required />
          </Campo>}
          {dialogo.accion === 'incidentes' && <>
            <Campo nombre="gravedad" etiqueta="Gravedad" errores={errores}>
              <select id="gravedad" name="gravedad" className="form-select" required defaultValue="">
                <option value="">Selecciona</option><option value="BAJA">Baja</option><option value="MEDIA">Media</option><option value="ALTA">Alta</option>
              </select>
            </Campo>
            <Campo nombre="detalle" etiqueta="Detalle de la novedad" errores={errores}>
              <textarea id="detalle" name="detalle" className="form-control" rows={4} maxLength={500} required />
            </Campo>
          </>}
          {error && <p className="form-error" role="alert">{error}</p>}
          <BotonOperacion principal type="submit">{ocupado ? 'Guardando…' : dialogo.accion === 'confirmar' ? 'Confirmar' : dialogo.accion === 'llegada' ? 'Guardar llegada' : 'Enviar novedad'}</BotonOperacion>
        </fieldset>
      </form>}
    </Dialogo>
  </>;
}
