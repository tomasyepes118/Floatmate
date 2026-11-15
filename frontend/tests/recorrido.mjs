import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const origen = process.env.FLOATMATE_URL || 'http://127.0.0.1:3000';
const capturas = resolve(process.env.FLOATMATE_CAPTURAS || 'test-results/avance-4');
await mkdir(capturas, { recursive: true });
const navegador = await chromium.launch({ headless: true, ...(process.env.PLAYWRIGHT_CHANNEL ? { channel: process.env.PLAYWRIGHT_CHANNEL } : {}) });
const resultados = [], errores = [];
const comprobar = (nombre, valor) => { assert.ok(valor, nombre); resultados.push(nombre); };
const foto = (pagina, nombre) => /error|registrar|programar|registro|programacion/.test(nombre) ? pagina.getByRole('dialog').screenshot({ path: resolve(capturas, nombre) }) : pagina.screenshot({ path: resolve(capturas, nombre), fullPage: false });

async function ingresar(pagina) {
  await pagina.getByLabel('Usuario', { exact: true }).fill('admin');
  const clave = pagina.getByLabel('Contraseña', { exact: true });
  await clave.fill('floatmate123');
  await clave.press('Enter');
  await pagina.waitForURL('**/resumen');
  await pagina.getByRole('heading', { name: 'Resumen de la flota' }).waitFor();
}

async function enviar(contexto, ruta, datos) {
  const csrf = await contexto.request.get(`${origen}/api/csrf`);
  const { token } = await csrf.json();
  return contexto.request.post(`${origen}/api/${ruta}`, { data: datos, headers: { 'X-CSRF-TOKEN': token, Accept: 'application/json' } });
}

try {
  for (const width of [320, 390, 768, 1440]) {
    const vista = await navegador.newPage({ viewport: { width, height: width === 320 ? 740 : 900 } });
    const fotos = [];
    vista.on('request', peticion => {
      if (peticion.url().includes('/images/login/floatmate-bus-')) fotos.push(peticion.url());
    });
    await vista.goto(`${origen}/login`, { waitUntil: 'load' });
    const variante = width < 880 ? 'mobile' : 'desktop';
    comprobar(`El login a ${width} px carga únicamente la foto ${variante}`,
      fotos.length === 1 && fotos[0].endsWith(`floatmate-bus-${variante}.webp`) &&
      await vista.locator('.login-photo img').evaluate(imagen => imagen.naturalWidth > 0));
    comprobar(`El login a ${width} px cabe sin desbordamiento horizontal`,
      await vista.evaluate(() => document.documentElement.scrollWidth === document.documentElement.clientWidth));
    comprobar(`El ejemplo de recorrido se muestra según el ancho de ${width} px`,
      await vista.getByText('Recorrido · R12').isVisible() === (variante === 'desktop'));
    await vista.screenshot({ path: resolve(capturas, `login-${width}.png`), fullPage: true });
    await vista.close();
  }

  const contexto = await navegador.newContext({ viewport: { width: 1440, height: 850 }, deviceScaleFactor: 1 });
  const pagina = await contexto.newPage();
  pagina.on('pageerror', error => errores.push(error.message));
  for (const ruta of ['resumen','vehiculos','viajes']) {
    await pagina.goto(`${origen}/${ruta}`);
    await pagina.waitForURL('**/login');
    comprobar(`${ruta} exige una sesión`, pagina.url().endsWith('/login'));
  }
  const usuarioLogin = pagina.getByLabel('Usuario', { exact: true });
  const claveLogin = pagina.getByLabel('Contraseña', { exact: true });
  await pagina.keyboard.press('Tab');
  comprobar('El primer campo del login recibe foco visible con el teclado',
    await usuarioLogin.evaluate(campo => document.activeElement === campo && getComputedStyle(campo).outlineStyle === 'solid'));
  const demo = pagina.getByRole('complementary', { name: 'Acceso de demostración' });
  comprobar('El bloque de demostración sigue siendo informativo y muestra el acceso local',
    await demo.getByText('Versión de demostración con datos de ejemplo.').isVisible() &&
    await demo.getByText('floatmate123').isVisible() && await demo.getByRole('link').count() === 0 &&
    await demo.getByRole('button').count() === 0);
  await usuarioLogin.fill('admin');
  await claveLogin.fill('incorrecta');
  await pagina.getByRole('button', { name: 'Mostrar contraseña' }).click();
  comprobar('El botón muestra la contraseña y cambia de nombre accesible',
    await claveLogin.getAttribute('type') === 'text' && await pagina.getByRole('button', { name: 'Ocultar contraseña' }).isVisible());
  await pagina.getByRole('button', { name: 'Ocultar contraseña' }).click();
  comprobar('El botón vuelve a ocultar la contraseña sin borrar el valor',
    await claveLogin.getAttribute('type') === 'password' && await claveLogin.inputValue() === 'incorrecta');
  await pagina.route('**/api/login', async peticion => {
    await pagina.getByRole('button', { name: 'Ingresando…' }).waitFor();
    comprobar('El login anuncia la carga y bloquea envíos repetidos',
      await pagina.getByRole('status').textContent() === 'Ingresando…' && await pagina.getByRole('button', { name: 'Ingresando…' }).isDisabled());
    await peticion.continue();
  }, { times: 1 });
  await pagina.getByRole('button', { name: 'Ingresar', exact: true }).click();
  await pagina.getByText('Usuario o contraseña incorrectos. Intenta de nuevo.', { exact: true }).waitFor();
  comprobar('El login rechaza una contraseña incorrecta', pagina.url().endsWith('/login'));
  await ingresar(pagina);
  const catalogos = await (await contexto.request.get(`${origen}/api/viajes`)).json();
  assert.equal(catalogos.pruebas_navegador, true, 'Inicia Laravel con DEMO_E2E=true y DEMO_DATA_PATH apuntando a una carpeta de pruebas antes de ejecutar este recorrido.');
  const baseResumen = await (await contexto.request.get(`${origen}/api/resumen`)).json();
  comprobar('Login y resumen funcionan', await pagina.locator('.metric').count()===4);
  const proximaSalida = pagina.getByRole('region', { name:'Próxima salida' });
  const [primero] = baseResumen.viajes;
  comprobar('El resumen muestra la ruta, fecha, hora y placa de la próxima salida',
    await proximaSalida.getByText(primero.ruta.replace(' - ', ' → '), { exact:true }).isVisible() &&
    await proximaSalida.locator('time').getAttribute('datetime') === primero.salida_iso &&
    await proximaSalida.getByText(primero.placa, { exact:true }).isVisible());
  const estadosResumen = pagina.getByRole('region', { name:'Estado de los vehículos' });
  for (const estado of baseResumen.estados) {
    const fila = estadosResumen.getByRole('listitem').filter({ hasText:estado.nombre });
    const ancho = await fila.locator('.resumen-estado-barra span').evaluate(barra => parseFloat(barra.style.width));
    comprobar(`El estado ${estado.nombre} muestra el total y su proporción`,
      await fila.getByText(String(estado.cantidad), { exact:true }).isVisible() &&
      Math.abs(ancho - estado.cantidad / baseResumen.indicadores[0].valor * 100) < 0.01);
  }
  await pagina.screenshot({ path:resolve(capturas, 'resumen-escritorio.png'), fullPage:true });
  for (const width of [320, 390, 768]) {
    await pagina.setViewportSize({ width, height:844 });
    const viaje = pagina.locator('.resumen-viajes tbody tr').first();
    comprobar(`El resumen a ${width} px muestra los datos del viaje sin desbordamiento`,
      await pagina.evaluate(() => document.documentElement.scrollWidth === document.documentElement.clientWidth) &&
      await viaje.getByText(primero.ruta.replace(' - ', ' → '), { exact:true }).isVisible() &&
      await viaje.getByText(primero.conductor, { exact:true }).isVisible() &&
      await viaje.getByText(primero.salida, { exact:true }).isVisible() &&
      await viaje.getByText(primero.placa, { exact:true }).isVisible() &&
      await viaje.getByText(primero.estado, { exact:true }).isVisible());
    if (width === 390) await pagina.screenshot({ path:resolve(capturas, 'resumen-movil.png'), fullPage:true });
  }
  await pagina.setViewportSize({ width:1440, height:850 });
  await pagina.getByRole('link', { name: 'Vehículos', exact: true }).click();
  await pagina.waitForURL('**/vehiculos');
  await pagina.getByRole('heading', { name: 'Inventario de vehículos' }).waitFor();
  comprobar('La consulta muestra los vehículos guardados', await pagina.locator('tbody tr').count()===catalogos.vehiculos.length);
  await foto(pagina, '01-vehiculos-pc.png');
  await pagina.getByLabel('Filtrar vehículos por estado').selectOption('MANTENIMIENTO');
  comprobar('El filtro de estado de vehículos funciona', await pagina.locator('tbody tr').count()===catalogos.vehiculos.filter(v=>v.estado==='MANTENIMIENTO').length);
  await pagina.getByLabel('Filtrar vehículos por estado').selectOption('');
  await pagina.getByLabel('Buscar vehículo', { exact: true }).fill('no-existe');
  comprobar('La búsqueda vacía tiene un mensaje claro', await pagina.getByText('No hay vehículos que coincidan con la búsqueda.').isVisible());
  await pagina.getByLabel('Buscar vehículo', { exact: true }).fill('');
  await pagina.getByRole('button', { name: 'Registrar vehículo', exact: true }).click();
  await pagina.getByRole('button', { name: 'Cerrar', exact: true }).click();
  comprobar('Cerrar el formulario no crea registros', await pagina.locator('tbody tr').count()===catalogos.vehiculos.length);
  await pagina.getByRole('button', { name: 'Registrar vehículo', exact: true }).click();
  let n=200;
  while(catalogos.vehiculos.some(v=>v.placa===`PRU${n}`||v.codigo===`AVANCE3-${n}`)) n++;
  const placa=`PRU${n}`, codigo=`AVANCE3-${n}`;
  for (const [campo,valor] of [['Placa','TPQ482'],['Código interno',codigo],['Marca y línea','Chevrolet NPR'],['Modelo','2026'],['Capacidad de pasajeros','30'],['Kilometraje actual','1000'],['Próximo mantenimiento en km','10000']]) {
    await pagina.getByLabel(campo,{exact:true}).fill(valor);
  }
  await pagina.getByRole('button',{name:'Guardar vehículo',exact:true}).click();
  await pagina.locator('.form-error').filter({hasText:'La placa ya está registrada.'}).waitFor();
  comprobar('La placa repetida se rechaza desde Laravel', (await contexto.request.get(`${origen}/api/vehiculos`).then(r=>r.json())).vehiculos.length===catalogos.vehiculos.length);
  await foto(pagina,'02-error-placa-pc.png');
  await pagina.getByLabel('Placa',{exact:true}).fill(placa);
  comprobar('Corregir la placa retira el error anterior', (await pagina.locator('.form-error').textContent()).trim()==='');
  await foto(pagina,'03-registrar-vehiculo-pc.png');
  await pagina.getByRole('button',{name:'Guardar vehículo',exact:true}).click();
  await pagina.getByText('Vehículo registrado correctamente.',{exact:true}).waitFor();
  await pagina.locator('tbody tr').filter({hasText:placa}).waitFor();
  comprobar('Se registra el vehículo y aparece en la tabla', await pagina.locator('tbody tr').filter({hasText:placa}).count()===1);
  await pagina.reload();
  await pagina.getByRole('heading',{name:'Inventario de vehículos'}).waitFor();
  comprobar('El registro se conserva al recargar', await pagina.locator('tbody tr').filter({hasText:placa}).count()===1);
  await pagina.getByRole('link',{name:'Resumen',exact:true}).click();
  await pagina.getByRole('heading',{name:'Resumen de la flota'}).waitFor();
  comprobar('El resumen refleja el vehículo nuevo', (await pagina.locator('.metric strong').allTextContents())[0]===String(baseResumen.indicadores[0].valor+1));
  await pagina.getByRole('link',{name:'Viajes',exact:true}).click();
  await pagina.getByRole('heading',{name:'Programación de viajes'}).waitFor();
  comprobar('La consulta muestra los viajes guardados', await pagina.locator('tbody tr').count()===catalogos.viajes.length);
  await foto(pagina,'04-viajes-pc.png');
  await pagina.getByLabel('Filtrar viajes por estado').selectOption('FINALIZADO');
  comprobar('El filtro de estado de viajes funciona', await pagina.locator('tbody tr').count()===catalogos.viajes.filter(v=>v.estado==='FINALIZADO').length);
  await pagina.getByLabel('Filtrar viajes por estado').selectOption('');
  await pagina.getByLabel('Buscar viaje',{exact:true}).fill('ningun-viaje');
  comprobar('La búsqueda sin viajes muestra un mensaje', await pagina.getByText('No hay viajes que coincidan con la búsqueda.').isVisible());
  await pagina.getByLabel('Buscar viaje',{exact:true}).fill('');
  await pagina.getByRole('button',{name:'Programar viaje',exact:true}).click();
  const data = await (await contexto.request.get(`${origen}/api/viajes`)).json();
  const nuevo = data.vehiculos.find(v=>v.placa===placa);
  const seleccion = await pagina.locator('#vehiculo_id option').allTextContents();
  comprobar('El formulario solo ofrece buses disponibles', seleccion.some(x=>x.includes(placa)) && !seleccion.some(x=>x.includes('WLM305')||x.includes('SXY916')));
  let dia = new Date(Date.now()+3*86400000).toLocaleDateString('en-CA',{timeZone:'America/Bogota'});
  let salida=`${dia}T10:00`;
  while(data.viajes.some(v=>v.conductor_id===4&&['PROGRAMADO','EN_CURSO'].includes(v.estado)&&Math.abs(new Date(`${v.salida}:00-05:00`)-new Date(`${salida}:00-05:00`))<7200000)) {
    const siguiente=new Date(new Date(`${salida}:00-05:00`).getTime()+7200000);
    const partes=new Intl.DateTimeFormat('sv-SE',{timeZone:'America/Bogota',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hour12:false}).format(siguiente);
    salida=partes.replace(' ','T');
  }
  await pagina.getByLabel('Ruta activa',{exact:true}).selectOption('1');
  await pagina.getByLabel('Vehículo disponible',{exact:true}).selectOption(String(nuevo.id));
  await pagina.getByLabel('Conductor disponible',{exact:true}).selectOption('4');
  await pagina.getByLabel('Fecha y hora de salida',{exact:true}).fill('2020-01-01T10:00');
  await pagina.getByLabel('Pasajeros',{exact:true}).fill('13');
  await pagina.getByLabel('Observaciones',{exact:true}).fill('Programación de demostración del tercer avance.');
  await pagina.getByRole('button',{name:'Confirmar programación',exact:true}).click();
  await pagina.locator('.form-error').filter({hasText:'Selecciona una fecha y hora futuras.'}).waitFor();
  comprobar('La fecha pasada se rechaza con un mensaje', await pagina.getByRole('dialog').isVisible());
  await pagina.getByLabel('Fecha y hora de salida',{exact:true}).fill(salida);
  await pagina.getByLabel('Pasajeros',{exact:true}).fill('31');
  await pagina.getByRole('button',{name:'Revisar elegibilidad',exact:true}).click();
  await pagina.getByText('Los pasajeros superan la capacidad del vehículo.',{exact:true}).waitFor();
  await pagina.getByRole('button',{name:'Usar KPT641',exact:true}).click();
  comprobar('Elegibilidad explica el rechazo y permite elegir una alternativa',
    await pagina.getByLabel('Vehículo disponible',{exact:true}).inputValue()==='5');
  await pagina.getByRole('button',{name:'Revisar elegibilidad',exact:true}).click();
  await pagina.getByText('La asignación cumple las condiciones de programación',{exact:true}).waitFor();
  await pagina.getByLabel('Vehículo disponible',{exact:true}).selectOption(String(nuevo.id));
  await pagina.getByLabel('Pasajeros',{exact:true}).fill('13');
  comprobar('Cambiar la asignación invalida la revisión anterior',
    await pagina.getByText('La asignación cumple las condiciones de programación',{exact:true}).count()===0);
  await foto(pagina,'05-programar-viaje-pc.png');
  const payload={ruta_id:1,vehiculo_id:nuevo.id,conductor_id:4,salida,pasajeros:13,observaciones:'Prueba de navegador.'};
  const exceso=await enviar(contexto,'viajes',{...payload,pasajeros:31});
  comprobar('El servidor rechaza el exceso de capacidad', exceso.status()===422 && (await exceso.json()).errors.pasajeros.length>0);
  await pagina.getByRole('button',{name:'Confirmar programación',exact:true}).click();
  await pagina.getByText('Viaje programado correctamente.',{exact:true}).waitFor();
  await pagina.locator('tbody tr').filter({hasText:placa}).waitFor();
  comprobar('El viaje creado aparece en la programación', await pagina.locator('tbody tr').filter({hasText:placa}).count()===1);
  const cruce=await enviar(contexto,'viajes',{...payload,conductor_id:3});
  comprobar('El servidor rechaza cruces del vehículo', cruce.status()===422 && (await cruce.json()).errors.salida.length>0);
  const sinCsrf=await contexto.request.post(`${origen}/api/vehiculos`,{data:{}});
  comprobar('Las altas exigen protección CSRF',sinCsrf.status()===419);
  await pagina.getByRole('link',{name:'Resumen',exact:true}).click();
  await pagina.getByRole('heading',{name:'Resumen de la flota'}).waitFor();
  comprobar('El panel refleja el viaje nuevo', (await pagina.locator('.metric strong').allTextContents())[2]===String(baseResumen.indicadores[2].valor+1));
  await foto(pagina,'06-resumen-actualizado-pc.png');
  await pagina.getByRole('button',{name:'Salir',exact:true}).click();
  await pagina.waitForURL('**/login');
  await pagina.goto(`${origen}/viajes`);
  await pagina.waitForURL('**/login');
  comprobar('Salir protege nuevamente la programación',pagina.url().endsWith('/login'));
  await ingresar(pagina);
  const persistido=await(await contexto.request.get(`${origen}/api/viajes`)).json();
  comprobar('El archivo conserva los registros después de salir',persistido.vehiculos.some(v=>v.placa===placa)&&persistido.viajes.some(v=>v.vehiculo_id===nuevo.id));

  await pagina.getByRole('link', { name: 'Viajes', exact: true }).click();
  const viajeNuevo = pagina.locator('tbody tr').filter({ hasText: placa });
  await viajeNuevo.getByRole('button', { name: 'Registrar control', exact: true }).click();
  comprobar('Sin control aprobado no se ofrece iniciar', await viajeNuevo.getByRole('button', { name: 'Iniciar viaje' }).count() === 0);
  await pagina.getByLabel('Número de ticket').fill(`SAL-${placa}`);
  await pagina.getByLabel('Alcoholemia en mg/L').fill('0');
  await pagina.getByRole('dialog').screenshot({ path: resolve(capturas, '11-control-salida-pc.png') });
  await pagina.getByRole('button', { name: 'Guardar control' }).click();
  await viajeNuevo.getByText('Control aprobado', { exact: false }).waitFor();
  comprobar('El ticket aprobado habilita el botón de inicio', await viajeNuevo.getByRole('button', { name: 'Iniciar viaje' }).isVisible());
  await foto(pagina, '12-viaje-habilitado-pc.png');
  const idViaje = persistido.viajes.find(v => v.vehiculo_id === nuevo.id).id;
  const cambioSinCsrf = await contexto.request.patch(`${origen}/api/viajes/${idViaje}/estado`, { data: { estado: 'EN_CURSO' } });
  comprobar('Los cambios de estado exigen protección CSRF', cambioSinCsrf.status() === 419);
  await viajeNuevo.getByRole('button', { name: 'Iniciar viaje' }).click();
  await pagina.getByRole('button', { name: 'Confirmar inicio' }).click();
  await viajeNuevo.getByText('En curso', { exact: true }).waitFor();
  let operacion = await (await contexto.request.get(`${origen}/api/viajes`)).json();
  comprobar('El inicio ocupa el bus y el conductor', operacion.vehiculos.find(v => v.id === nuevo.id).estado === 'EN_RUTA' &&
    operacion.conductores.find(c => c.id === 4).estado === 'EN_VIAJE');
  await viajeNuevo.getByRole('button', { name: 'Finalizar viaje' }).click();
  await pagina.getByLabel('Kilometraje de llegada').fill('1042');
  await pagina.getByRole('dialog').screenshot({ path: resolve(capturas, '13-finalizar-viaje-pc.png') });
  await pagina.getByRole('button', { name: 'Confirmar llegada' }).click();
  await viajeNuevo.getByText('Finalizado', { exact: true }).waitFor();
  operacion = await (await contexto.request.get(`${origen}/api/viajes`)).json();
  const busDevuelto = operacion.vehiculos.find(v => v.id === nuevo.id);
  comprobar('La llegada actualiza el kilometraje y libera las asignaciones', busDevuelto.kilometraje === 1042 &&
    busDevuelto.estado === 'DISPONIBLE' && operacion.conductores.find(c => c.id === 4).estado === 'DISPONIBLE');

  const nuevoProgramado = await enviar(contexto, 'viajes', payload);
  assert.equal(nuevoProgramado.status(), 201);
  const segundo = (await nuevoProgramado.json()).viaje;
  await pagina.reload();
  const rechazado = pagina.locator('tbody tr').filter({ hasText: `V-${segundo.id}` });
  await rechazado.getByRole('button', { name: 'Registrar control', exact: true }).click();
  await pagina.getByLabel('Número de ticket').fill(`RECH-${placa}`);
  await pagina.getByLabel('Alcoholemia en mg/L').fill('0.015');
  await pagina.getByRole('button', { name: 'Guardar control' }).click();
  await rechazado.getByText('Control rechazado', { exact: false }).waitFor();
  comprobar('El resultado positivo bloquea el inicio', await rechazado.getByRole('button', { name: 'Iniciar viaje' }).count() === 0);
  await rechazado.getByRole('button', { name: 'Cancelar viaje' }).click();
  await pagina.getByRole('button', { name: 'Confirmar cancelación' }).click();
  await rechazado.getByText('Cancelado', { exact: true }).waitFor();
  comprobar('El viaje cancelado conserva el ticket en el historial', await rechazado.getByText(`Ticket RECH-${placa}`, { exact: false }).isVisible());

  await pagina.getByRole('link', { name: 'Vehículos', exact: true }).click();
  const filaBus = pagina.locator('tbody tr').filter({ hasText: placa });
  await filaBus.getByRole('button', { name: 'Editar', exact: true }).click();
  comprobar('La edición carga el kilometraje de llegada', await pagina.getByLabel('Kilometraje actual').inputValue() === '1042');
  await pagina.getByLabel('Marca y línea').fill('Chevrolet NPR revisado');
  await pagina.getByRole('dialog').getByLabel('Estado', { exact: true }).selectOption('FUERA_SERVICIO');
  await pagina.getByRole('dialog').screenshot({ path: resolve(capturas, '14-editar-vehiculo-pc.png') });
  await pagina.getByRole('button', { name: 'Guardar cambios' }).click();
  await filaBus.getByText('Fuera de servicio', { exact: true }).waitFor();
  await pagina.reload();
  await filaBus.getByText('Fuera de servicio', { exact: true }).waitFor();
  comprobar('El vehículo retirado conserva su edición al recargar', await filaBus.getByText('Chevrolet NPR revisado', { exact: false }).isVisible());
  await foto(pagina, '15-vehiculo-retirado-pc.png');

  await pagina.getByRole('link', { name:'Catálogos' }).click();
  await pagina.getByRole('button', { name:'Registrar ruta' }).click();
  const dialogo = pagina.getByRole('dialog');
  async function llenar(campos) {
    for (const [etiqueta, valor] of Object.entries(campos)) {
      await dialogo.getByLabel(etiqueta, { exact:true }).fill(valor);
    }
  }
  const guardarRegistro = () => dialogo.getByRole('button', { name:'Guardar', exact:true }).click();
  const codigoRuta = dialogo.getByLabel('Código de ruta', { exact:true });
  comprobar('El código de ruta se muestra automáticamente y es de solo lectura',
    await codigoRuta.inputValue() === '0001' && !await codigoRuta.isEditable());
  let consultasRuta = 0;
  await pagina.route('**/api/catalogos/rutas/estimar', ruta => {
    consultasRuta++;
    if (consultasRuta === 1) return ruta.fulfill({ status:503, headers:{'Retry-After':'2'}, json:{message:'Servicio ocupado'} });
    return ruta.fulfill({ json:{distancia:27.5, duracion:55} });
  });
  await dialogo.getByLabel('Origen', { exact:true }).selectOption('Bello');
  await dialogo.getByLabel('Destino', { exact:true }).selectOption('Envigado');
  await dialogo.getByText('Estimación por carretera', {exact:false}).waitFor();
  comprobar('El cálculo completa los campos de distancia y duración al seleccionar los municipios',
    await dialogo.getByLabel('Distancia en km').inputValue() === '27.5' &&
    await dialogo.getByLabel('Duración en minutos').inputValue() === '55');
  comprobar('El formulario reintenta automáticamente cuando el servicio está ocupado', consultasRuta === 2);
  await guardarRegistro();
  const rutaFinal = pagina.getByRole('row').filter({ has:pagina.getByRole('cell', { name:'0001', exact:true }) });
  await rutaFinal.getByText('Bello → Envigado').waitFor();
  comprobar('Una ruta nueva queda visible en catálogos', await rutaFinal.isVisible());
  await foto(pagina, '17-catalogos-pc.png');
  await rutaFinal.getByRole('button', { name:'Editar' }).click();
  await dialogo.getByLabel('Estado').selectOption('0');
  await guardarRegistro();
  await rutaFinal.getByText('Inactiva', { exact:true }).waitFor();
  comprobar('La ruta se puede desactivar desde su catálogo', await rutaFinal.getByText('Inactiva', { exact:true }).isVisible());
  await pagina.getByRole('button', { name:'Conductores', exact:true }).click();
  await pagina.getByRole('button', { name:'Registrar conductor' }).click();
  await llenar({ 'Nombre completo':'Operación de prueba', 'Vencimiento de la licencia':'2032-10-01' });
  await dialogo.getByLabel('Estado').selectOption('DISPONIBLE');
  await guardarRegistro();
  await pagina.getByRole('row').filter({ hasText:'Operación de prueba' }).waitFor();
  comprobar('El conductor nuevo se puede seleccionar al programar', (await contexto.request.get(`${origen}/api/viajes`).then(r => r.json())).conductores.some(c => c.nombre === 'Operación de prueba'));

  await pagina.getByRole('link', { name:'Registros', exact:true }).click();
  for (const [seccion, texto] of [
    ['Mantenimientos', 'Sin mantenimientos registrados'],
    ['Incidentes', 'Sin incidentes registrados'],
    ['Combustible', 'Sin abastecimientos registrados'],
  ]) {
    const pestana = pagina.getByRole('button', { name:seccion, exact:true });
    await pestana.click();
    comprobar(`${seccion} tiene una pestaña activa y su propio mensaje vacío`,
      await pestana.getAttribute('aria-pressed') === 'true' && await pagina.getByText(texto, { exact:true }).isVisible());
  }
  await foto(pagina, 'modulo-combustible-sin-datos.png');
  await pagina.route('**/api/registros/combustible/acpm', ruta => ruta.fulfill({json:{
    ciudad:'Medellín', precio_galon:11641, precio_litro:3075.23, vigente_desde:'2026-11-01',
    fuente:'https://creg.gov.co/publicaciones/15565/precios-de-combustibles-liquidos/',
  }}));
  await pagina.getByRole('button', { name:'Registrar abastecimiento' }).click();
  await dialogo.getByText(/ACPM en Medellín/).waitFor();
  const precioLitro = dialogo.getByLabel('Precio por litro en COP');
  comprobar('El formulario muestra la referencia por galón sin cambiar el precio de la factura',
    (await dialogo.getByText(/ACPM en Medellín/).innerText()).includes('11.641') && await precioLitro.inputValue() === '');
  await dialogo.getByRole('button', { name:/Usar .* COP por litro/ }).click();
  comprobar('La referencia se puede copiar por litro y ajustar antes de guardar',
    await precioLitro.inputValue() === '3075.23' && await precioLitro.isEditable());
  await dialogo.getByLabel('Vehículo').selectOption('1');
  await llenar({ Litros:'20.25', 'Precio por litro en COP':'10000', Detalle:'Abastecimiento de prueba' });
  await guardarRegistro();
  const abastecimiento = pagina.getByRole('row').filter({ hasText:'Abastecimiento de prueba' });
  await abastecimiento.waitFor();
  comprobar('El abastecimiento muestra el costo calculado', (await abastecimiento.innerText()).includes('202.500'));
  const descarga = pagina.waitForEvent('download');
  await pagina.getByRole('link', { name:'Descargar CSV' }).click();
  comprobar('La aplicación descarga el CSV de combustible', (await descarga).suggestedFilename() === 'floatmate-combustible.csv');
  await foto(pagina, '18-combustible-pc.png');

  await pagina.getByRole('button', { name:'Mantenimientos', exact:true }).click();
  await pagina.getByRole('button', { name:'Registrar mantenimiento' }).click();
  await dialogo.getByLabel('Vehículo').selectOption('3');
  await llenar({ 'Kilometraje del servicio':'89300', 'Próximo mantenimiento en km':'95000', Detalle:'Servicio preventivo de prueba' });
  await guardarRegistro();
  await pagina.getByRole('row').filter({ hasText:'Servicio preventivo de prueba' }).waitFor();
  comprobar('El mantenimiento libera el vehículo y actualiza su próximo servicio',
    (await contexto.request.get(`${origen}/api/vehiculos`).then(r => r.json())).vehiculos.some(v => v.placa === 'WLM305' && v.estado === 'DISPONIBLE' && v.proximo_mantenimiento === 95000));
  await foto(pagina, '19-mantenimientos-pc.png');
  await pagina.getByRole('button', { name:'Incidentes', exact:true }).click();
  await pagina.getByRole('button', { name:'Registrar incidente' }).click();
  await dialogo.getByLabel('Viaje', { exact:true }).selectOption('9004');
  await dialogo.getByLabel('Gravedad').selectOption('BAJA');
  await llenar({ Detalle:'Novedad de prueba' });
  await guardarRegistro();
  await pagina.getByRole('row').filter({ hasText:'Novedad de prueba' }).waitFor();
  comprobar('El incidente queda asociado al viaje y al vehículo', await pagina.getByRole('row').filter({ hasText:'Novedad de prueba' }).getByText('KPT641').isVisible());
  await pagina.getByRole('link', { name:'Resumen', exact:true }).click();
  await pagina.getByRole('heading', { name:'Actividad registrada' }).waitFor();
  comprobar('El resumen muestra el total registrado', await pagina.getByText('$ 202.500 COP', { exact:true }).isVisible());
  await foto(pagina, '20-resumen-final-pc.png');

  const movil=await navegador.newContext({viewport:{width:390,height:844},deviceScaleFactor:1,isMobile:true,hasTouch:true});
  const mp=await movil.newPage();
  mp.on('pageerror',e=>errores.push(e.message));
  await mp.goto(`${origen}/login`);await ingresar(mp);
  await mp.getByRole('link',{name:'Vehículos',exact:true}).click();
  await mp.getByRole('heading',{name:'Inventario de vehículos'}).waitFor();
  comprobar('Vehículos se adapta al ancho móvil',await mp.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  await foto(mp,'07-vehiculos-movil.png');
  await mp.getByRole('button',{name:'Registrar vehículo',exact:true}).click();
  comprobar('El formulario de vehículo cabe en móvil',await mp.locator('dialog').evaluate(d=>d.scrollWidth<=d.clientWidth));
  await foto(mp,'08-registro-movil.png');
  await mp.getByRole('button',{name:'Cerrar',exact:true}).click();
  await mp.getByRole('link',{name:'Viajes',exact:true}).click();
  await mp.getByRole('heading',{name:'Programación de viajes'}).waitFor();
  comprobar('Viajes se adapta al ancho móvil',await mp.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  await foto(mp,'09-viajes-movil.png');
  await mp.getByRole('button',{name:'Programar viaje',exact:true}).click();
  comprobar('El formulario de viaje cabe en móvil',await mp.getByRole('dialog').evaluate(d=>d.scrollWidth<=d.clientWidth));
  await foto(mp,'10-programacion-movil.png');
  await mp.getByRole('dialog').getByRole('button', { name: 'Cerrar' }).click();
  await mp.getByRole('button', { name: 'Registrar control', exact: true }).first().click();
  const controlMovil = mp.getByRole('dialog', { name: 'Registrar control de salida' });
  comprobar('El control de salida se adapta a móvil', await controlMovil.evaluate(d => d.scrollWidth <= d.clientWidth));
  await mp.getByRole('button', { name: 'Guardar control', exact: true }).waitFor();
  await mp.screenshot({ path: resolve(capturas, '16-control-salida-movil.png') });
  await controlMovil.getByRole('button', { name:'Cerrar' }).click();
  await mp.getByRole('link', { name:'Registros', exact:true }).click();
  await mp.getByRole('heading', { name:'Registros de operación' }).waitFor();
  comprobar('Registros se adapta al ancho móvil', await mp.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  await mp.route('**/api/registros/combustible/acpm', ruta => ruta.fulfill({status:503, json:{message:'Referencia no disponible'}}));
  await mp.getByRole('button', { name:'Registrar abastecimiento' }).click();
  await mp.getByText(/Referencia de ACPM no disponible/).waitFor();
  comprobar('El precio se puede registrar manualmente si la referencia no está disponible',
    await mp.getByLabel('Precio por litro en COP').isEditable());
  comprobar('El formulario de combustible cabe en móvil', await mp.getByRole('dialog').evaluate(d => d.scrollWidth <= d.clientWidth));
  await foto(mp, '21-combustible-movil.png');
  await mp.getByRole('dialog').getByRole('button', { name:'Cerrar' }).click();
  await mp.setViewportSize({ width:320, height:740 });
  for (const [enlace, titulo, accion] of [
    ['Vehículos', 'Inventario de vehículos', 'Registrar vehículo'],
    ['Viajes', 'Programación de viajes', 'Programar viaje'],
    ['Catálogos', 'Rutas', 'Registrar ruta'],
    ['Registros', 'Combustible', 'Registrar abastecimiento'],
  ]) {
    await mp.getByRole('navigation', { name:'Navegación principal' }).getByRole('link', { name:enlace, exact:true }).click();
    await mp.getByRole('heading', { name:titulo, exact:true }).waitFor();
    comprobar(`${enlace} conserva su acción principal y cabe a 320 px`,
      await mp.getByRole('button', { name:accion, exact:true }).isVisible() &&
      await mp.evaluate(() => document.documentElement.scrollWidth === document.documentElement.clientWidth &&
        [...document.querySelectorAll('.tabla-operacion, .toolbar')].every(elemento => elemento.scrollWidth <= elemento.clientWidth)));
  }

  await pagina.getByRole('link', { name:'Accesos', exact:true }).click();
  for (const [usuario, rol] of [['operador.demo', 'Operador'], ['carlos.demo', 'Conductor']]) {
    await pagina.getByRole('button', { name:'Crear cuenta', exact:true }).click();
    await dialogo.getByLabel('Usuario', { exact:true }).fill(usuario);
    await dialogo.getByLabel('Rol', { exact:true }).selectOption(rol);
    if (rol === 'Conductor') await dialogo.getByLabel('Conductor del catálogo').selectOption({ label:'Carlos Restrepo' });
    else await dialogo.getByLabel('Nombre completo').fill('Operador de prueba');
    await dialogo.getByLabel('Nueva contraseña').fill('Acceso-demostracion-2026');
    await dialogo.getByRole('button', { name:'Guardar cuenta' }).click();
    await pagina.getByRole('row').filter({ hasText:usuario }).waitFor();
    comprobar(`El administrador crea la cuenta de ${rol} desde Accesos`,
      await pagina.getByRole('row').filter({ hasText:usuario }).getByText(rol, { exact:true }).isVisible());
  }
  await foto(pagina, 'accesos-operativos.png');

  const portal = await navegador.newPage({ viewport:{width:320,height:740} });
  portal.on('pageerror', error => errores.push(error.message));
  await portal.goto(`${origen}/login`);
  await portal.getByLabel('Usuario', { exact:true }).fill('carlos.demo');
  await portal.getByLabel('Contraseña', { exact:true }).fill('Acceso-demostracion-2026');
  await portal.getByRole('button', { name:'Ingresar', exact:true }).click();
  await portal.waitForURL('**/mis-viajes');
  await portal.getByRole('heading', { name:'Mis viajes', exact:true }).waitFor();
  comprobar('En móvil, el conductor entra solo a sus viajes y la página cabe a 320 px',
    await portal.getByRole('article').count() === 1 && await portal.getByText('Viaje V-9001').isVisible() &&
    await portal.getByRole('navigation', { name:'Navegación principal' }).getByRole('link').count() === 1 &&
    await portal.evaluate(() => document.documentElement.scrollWidth === document.documentElement.clientWidth));
  await portal.screenshot({ path:resolve(capturas, 'mis-viajes-movil.png'), fullPage:true });

  const dialogoConductor = portal.getByRole('dialog');
  await portal.getByRole('button', { name:'Confirmar asignación', exact:true }).click();
  await dialogoConductor.getByRole('button', { name:'Confirmar', exact:true }).click();
  await portal.getByText('Asignación confirmada', { exact:true }).waitFor();
  await pagina.getByRole('link', { name:'Viajes', exact:true }).click();
  const viajeCarlos = pagina.getByRole('row').filter({ hasText:'V-9001' });
  comprobar('La confirmación del conductor aparece en el despacho',
    await viajeCarlos.getByText('Confirmado por conductor', { exact:true }).isVisible());
  await viajeCarlos.getByRole('button', { name:'Registrar control', exact:true }).click();
  await dialogo.getByLabel('Número de ticket').fill('PORTAL-9001');
  await dialogo.getByLabel('Alcoholemia en mg/L').fill('0');
  await dialogo.getByRole('button', {name:'Guardar control'}).click();
  await viajeCarlos.getByRole('button', { name:'Iniciar viaje', exact:true }).click();
  await dialogo.getByRole('button', {name:'Confirmar inicio'}).click();
  await viajeCarlos.getByText('En curso', { exact:true }).waitFor();
  await portal.reload();
  await portal.getByRole('button', { name:'Reportar novedad', exact:true }).click();
  await dialogoConductor.getByLabel('Gravedad').selectOption('BAJA');
  await dialogoConductor.getByLabel('Detalle de la novedad').fill('Novedad desde el portal del conductor');
  await dialogoConductor.getByRole('button', { name:'Enviar novedad' }).click();
  await portal.getByText('Novedad registrada.', { exact:true }).waitFor();
  await portal.getByRole('button', { name:'Registrar llegada', exact:true }).click();
  await dialogoConductor.getByLabel('Kilometraje de llegada').fill('35000');
  await dialogoConductor.getByRole('button', { name:'Guardar llegada' }).click();
  await portal.getByText('Finalizado', { exact:true }).waitFor();
  const registrosConductor = await contexto.request.get(`${origen}/api/registros`).then(r => r.json());
  comprobar('La llegada desde móvil finaliza el viaje y la novedad aparece en Registros',
    registrosConductor.viajes.some(viaje => viaje.id === 9001 && viaje.estado === 'FINALIZADO') &&
    registrosConductor.incidentes.some(incidente => incidente.viaje_id === 9001 && incidente.registrado_por === 'Carlos Restrepo'));
  await portal.close();
  comprobar('El recorrido no genera errores JavaScript',errores.length===0);
  await writeFile(resolve(capturas,'resultados.json'),JSON.stringify({fecha:new Date().toISOString(),comprobaciones:resultados.length,resultados},null,2));
  console.log(resultados.map(x=>`PASS ${x}`).join('\n'));
  console.log(`RESULTADO: ${resultados.length} comprobaciones correctas.`);
} finally { await navegador.close(); }
