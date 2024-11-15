# syntax = docker/dockerfile:1
# Ever Teams Platform - Versión 5
# Optimizada para problemas de build y caché
FROM node:20.11.1-slim as deps

WORKDIR /app

# Install build essentials
RUN apt-get update -qq && \
    apt-get install -y build-essential pkg-config python-is-python3 git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Remove yarn completely and configure npm
RUN rm -rf /usr/local/lib/node_modules/yarn && \
    rm -rf /opt/yarn-* && \
    rm -rf ~/.yarn && \
    rm -rf ~/.npm && \
    npm cache clean --force && \
    npm config set registry=https://registry.npmmirror.com/ && \
    npm config set fetch-retries=5 && \
    npm config set fetch-retry-maxtimeout=60000 && \
    npm config set timeout=60000

# Setup workspace directory
WORKDIR /app/apps/web

# Copy only package files first
COPY package*.json /app/
COPY apps/web/package*.json ./

# Install dependencies directly in web directory
RUN echo "Installing dependencies..." && \
    cd /app && npm install --no-audit --no-fund --legacy-peer-deps && \
    cd /app/apps/web && npm install --no-audit --no-fund --legacy-peer-deps

FROM node:20.11.1-slim as builder
WORKDIR /app

# Copy dependencies and source
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/web/node_modules ./apps/web/node_modules
COPY . .

# Build directly in web directory
WORKDIR /app/apps/web
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_SHARP_PATH=/app/node_modules/sharp

RUN echo "Building web application..." && \
    npm run build || (echo "Build failed, retrying..." && npm run build)

FROM node:20.11.1-slim as runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Copy built application
COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/.next/static ./apps/web/.next/static
COPY --from=builder /app/apps/web/public ./apps/web/public

EXPOSE 3030
ENV PORT=3030

CMD ["node", "./apps/web/server.js"]
