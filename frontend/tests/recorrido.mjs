import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const origen = process.env.FLOATMATE_URL || 'http://127.0.0.1:3000';
const capturas = new URL('../../docs/capturas/', import.meta.url);
await mkdir(capturas, { recursive: true });
const navegador = await chromium.launch({ headless: true, ...(process.env.PLAYWRIGHT_CHANNEL ? { channel: process.env.PLAYWRIGHT_CHANNEL } : {}) });
const errores = [];
const resultados = [];
const comprobar = (nombre, condicion) => { assert.ok(condicion, nombre); resultados.push(`PASS ${nombre}`); };

async function ingresar(pagina) {
  await pagina.getByLabel('Usuario', { exact: true }).fill('admin');
  await pagina.getByLabel('Contraseña', { exact: true }).fill('floatmate123');
  await pagina.getByRole('button', { name: 'Ingresar', exact: true }).click();
  await pagina.waitForURL('**/resumen');
  await pagina.getByRole('heading', { name: 'Resumen de la flota' }).waitFor();
}

try {
  const contexto = await navegador.newContext({ viewport: { width: 1268, height: 697 }, deviceScaleFactor: 1.25 });
  const pagina = await contexto.newPage();
  pagina.on('pageerror', error => errores.push(error.message));
  await pagina.goto(`${origen}/resumen`);
  await pagina.waitForURL('**/login');
  comprobar('El resumen sin sesión vuelve al acceso', pagina.url().endsWith('/login'));
  await pagina.screenshot({ path: fileURLToPath(new URL('01-login-pc.png', capturas)), fullPage: true });

  await pagina.getByLabel('Contraseña', { exact: true }).fill('incorrecta');
  await pagina.getByRole('button', { name: 'Mostrar contraseña' }).click();
  comprobar('Ver muestra la contraseña', await pagina.locator('#clave').getAttribute('type') === 'text');
  await pagina.getByRole('button', { name: 'Ocultar contraseña' }).click();
  comprobar('Ocultar protege la contraseña', await pagina.locator('#clave').getAttribute('type') === 'password');
  await pagina.getByLabel('Usuario', { exact: true }).fill('admin');
  await pagina.getByRole('button', { name: 'Ingresar', exact: true }).click();
  await pagina.getByText('Usuario o contraseña incorrectos. Intenta de nuevo.', { exact: true }).waitFor();
  comprobar('Credenciales incorrectas muestran un mensaje', pagina.url().endsWith('/login'));

  await ingresar(pagina);
  comprobar('Login conectado a Laravel', pagina.url().endsWith('/resumen'));
  comprobar('Indicadores de la referencia', (await pagina.locator('.metric strong').allTextContents()).join(',') === '5,3,2,1');
  comprobar('Dos viajes de demostración', await pagina.locator('tbody tr').count() === 2);
  comprobar('Los módulos pendientes están deshabilitados', await pagina.getByRole('button', { name: 'Vehículos', exact: true }).isDisabled() && await pagina.getByRole('button', { name: 'Viajes', exact: true }).isDisabled());
  await pagina.reload();
  await pagina.getByRole('heading', { name: 'Resumen de la flota' }).waitFor();
  comprobar('Recargar conserva la sesión', pagina.url().endsWith('/resumen'));
  await pagina.setViewportSize({ width: 1536, height: 741 });
  await pagina.screenshot({ path: fileURLToPath(new URL('02-resumen-pc.png', capturas)), fullPage: true });

  const respuestaSinCsrf = await contexto.request.post(`${origen}/api/logout`, { data: {} });
  comprobar('El servidor rechaza POST sin CSRF', respuestaSinCsrf.status() === 419);
  comprobar('La cookie de sesión es HttpOnly', (await contexto.cookies()).some(cookie => cookie.name.includes('session') && cookie.httpOnly));
  await pagina.getByRole('button', { name: 'Salir', exact: true }).click();
  await pagina.waitForURL('**/login');
  await pagina.goto(`${origen}/resumen`);
  await pagina.waitForURL('**/login');
  comprobar('Salir invalida la sesión', pagina.url().endsWith('/login'));

  const movil = await navegador.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  const paginaMovil = await movil.newPage();
  paginaMovil.on('pageerror', error => errores.push(error.message));
  await paginaMovil.goto(`${origen}/login`);
  await paginaMovil.screenshot({ path: fileURLToPath(new URL('03-login-movil.png', capturas)), fullPage: true });
  comprobar('Login móvil sin desplazamiento horizontal', await paginaMovil.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  await ingresar(paginaMovil);
  await paginaMovil.screenshot({ path: fileURLToPath(new URL('04-resumen-movil.png', capturas)), fullPage: true });
  comprobar('Resumen móvil sin desplazamiento horizontal', await paginaMovil.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  comprobar('Sin errores JavaScript', errores.length === 0);
  console.log(resultados.join('\n'));
} finally {
  await navegador.close();
}
