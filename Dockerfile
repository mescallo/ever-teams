# syntax = docker/dockerfile:1
# Ever Teams Platform v16.1.0 - 2024 (Fully Standalone Offline Build) pre precarga

FROM node:20.11.1-bullseye AS base
WORKDIR /app

# Configuración base de npm/yarn para mejor rendimiento
RUN npm config set registry https://registry.npmmirror.com && \
    npm config set fetch-retries 5 && \
    npm config set fetch-retry-factor 2 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000 && \
    yarn config set network-timeout 300000

# Instalar herramientas necesarias
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    python-is-python3 \
    git \
    ca-certificates \
    curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

FROM base AS deps
WORKDIR /app

ENV NODE_ENV=development
ENV NEXT_TELEMETRY_DISABLED=1
ENV SKIP_GENERATE=1
ENV DISABLE_ERD=1
ENV API_URL=https://api.teams.canvasia.co
ENV NEXTAUTH_URL=https://teams.canvasia.co
ENV GAUZY_API_SERVER_URL=https://api.teams.canvasia.co

# Copiar package.json antes de la instalación
COPY package*.json ./
COPY apps/web/package*.json ./apps/web/

# Instalación con reintentos y timeouts extendidos
RUN cd apps/web && \
    for i in 1 2 3; do \
        echo "=== Intento de instalación $i/3 ===" && \
        yarn install \
            --network-timeout 600000 \
            --prefer-offline \
            --frozen-lockfile \
            --non-interactive \
            --no-progress && break || \
        sleep 10; \
    done

FROM base AS builder
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV SKIP_GENERATE=1
ENV DISABLE_ERD=1
ENV API_URL=https://api.teams.canvasia.co
ENV NEXTAUTH_URL=https://teams.canvasia.co
ENV GAUZY_API_SERVER_URL=https://api.teams.canvasia.co

# Copiar node_modules y código fuente
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build con reintentos
RUN cd apps/web && \
    for i in 1 2 3; do \
        echo "=== Intento de build $i/3 ===" && \
        yarn build && break || \
        sleep 10; \
    done

FROM node:20.11.1-bullseye-slim AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3030
ENV SKIP_GENERATE=1
ENV DISABLE_ERD=1
ENV API_URL=https://api.teams.canvasia.co
ENV NEXTAUTH_URL=https://teams.canvasia.co
ENV GAUZY_API_SERVER_URL=https://api.teams.canvasia.co

# Copiar solo los archivos necesarios para producción
COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/.next/static ./.next/static
COPY --from=builder /app/apps/web/public ./public

EXPOSE 3030
CMD ["node", "server.js"]

# Metadata
LABEL version="16.1.0"
LABEL description="Ever Teams Platform - Standalone Build"
LABEL maintainer="aulneau@canvasia.co"
