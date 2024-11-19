# syntax = docker/dockerfile:1
# Ever Teams Platform v16.1.0 - 2024
# Optimizado para despliegue en Coolify

FROM node:20.11.1-bullseye as deps
WORKDIR /app

# Variables de entorno para la etapa de deps
ENV NODE_ENV=development
ENV NEXT_TELEMETRY_DISABLED=1
ENV SKIP_GENERATE=1
ENV DISABLE_ERD=1
ENV API_URL=https://api.teams.canvasia.co
ENV NEXTAUTH_URL=https://teams.canvasia.co
ENV GAUZY_API_SERVER_URL=https://api.teams.canvasia.co

# Optimizar configuración de npm/yarn 
RUN npm config set registry https://registry.npmmirror.com && \
   npm config set network-timeout 300000 && \
   yarn config set network-timeout 300000 && \
   yarn config set registry https://registry.npmmirror.com && \
   npm config set sharp_binary_host "https://npmmirror.com/mirrors/sharp" && \
   npm config set sharp_libvips_binary_host "https://npmmirror.com/mirrors/sharp-libvips" && \
   npm config set puppeteer_download_host "https://npmmirror.com/mirrors" && \
   npm config set electron_mirror "https://npmmirror.com/mirrors/electron/" && \
   npm config set sass_binary_site "https://npmmirror.com/mirrors/node-sass" && \
   npm install -g npm@latest

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
   rm -rf /var/lib/apt/lists/*

# Pre-descargar date-fns
RUN cd /tmp && \
   curl -L -o date-fns.tgz https://registry.npmmirror.com/date-fns/-/date-fns-2.30.0.tgz && \
   npm install /tmp/date-fns.tgz

# Copiar archivos de package
COPY package*.json ./
COPY apps/web/package*.json ./apps/web/

# Instalar dependencias con reintentos
RUN cd apps/web && \
   for i in 1 2 3 4 5; do \
       echo "=== Intento de instalación $i/5 ===" && \
       yarn install --network-timeout 300000 \
           --prefer-offline \
           --frozen-lockfile \
           --network-concurrency 1 \
           --no-audit \
           --ignore-scripts && break || \
       echo "Reintentando en 30s..." && \
       sleep 30; \
   done

FROM node:20.11.1-bullseye as builder
WORKDIR /app

# Variables de entorno para la etapa de build
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV SKIP_GENERATE=1
ENV DISABLE_ERD=1
ENV API_URL=https://api.teams.canvasia.co
ENV NEXTAUTH_URL=https://teams.canvasia.co
ENV GAUZY_API_SERVER_URL=https://api.teams.canvasia.co

# Copiar dependencias y código
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /tmp/node_modules/date-fns ./node_modules/date-fns
COPY . .

# Build con npm
RUN cd apps/web && npm run build

FROM node:20.11.1-bullseye-slim as runner
WORKDIR /app

# Variables de entorno para producción
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3030
ENV SKIP_GENERATE=1
ENV DISABLE_ERD=1
ENV API_URL=https://api.teams.canvasia.co
ENV NEXTAUTH_URL=https://teams.canvasia.co
ENV GAUZY_API_SERVER_URL=https://api.teams.canvasia.co

# Copiar archivos necesarios
COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/.next/static ./.next/static
COPY --from=builder /app/apps/web/public ./public

# Configurar puerto y comando de inicio
EXPOSE 3030
CMD ["node", "server.js"]

# Metadata
LABEL version="16.1.0"
LABEL description="Ever Teams Platform - Optimizado para Coolify"
LABEL maintainer="marcelo.canvasia@gmail.com"
