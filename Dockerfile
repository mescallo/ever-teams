# syntax = docker/dockerfile:1
# Ever Teams Platform - Version 12
# Optimizado para: Ubuntu 20.04, 4 CPUs, 5.8GB RAM
# Enfoque: Estabilidad de red y npm

FROM node:20.11.1-slim as deps

# Configuración de recursos y telemetría
ENV NODE_OPTIONS="--max_old_space_size=2048"
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_SHARP_PATH=/tmp/node_modules/sharp

WORKDIR /app

# Instalar dependencias del sistema
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    python-is-python3 \
    git \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configurar npm para mejor manejo de red
RUN npm i -g npm@latest && \
    npm config set registry https://registry.npmmirror.com && \
    npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 60000 && \
    npm config set fetch-retry-maxtimeout 180000 && \
    npm config set prefer-offline true && \
    npm config set timeout 300000

# Preparar sharp para Next.js
RUN mkdir -p /tmp && cd /tmp && \
    for i in 1 2 3; do \
        echo "Intento de instalación sharp $i/3" && \
        npm install sharp --no-audit --no-fund && \
        break || \
        echo "Reintentando en 30s..." && \
        npm cache clean --force && \
        sleep 30; \
    done

# Copiar archivos de package
COPY package*.json ./
COPY apps/web/package*.json ./apps/web/

# Instalar dependencias con reintentos
RUN cd apps/web && \
    for i in 1 2 3 4 5; do \
        echo "Intento de instalación $i/5" && \
        npm install --no-audit --no-fund --legacy-peer-deps --prefer-offline && \
        break || \
        echo "Reintentando en 45s..." && \
        npm cache clean --force && \
        sleep 45; \
    done

FROM node:20.11.1-slim as builder

WORKDIR /app

# Copiar dependencias y código fuente
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /tmp/node_modules/sharp ./node_modules/sharp
COPY . .

# Variables de entorno para el build
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_OPTIONS="--max_old_space_size=2048"

# Build con reintentos
RUN cd apps/web && \
    for i in 1 2 3 4 5; do \
        echo "Intento de build $i/5" && \
        npm run build && \
        break || \
        echo "Reintentando build en 45s..." && \
        rm -rf .next && \
        npm cache clean --force && \
        sleep 45; \
    done

FROM node:20.11.1-slim as runner

WORKDIR /app

# Variables de entorno para producción
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3030

# Copiar aplicación compilada
COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/.next/static ./.next/static
COPY --from=builder /app/apps/web/public ./public

# Configuración de salud
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3030 || exit 1

# Etiquetas informativas
LABEL version="12.0.0"
LABEL description="Ever Teams Platform - Optimized for network stability"
LABEL maintainer="ever@ever.co"

EXPOSE 3030

CMD ["node", "server.js"]
