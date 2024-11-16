# syntax = docker/dockerfile:1
FROM node:20.11.1-slim as deps

# Optimizar para 4 CPUs y 2GB de RAM disponible
ENV NODE_OPTIONS="--max_old_space_size=2048"
ENV NEXT_TELEMETRY_DISABLED=1

WORKDIR /app

# Instalar dependencias esenciales y limpiar
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    python-is-python3 \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configurar npm
RUN npm i -g npm@latest && \
    npm config set registry https://registry.npmmirror.com && \
    npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000

# Copiar solo los archivos necesarios
COPY package*.json ./
COPY apps/web/package*.json ./apps/web/

# Instalar dependencias con retry
RUN echo "Installing dependencies..." && \
    cd apps/web && \
    for i in 1 2 3; do \
        echo "Attempt $i/3" && \
        npm install --no-audit --no-fund --legacy-peer-deps && \
        break || \
        sleep 30; \
    done

FROM node:20.11.1-slim as builder

WORKDIR /app

# Copiar dependencias y código
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Variables de entorno para build
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_OPTIONS="--max_old_space_size=2048"

# Build con retry
RUN echo "Building application..." && \
    cd apps/web && \
    for i in 1 2 3; do \
        echo "Attempt $i/3" && \
        NODE_ENV=production npm run build && \
        break || \
        sleep 30; \
    done

FROM node:20.11.1-slim as runner

WORKDIR /app

# Variables de entorno para producción
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3030

# Copiar archivos necesarios
COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/.next/static ./.next/static
COPY --from=builder /app/apps/web/public ./public

# Configuración de salud
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3030 || exit 1

EXPOSE 3030

CMD ["node", "server.js"]
