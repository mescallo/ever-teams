# syntax = docker/dockerfile:1
# Ever Teams Platform v16.1.0 - 2024 (Offline Build)
FROM node:20.11.1-bullseye as downloader
WORKDIR /downloads

# Instalar herramientas necesarias
RUN apt-get update && \
   apt-get install -y curl wget git

# Descargar paquetes críticos
RUN mkdir -p packages && cd packages && \
   wget https://registry.npmmirror.com/date-fns/-/date-fns-2.30.0.tgz && \
   wget https://registry.npmmirror.com/rxjs/-/rxjs-7.8.1.tgz && \
   wget https://registry.npmmirror.com/@nrwl/next/-/next-16.8.1.tgz && \
   wget https://registry.npmmirror.com/next/-/next-13.4.19.tgz

FROM node:20.11.1-bullseye as deps
WORKDIR /app

ENV NODE_ENV=development
ENV NEXT_TELEMETRY_DISABLED=1
ENV SKIP_GENERATE=1
ENV DISABLE_ERD=1
ENV API_URL=https://api.teams.canvasia.co
ENV NEXTAUTH_URL=https://teams.canvasia.co
ENV GAUZY_API_SERVER_URL=https://api.teams.canvasia.co

# Copiar paquetes pre-descargados
COPY --from=downloader /downloads/packages /tmp/packages

# Preparar cache npm
RUN mkdir -p /root/.npm/_cacache && \
   cd /tmp/packages && \
   for package in *.tgz; do \
       npm cache add $(pwd)/$package; \
   done

# Instalar paquetes críticos
RUN cd /tmp && \
   npm install \
       ./packages/date-fns-2.30.0.tgz \
       ./packages/rxjs-7.8.1.tgz \
       ./packages/next-13.4.19.tgz \
       ./packages/@nrwl-next-16.8.1.tgz

COPY package*.json ./
COPY apps/web/package*.json ./apps/web/

# Instalación offline
RUN cd apps/web && \
   npm install \
       --prefer-offline \
       --no-registry \
       --legacy-peer-deps \
       --ignore-scripts

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
COPY --from=deps /tmp/node_modules ./node_modules
COPY . .

RUN cd apps/web && npm run build

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
LABEL description="Ever Teams Platform - Build Offline Optimizado"
LABEL maintainer="aulneau@canvasia.co"
