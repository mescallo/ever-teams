# syntax = docker/dockerfile:1
# Ever Teams Platform - Version 16
# Optimizado para problemas con date-fns

FROM node:20.11.1-bullseye as deps

WORKDIR /app

# Configurar registros alternativos
RUN npm config set registry https://registry.npmmirror.com && \
    npm config set sharp_binary_host "https://npmmirror.com/mirrors/sharp" && \
    npm config set sharp_libvips_binary_host "https://npmmirror.com/mirrors/sharp-libvips" && \
    npm config set puppeteer_download_host "https://npmmirror.com/mirrors" && \
    npm config set electron_mirror "https://npmmirror.com/mirrors/electron/" && \
    npm config set sass_binary_site "https://npmmirror.com/mirrors/node-sass" && \
    npm install -g npm@latest

# Instalar dependencias necesarias
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    python-is-python3 \
    git \
    ca-certificates \
    curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Pre-descargar date-fns
RUN cd /tmp && \
    curl -L -o date-fns.tgz https://registry.npmmirror.com/date-fns/-/date-fns-2.30.0.tgz && \
    npm install /tmp/date-fns.tgz

# Copiar archivos de package
COPY package*.json ./
COPY apps/web/package*.json ./apps/web/

# Instalar dependencias con npm
RUN cd apps/web && \
    for i in 1 2 3 4 5; do \
        echo "=== Intento de instalación $i/5 ===" && \
        npm install --registry https://registry.npmmirror.com \
        --prefer-offline \
        --no-audit \
        --no-fund \
        --legacy-peer-deps && break || \
        echo "Reintentando en 45s..." && \
        sleep 45; \
    done

FROM node:20.11.1-bullseye as builder

WORKDIR /app

# Copiar dependencias y código
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /tmp/node_modules/date-fns ./node_modules/date-fns
COPY . .

# Build con npm
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN cd apps/web && npm run build

FROM node:20.11.1-bullseye-slim as runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3030

COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/.next/static ./.next/static
COPY --from=builder /app/apps/web/public ./public

EXPOSE 3030

CMD ["node", "server.js"]
