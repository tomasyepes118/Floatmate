import localFont from 'next/font/local';

export const inter = localFont({
  src: './fonts/InterVariable.woff2',
  weight: '400 800',
  display: 'swap',
  fallback: ['system-ui', 'sans-serif'],
});
