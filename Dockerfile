# syntax = docker/dockerfile:1
# Ever Teams Platform - Version 14
# Optimizado para estabilidad de red y npm

FROM node:20.11.1-bullseye as deps

# Configuración de entorno y recursos
ENV NODE_OPTIONS="--max_old_space_size=2048"
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_SHARP_PATH=/temp/node_modules/sharp
ENV NPM_CONFIG_LOGLEVEL=verbose

WORKDIR /app

# Instalación de dependencias base
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    python-is-python3 \
    git \
    ca-certificates \
    wget \
    curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /usr/local/lib/node_modules/yarn && \
    rm -rf /opt/yarn* && \
    rm -rf ~/.yarn

# Configuración de npm
RUN npm i -g npm@latest && \
    npm config set registry=https://registry.npmmirror.com && \
    npm config set fetch-retries=5 && \
    npm config set fetch-retry-mintimeout=60000 && \
    npm config set fetch-retry-maxtimeout=180000 && \
    npm config set prefer-offline=true && \
    npm config set timeout=300000

# Instalación de sharp
RUN mkdir -p /temp && cd /temp && \
    for i in 1 2 3; do \
        echo "Intento de instalación de sharp $i/3" && \
        npm install sharp --no-audit --no-fund && break || \
        sleep 15; \
    done

# Copia e instalación de dependencias web
COPY package*.json ./
COPY apps/web/package*.json ./apps/web/

# Instalación de dependencias con reintentos
RUN cd apps/web && \
    for i in 1 2 3 4 5; do \
        echo "=== Intento de instalación $i/5 ===" && \
        PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
        npm install --prefer-offline --no-audit --no-fund --legacy-peer-deps && break || \
        echo "Reintento en 60s..." && \
        npm cache clean --force && \
        sleep 60; \
    done

FROM node:20.11.1-bullseye as builder

WORKDIR /app

# Copiar dependencias y código fuente
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /temp/node_modules/sharp ./node_modules/sharp
COPY . .

# Variables de entorno para build
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_OPTIONS="--max_old_space_size=2048"

# Build con reintentos
RUN cd apps/web && \
    for i in 1 2 3 4 5; do \
        echo "=== Intento de build $i/5 ===" && \
        NODE_ENV=production npm run build && break || \
        echo "Reintento en 60s..." && \
        rm -rf .next && \
        sleep 60; \
    done

FROM node:20.11.1-bullseye-slim as runner

WORKDIR /app

# Variables de entorno para producción
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3030

# Copiar aplicación compilada
COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/.next/static ./.next/static
COPY --from=builder /app/apps/web/public ./public

# Healthcheck
HEALTHCHECK --interval=30s --timeout=30s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=3 --spider http://localhost:3030 || exit 1

# Metadatos
LABEL version="14.0.0"
LABEL description="Ever Teams Platform - Optimized for network stability"
LABEL maintainer="ever@ever.co"

EXPOSE 3030

CMD ["node", "server.js"]
