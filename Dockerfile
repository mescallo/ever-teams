# syntax = docker/dockerfile:1
# Ever Teams Platform v16.1.0 - 2024 (Fully Offline Build)

# Etapa 1: Descargar y cachear todos los paquetes
FROM node:20.11.1-bullseye as cache-builder
WORKDIR /cache

# Instalar herramientas necesarias
RUN apt-get update && \
    apt-get install -y curl wget git

# Crear directorio para cache
RUN mkdir -p /cache/npm-packages

# Descargar paquetes esenciales primero
RUN cd /cache/npm-packages && \
    wget -q https://registry.npmmirror.com/date-fns/-/date-fns-2.30.0.tgz && \
    wget -q https://registry.npmmirror.com/rxjs/-/rxjs-7.8.1.tgz && \
    wget -q https://registry.npmmirror.com/next/-/next-13.4.19.tgz && \
    wget -q https://registry.npmmirror.com/@nrwl/next/-/next-16.8.1.tgz && \
    wget -q https://registry.npmmirror.com/react/-/react-18.2.0.tgz && \
    wget -q https://registry.npmmirror.com/react-dom/-/react-dom-18.2.0.tgz

# Crear y poblar cache de npm
RUN npm config set cache /cache/npm-cache && \
    cd /cache/npm-packages && \
    for f in *.tgz; do npm cache add $(pwd)/$f; done

# Copiar package.json para pre-cache
COPY package*.json ./
COPY apps/web/package*.json ./apps/web/

# Realizar una instalación offline para cachear dependencias
RUN cd apps/web && \
    npm install \
        --prefer-offline \
        --legacy-peer-deps \
        --ignore-scripts \
        --no-audit \
        --fetch-timeout=600000 \
        --network-timeout=600000

# Etapa 2: Build usando cache
FROM node:20.11.1-bullseye as deps
WORKDIR /app

ENV NODE_ENV=development
ENV NEXT_TELEMETRY_DISABLED=1
ENV SKIP_GENERATE=1
ENV DISABLE_ERD=1
ENV API_URL=https://api.teams.canvasia.co
ENV NEXTAUTH_URL=https://teams.canvasia.co
ENV GAUZY_API_SERVER_URL=https://api.teams.canvasia.co

# Copiar cache y paquetes
COPY --from=cache-builder /cache/npm-cache /root/.npm/_cacache
COPY --from=cache-builder /cache/npm-packages /tmp/packages
COPY --from=cache-builder /cache/node_modules ./node_modules

# Copiar package.json
COPY package*.json ./
COPY apps/web/package*.json ./apps/web/

# Instalación completamente offline
RUN cd apps/web && \
    npm install \
        --offline \
        --prefer-offline \
        --no-registry \
        --legacy-peer-deps \
        --ignore-scripts \
        --no-audit \
        --cache=/root/.npm/_cacache

# Etapa 3: Builder
FROM node:20.11.1-bullseye as builder
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV SKIP_GENERATE=1
ENV DISABLE_ERD=1
ENV API_URL=https://api.teams.canvasia.co
ENV NEXTAUTH_URL=https://teams.canvasia.co
ENV GAUZY_API_SERVER_URL=https://api.teams.canvasia.co

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN cd apps/web && \
    NODE_ENV=production \
    npm run build

# Etapa 4: Runner
FROM node:20.11.1-bullseye-slim as runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3030
ENV SKIP_GENERATE=1
ENV DISABLE_ERD=1
ENV API_URL=https://api.teams.canvasia.co
ENV NEXTAUTH_URL=https://teams.canvasia.co
ENV GAUZY_API_SERVER_URL=https://api.teams.canvasia.co

COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/.next/static ./.next/static
COPY --from=builder /app/apps/web/public ./public

EXPOSE 3030
CMD ["node", "server.js"]

LABEL version="16.1.0"
LABEL description="Ever Teams Platform - Fully Offline Build"
LABEL maintainer="aulneau@canvasia.co"
