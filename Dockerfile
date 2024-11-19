# syntax = docker/dockerfile:1
# Ever Teams Platform v16.1.0 - 2024 (Offline Build)

FROM node:20.11.1-bullseye as deps
WORKDIR /app

ENV NODE_ENV=development
ENV NEXT_TELEMETRY_DISABLED=1
ENV SKIP_GENERATE=1
ENV DISABLE_ERD=1
ENV API_URL=https://api.teams.canvasia.co
ENV NEXTAUTH_URL=https://teams.canvasia.co
ENV GAUZY_API_SERVER_URL=https://api.teams.canvasia.co

# Configurar npm para modo offline
RUN npm config set offline true

# Copiar cache y paquetes pre-descargados
COPY /root/ever-teams-offline/npm-cache /root/.npm/_cacache
COPY /root/ever-teams-offline/packages /tmp/packages

# Instalar paquetes del cache local
RUN cd /tmp/packages && \
    for package in *.tgz; do \
        npm install --global --offline --no-audit --no-save $package; \
    done

COPY package*.json ./
COPY apps/web/package*.json ./apps/web/

# Instalación offline
RUN cd apps/web && \
    npm install \
        --offline \
        --no-registry \
        --prefer-offline \
        --legacy-peer-deps \
        --ignore-scripts \
        --no-audit \
        --cache=/root/.npm/_cacache

FROM node:20.11.1-bullseye as builder
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV SKIP_GENERATE=1
ENV DISABLE_ERD=1
ENV API_URL=https://api.teams.canvasia.co
ENV NEXTAUTH_URL=https://teams.canvasia.co
ENV GAUZY_API_SERVER_URL=https://api.teams.canvasia.co

# Copiar módulos y dependencias
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY . .

# Build offline
RUN cd apps/web && \
    NODE_ENV=production \
    npm run build --offline

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
LABEL description="Ever Teams Platform - Offline Build"
LABEL maintainer="aulneau@canvasia.co"
