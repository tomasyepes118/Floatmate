import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const origen = process.env.FLOATMATE_URL || 'http://127.0.0.1:3000';
const capturas = resolve(process.env.FLOATMATE_CAPTURAS || 'test-results/avance-2');
await mkdir(capturas, { recursive: true });
const navegador = await chromium.launch({ headless: true, ...(process.env.PLAYWRIGHT_CHANNEL ? { channel: process.env.PLAYWRIGHT_CHANNEL } : {}) });
const resultados = [], errores = [];
const comprobar = (nombre, valor) => { assert.ok(valor, nombre); resultados.push(nombre); };
const foto = (pagina, nombre) => /error|registrar|programar|registro|programacion/.test(nombre) ? pagina.getByRole('dialog').screenshot({ path: resolve(capturas, nombre) }) : pagina.screenshot({ path: resolve(capturas, nombre), fullPage: false });

async function ingresar(pagina) {
  await pagina.getByLabel('Usuario', { exact: true }).fill('admin');
  await pagina.getByLabel('Contraseña', { exact: true }).fill('floatmate123');
  await pagina.getByRole('button', { name: 'Ingresar', exact: true }).click();
  await pagina.waitForURL('**/resumen');
  await pagina.getByRole('heading', { name: 'Resumen de la flota' }).waitFor();
}

async function enviar(contexto, ruta, datos) {
  const csrf = await contexto.request.get(`${origen}/api/csrf`);
  const { token } = await csrf.json();
  return contexto.request.post(`${origen}/api/${ruta}`, { data: datos, headers: { 'X-CSRF-TOKEN': token, Accept: 'application/json' } });
}

try {
  const contexto = await navegador.newContext({ viewport: { width: 1440, height: 850 }, deviceScaleFactor: 1 });
  const pagina = await contexto.newPage();
  pagina.on('pageerror', error => errores.push(error.message));
  for (const ruta of ['resumen','vehiculos','viajes']) {
    await pagina.goto(`${origen}/${ruta}`);
    await pagina.waitForURL('**/login');
    comprobar(`${ruta} exige una sesión`, pagina.url().endsWith('/login'));
  }
  await pagina.getByLabel('Usuario', { exact: true }).fill('admin');
  await pagina.getByLabel('Contraseña', { exact: true }).fill('incorrecta');
  await pagina.getByRole('button', { name: 'Ingresar', exact: true }).click();
  await pagina.getByText('Usuario o contraseña incorrectos. Intenta de nuevo.', { exact: true }).waitFor();
  comprobar('El login rechaza una contraseña incorrecta', pagina.url().endsWith('/login'));
  await ingresar(pagina);
  const catalogos = await (await contexto.request.get(`${origen}/api/viajes`)).json();
  assert.equal(catalogos.pruebas_navegador, true, 'Inicia Laravel con DEMO_E2E=true y DEMO_DATA_PATH apuntando a una carpeta de pruebas antes de ejecutar este recorrido.');
  const baseResumen = await (await contexto.request.get(`${origen}/api/resumen`)).json();
  comprobar('Login y resumen funcionan', await pagina.locator('.metric').count()===4);
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
  while(catalogos.vehiculos.some(v=>v.placa===`PRU${n}`||v.codigo===`AVANCE2-${n}`)) n++;
  const placa=`PRU${n}`, codigo=`AVANCE2-${n}`;
  for (const [campo,valor] of [['Placa','TPQ482'],['Código interno',codigo],['Marca y línea','Chevrolet NPR'],['Modelo','2026'],['Capacidad de pasajeros','30'],['Kilometraje actual','1000'],['Próximo mantenimiento en km','10000']]) {
    await pagina.getByLabel(campo,{exact:true}).fill(valor);
  }
  await pagina.getByRole('button',{name:'Guardar vehículo',exact:true}).click();
  await pagina.locator('.form-error').filter({hasText:'La placa ya está registrada.'}).waitFor();
  comprobar('La placa repetida se rechaza desde Laravel', (await contexto.request.get(`${origen}/api/vehiculos`).then(r=>r.json())).vehiculos.length===catalogos.vehiculos.length);
  await foto(pagina,'02-error-placa-pc.png');
  await pagina.getByLabel('Placa',{exact:true}).fill(placa);
  await foto(pagina,'03-registrar-vehiculo-pc.png');
  await pagina.getByRole('button',{name:'Guardar vehículo',exact:true}).click();
  await pagina.getByText('Vehículo registrado correctamente.',{exact:true}).waitFor();
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
  await pagina.getByLabel('Observaciones',{exact:true}).fill('Programación de demostración del segundo avance.');
  await pagina.getByRole('button',{name:'Confirmar programación',exact:true}).click();
  await pagina.locator('.form-error').filter({hasText:'Selecciona una fecha y hora futuras.'}).waitFor();
  comprobar('La fecha pasada se rechaza con un mensaje', await pagina.getByRole('dialog').isVisible());
  await pagina.getByLabel('Fecha y hora de salida',{exact:true}).fill(salida);
  await foto(pagina,'05-programar-viaje-pc.png');
  const payload={ruta_id:1,vehiculo_id:nuevo.id,conductor_id:4,salida,pasajeros:13,observaciones:'Prueba de navegador.'};
  const exceso=await enviar(contexto,'viajes',{...payload,pasajeros:31});
  comprobar('El servidor rechaza el exceso de capacidad', exceso.status()===422 && (await exceso.json()).errors.pasajeros.length>0);
  await pagina.getByRole('button',{name:'Confirmar programación',exact:true}).click();
  await pagina.getByText('Viaje programado correctamente.',{exact:true}).waitFor();
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
  comprobar('El formulario de viaje cabe en móvil',await mp.locator('dialog').evaluate(d=>d.scrollWidth<=d.clientWidth));
  await foto(mp,'10-programacion-movil.png');
  comprobar('El recorrido no genera errores JavaScript',errores.length===0);
  await writeFile(resolve(capturas,'resultados.json'),JSON.stringify({fecha:new Date().toISOString(),comprobaciones:resultados.length,resultados},null,2));
  console.log(resultados.map(x=>`PASS ${x}`).join('\n'));
  console.log(`RESULTADO: ${resultados.length} comprobaciones correctas.`);
} finally { await navegador.close(); }
