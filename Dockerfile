# syntax = docker/dockerfile:1
# Ever Teams Platform v16.1.0 - 2024 (Pre-cached Build)
FROM node:20.11.1-bullseye as deps
WORKDIR /app

ENV NODE_ENV=development
ENV NEXT_TELEMETRY_DISABLED=1
ENV SKIP_GENERATE=1
ENV DISABLE_ERD=1
ENV API_URL=https://api.teams.canvasia.co
ENV NEXTAUTH_URL=https://teams.canvasia.co
ENV GAUZY_API_SERVER_URL=https://api.teams.canvasia.co

# Usar el cache pre-descargado
COPY /tmp/ever-teams-cache /root/.npm/_cacache

COPY package*.json ./
COPY apps/web/package*.json ./apps/web/

# Instalación usando cache pre-descargado
RUN cd apps/web && \
    npm install \
        --prefer-offline \
        --cache=/root/.npm/_cacache \
        --legacy-peer-deps \
        --ignore-scripts \
        --no-audit \
        --fetch-timeout=600000 \
        --network-timeout=600000

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
LABEL description="Ever Teams Platform - Pre-cached Build"
LABEL maintainer="aulneau@canvasia.co"
