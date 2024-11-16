# syntax = docker/dockerfile:1
# Ever Teams Platform - Version 15
# Optimizado para redes inestables usando pnpm

FROM node:20.11.1-bullseye as deps

# Configuración de entorno
ENV NODE_OPTIONS="--max_old_space_size=2048"
ENV NEXT_TELEMETRY_DISABLED=1
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="${PNPM_HOME}:${PATH}"

WORKDIR /app

# Instalar dependencias del sistema
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    python-is-python3 \
    git \
    ca-certificates \
    curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /usr/local/lib/node_modules/yarn && \
    npm uninstall -g yarn && \
    npm cache clean --force

# Instalar pnpm
RUN curl -fsSL https://get.pnpm.io/install.sh | sh - && \
    pnpm config set registry https://registry.npmmirror.com && \
    pnpm config set network-timeout 300000 && \
    pnpm config set fetch-retries 5 && \
    pnpm config set strict-ssl false && \
    pnpm setup

# Preparar sharp
RUN mkdir -p /temp && cd /temp && \
    pnpm add sharp

# Copiar archivos de package
COPY package.json pnpm-lock.yaml* ./
COPY apps/web/package.json ./apps/web/

# Instalar dependencias
RUN cd apps/web && \
    for i in 1 2 3 4 5; do \
        echo "=== Intento de instalación $i/5 ===" && \
        pnpm install --offline-first --strict-peer-dependencies=false && break || \
        echo "Reintentando en 45s..." && \
        pnpm store prune && \
        sleep 45; \
    done

FROM node:20.11.1-bullseye as builder

WORKDIR /app

# Copiar archivos necesarios
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
        echo "Reintentando en 45s..." && \
        rm -rf .next && \
        sleep 45; \
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

# Healthcheck más tolerante
HEALTHCHECK --interval=45s --timeout=45s --start-period=45s --retries=3 \
    CMD curl --fail http://localhost:3030 || exit 1

# Metadatos
LABEL version="15.0.0"
LABEL description="Ever Teams Platform - PNPM based build"
LABEL maintainer="ever@ever.co"

EXPOSE 3030

CMD ["node", "server.js"]
