# syntax = docker/dockerfile:1
# Ever Teams Platform - Version 13
# Enfoque: Estabilidad de red con NPM puro

FROM node:20.11.1-bullseye as deps

# Configuración de recursos
ENV NODE_OPTIONS="--max_old_space_size=2048"
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_SHARP_PATH=/tmp/node_modules/sharp
ENV NPM_CONFIG_LOGLEVEL=verbose

WORKDIR /app

# Remover yarn e instalar dependencias del sistema
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    python-is-python3 \
    git \
    ca-certificates \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/local/lib/node_modules/yarn \
    && rm -rf /opt/yarn* \
    && rm -rf ~/.yarn

# Configurar NPM
RUN npm i -g npm@latest && \
    npm cache clean --force && \
    npm config set registry=https://registry.npmmirror.com && \
    npm config set fetch-retries=5 && \
    npm config set fetch-retry-mintimeout=60000 && \
    npm config set fetch-retry-maxtimeout=180000 && \
    npm config set prefer-offline=true && \
    npm config set timeout=300000

# Preparar sharp
RUN mkdir -p /tmp && cd /tmp && \
    npm install sharp --no-package-lock

# Copiar solo package.json
COPY package*.json ./
COPY apps/web/package*.json ./apps/web/

# Instalar dependencias con reintentos
RUN cd apps/web && \
    for i in 1 2 3 4 5; do \
        echo "=== Intento de instalación $i/5 ===" && \
        PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
        npm install --prefer-offline --no-audit --no-fund --legacy-peer-deps && \
        if [ $? -eq 0 ]; then \
            echo "Instalación exitosa!" && \
            break; \
        else \
            echo "Fallo en intento $i. Limpiando y reintentando en 60s..." && \
            npm cache clean --force && \
            sleep 60; \
        fi; \
    done

FROM node:20.11.1-bullseye as builder

WORKDIR /app

# Copiar dependencias y código
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /tmp/node_modules/sharp ./node_modules/sharp
COPY . .

# Configuración de build
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_OPTIONS="--max_old_space_size=2048"

# Build con reintentos
RUN cd apps/web && \
    for i in 1 2 3 4 5; do \
        echo "=== Intento de build $i/5 ===" && \
        npm run build && \
        if [ $? -eq 0 ]; then \
            echo "Build exitoso!" && \
            break; \
        else \
            echo "Fallo en build $i. Limpiando y reintentando en 60s..." && \
            rm -rf .next && \
            npm cache clean --force && \
            sleep 60; \
        fi; \
    done

FROM node:20.11.1-bullseye-slim as runner

WORKDIR /app

# Configuración de producción
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3030

# Copiar aplicación compilada
COPY --from
