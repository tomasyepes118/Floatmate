const laravelUrl = process.env.LARAVEL_URL || 'http://127.0.0.1:8000';

/** El navegador usa el mismo origen; Laravel recibe las peticiones de la API. */
const nextConfig = {
  poweredByHeader: false,
  async rewrites() {
    return [{ source: '/api/:path*', destination: `${laravelUrl}/api/:path*` }];
  },
};

export default nextConfig;
