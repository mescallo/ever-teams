# syntax = docker/dockerfile:1
# Ever Teams Platform v16.1.0 - 2024
FROM node:20.11.1-bullseye as deps
WORKDIR /app

ENV NODE_ENV=development
ENV NEXT_TELEMETRY_DISABLED=1
ENV SKIP_GENERATE=1
ENV DISABLE_ERD=1
ENV API_URL=https://api.teams.canvasia.co
ENV NEXTAUTH_URL=https://teams.canvasia.co
ENV GAUZY_API_SERVER_URL=https://api.teams.canvasia.co

RUN npm config set registry https://registry.npmmirror.com && \
   npm config set network-timeout 1000000 && \
   yarn config set network-timeout 1000000 && \
   yarn config set registry https://registry.npmmirror.com && \
   npm config set sharp_binary_host "https://npmmirror.com/mirrors/sharp" && \
   npm config set sharp_libvips_binary_host "https://npmmirror.com/mirrors/sharp-libvips" && \
   npm config set puppeteer_download_host "https://npmmirror.com/mirrors" && \
   npm config set electron_mirror "https://npmmirror.com/mirrors/electron/" && \
   npm config set sass_binary_site "https://npmmirror.com/mirrors/node-sass" && \
   npm install -g npm@latest

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

# Pre-descargar paquetes críticos
RUN cd /tmp && \
   curl -L -o date-fns.tgz https://registry.npmmirror.com/date-fns/-/date-fns-2.30.0.tgz && \
   npm install /tmp/date-fns.tgz && \
   curl -L -o rxjs.tgz https://registry.npmmirror.com/rxjs/-/rxjs-7.8.1.tgz && \
   mkdir -p node_modules/rxjs && \
   tar -xzf rxjs.tgz -C node_modules/rxjs

COPY package*.json ./
COPY apps/web/package*.json ./apps/web/

RUN cd apps/web && \
   for i in 1 2 3 4 5; do \
       echo "=== Intento de instalación $i/5 ===" && \
       YARN_NETWORK_TIMEOUT=1000000 yarn install \
           --network-timeout 1000000 \
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

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV SKIP_GENERATE=1
ENV DISABLE_ERD=1
ENV API_URL=https://api.teams.canvasia.co
ENV NEXTAUTH_URL=https://teams.canvasia.co
ENV GAUZY_API_SERVER_URL=https://api.teams.canvasia.co

COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /tmp/node_modules/date-fns ./node_modules/date-fns
COPY --from=deps /tmp/node_modules/rxjs ./node_modules/rxjs
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
LABEL description="Ever Teams Platform - Optimizado para Coolify"
LABEL maintainer="aulneau@canvasia.co"
