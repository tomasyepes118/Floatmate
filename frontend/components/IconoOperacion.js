const trazos = {
  resumen: 'M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h7v7h-7z',
  vehiculos: 'M5 17v2a1 1 0 0 0 1 1h1a1 1 0 0 0 1-1v-2m8 0v2a1 1 0 0 0 1 1h1a1 1 0 0 0 1-1v-2M4 6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2Zm0 5h16M8 14h1m6 0h1M2 8v3m20-3v3',
  viajes: 'M19 10c0 5-7 11-7 11S5 15 5 10a7 7 0 1 1 14 0ZM14.5 10a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0Z',
  catalogos: 'm12 3 9 5-9 5-9-5 9-5ZM3 12l9 5 9-5M3 16l9 5 9-5',
  registros: 'M9 5H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-3M9 3h6v4H9zM8 12h8m-8 4h8',
  programados: 'M5 5h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Zm2-2v4m10-4v4M3 10h18',
  mantenimiento: 'M21 6.5 17.5 10l-3.6-.8-.8-3.6L16.6 2A6 6 0 0 0 10 9.4l-7 7a3 3 0 0 0 4.2 4.2l7-7A6 6 0 0 0 21 6.5Z',
  salir: 'M10 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h5M8 12h13m-5-5 5 5-5 5',
  flecha: 'M3 12h17m-6-6 6 6-6 6',
};

export default function IconoOperacion({ nombre }) {
  return <svg aria-hidden="true" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d={trazos[nombre]} /></svg>;
}
