#!/usr/bin/env bash
set -euo pipefail

: "${FLOATMATE_APP_SECRET:?Configura FLOATMATE_APP_SECRET}"
: "${FLOATMATE_DEMO_PASSWORD:?Configura FLOATMATE_DEMO_PASSWORD}"
export APP_KEY="base64:$FLOATMATE_APP_SECRET"
export DEMO_PASSWORD_HASH
DEMO_PASSWORD_HASH="$(php -r '$p = getenv("FLOATMATE_DEMO_PASSWORD"); if (strlen($p) < 12 || strlen($p) > 72) exit(1); echo password_hash($p, PASSWORD_BCRYPT);')"
unset FLOATMATE_DEMO_PASSWORD FLOATMATE_APP_SECRET

export APP_ENV=production APP_DEBUG=false FLOTA_STORAGE=json
export SESSION_SECURE_COOKIE="${SESSION_SECURE_COOKIE:-true}"
export LARAVEL_URL=http://127.0.0.1:8000 FLOATMATE_HOSTED=1

cd /app/backend
export DEMO_DATA_PATH
DEMO_DATA_PATH="$(php artisan flota:preparar-demo)"
test -s "$DEMO_DATA_PATH/flota.json"
php artisan serve --host=127.0.0.1 --port=8000 --no-reload &
backend=$!

cd /app/frontend
node node_modules/next/dist/bin/next start --hostname 0.0.0.0 --port "${PORT:-10000}" &
frontend=$!

trap 'kill "$backend" "$frontend" 2>/dev/null || true' EXIT
trap 'exit 0' TERM INT
wait -n "$backend" "$frontend"
