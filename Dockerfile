# syntax = docker/dockerfile:1
FROM node:20.11.1-slim as deps

WORKDIR /app

# Install build essentials
RUN apt-get update -qq && \
    apt-get install -y build-essential pkg-config python-is-python3

# Copy package files
COPY package.json ./
COPY apps/web/package.json ./apps/web/

# Simple npm configuration for better network handling
RUN npm set registry=https://registry.npmmirror.com/

# Install dependencies with basic retry
RUN echo "Installing dependencies..." && \
    npm install --legacy-peer-deps --no-audit && \
    cd apps/web && \
    npm install --legacy-peer-deps --no-audit

FROM node:20.11.1-slim as builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build:web

FROM node:20.11.1-slim as runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/.next/static ./apps/web/.next/static
COPY --from=builder /app/apps/web/public ./apps/web/public

EXPOSE 3030
ENV PORT=3030

CMD ["node", "./apps/web/server.js"]
