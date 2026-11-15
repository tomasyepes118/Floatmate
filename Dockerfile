FROM node:22-bookworm-slim AS frontend-build
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build && npm prune --omit=dev

FROM composer:2 AS composer-bin

FROM php:8.4-cli-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends unzip libonig-dev \
    && docker-php-ext-install mbstring \
    && rm -rf /var/lib/apt/lists/*
COPY --from=frontend-build /usr/local/bin/node /usr/local/bin/node
COPY --from=composer-bin /usr/bin/composer /usr/local/bin/composer

WORKDIR /app
COPY backend/ ./backend/
RUN composer --working-dir=backend install --no-dev --no-interaction --prefer-dist
COPY --from=frontend-build /app/frontend/ ./frontend/
COPY scripts/iniciar-demo.sh ./scripts/iniciar-demo.sh
RUN chown -R www-data:www-data /app/backend/storage /app/backend/bootstrap/cache

ENV NEXT_TELEMETRY_DISABLED=1
EXPOSE 10000
USER www-data
CMD ["bash", "/app/scripts/iniciar-demo.sh"]
