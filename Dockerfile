# syntax = docker/dockerfile:1
# Ever Teams Platform v16.1.0 - 2024 (Offline Build) marcelo

FROM node:20.11.1-bullseye as deps
WORKDIR /app

ENV NODE_ENV=development
ENV NEXT_TELEMETRY_DISABLED=1
ENV SKIP_GENERATE=1
ENV DISABLE_ERD=1
ENV API_URL=https://api.teams.canvasia.co
ENV NEXTAUTH_URL=https://teams.canvasia.co
ENV GAUZY_API_SERVER_URL=https://api.teams.canvasia.co

# Configurar yarn para modo offline
COPY /root/ever-teams-offline/packages /usr/local/share/.cache/yarn/v6/
RUN yarn config set yarn-offline-mirror /usr/local/share/.cache/yarn/v6 && \
    yarn config set yarn-offline-mirror-pruning true && \
    yarn config set offline true

COPY package*.json ./
COPY apps/web/package*.json ./apps/web/

# Instalación completamente offline
RUN cd apps/web && \
    YARN_CACHE_FOLDER=/usr/local/share/.cache/yarn/v6 \
    yarn install \
        --offline \
        --frozen-lockfile \
        --ignore-scripts \
        --prefer-offline \
        --no-progress

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
    YARN_CACHE_FOLDER=/usr/local/share/.cache/yarn/v6 \
    NODE_ENV=production \
    yarn build --offline

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
