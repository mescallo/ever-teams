# syntax = docker/dockerfile:1
# Ever Teams Platform - Versión 10
# Configuración completa con todas las variables de entorno
FROM node:20.11.1-slim as deps

WORKDIR /app/web

# Install essential build tools and PostgreSQL client
RUN apt-get update -qq && \
    apt-get install -y python3 make g++ git postgresql-client && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Pre-configure npm
RUN npm config set registry https://registry.npmmirror.com && \
    npm install -g npm@latest

# Copy necessary files
COPY apps/web/package.json ./package.json
COPY apps/web/.env.example ./.env

# Create environment file
RUN echo "BASE_URL=${BASE_URL}\n\
DB_HOST=${DB_HOST}\n\
DB_NAME=${DB_NAME}\n\
DB_PASS=${DB_PASS}\n\
DB_PORT=${DB_PORT}\n\
DB_USER=${DB_USER}\n\
HOST=${HOST}\n\
JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}\n\
JWT_SECRET=${JWT_SECRET}\n\
NEXT_PUBLIC_GAUZY_API_SERVER_URL=${NEXT_PUBLIC_GAUZY_API_SERVER_URL}\n\
NEXT_TELEMETRY_DISABLED=1\n\
NODE_ENV=production\n\
PORT=3030" > .env

# Install dependencies
RUN npm install --legacy-peer-deps --no-audit && \
    npm install next@13.4.19 react@latest react-dom@latest --legacy-peer-deps --no-audit && \
    npx browserslist@latest --update-db

# Create next.config.js with environment variables
RUN echo 'module.exports = {\n\
  output: "standalone",\n\
  env: {\n\
    BASE_URL: process.env.BASE_URL,\n\
    NEXT_PUBLIC_GAUZY_API_SERVER_URL: process.env.NEXT_PUBLIC_GAUZY_API_SERVER_URL,\n\
    DB_HOST: process.env.DB_HOST,\n\
    DB_PORT: process.env.DB_PORT,\n\
    DB_NAME: process.env.DB_NAME,\n\
    DB_USER: process.env.DB_USER,\n\
    DB_PASS: process.env.DB_PASS\n\
  }\n\
}' > next.config.js

FROM node:20.11.1-slim as builder

WORKDIR /app/web

# Copy deps and source
COPY --from=deps /app/web/node_modules ./node_modules
COPY --from=deps /app/web/next.config.js ./next.config.js
COPY --from=deps /app/web/.env ./.env
COPY apps/web ./

# Set build environment
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_OPTIONS="--max_old_space_size=4096"

# Create necessary directories
RUN mkdir -p pages

# Build Next.js application
RUN echo "Starting Next.js build..." && \
    ./node_modules/.bin/next build || \
    (echo "Build failed, retrying with clean cache..." && \
    rm -rf .next && \
    ./node_modules/.bin/next build)

FROM node:20.11.1-slim as runner

WORKDIR /app

# Install PostgreSQL client for production
RUN apt-get update -qq && \
    apt-get install -y postgresql-client && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set production environment
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Copy built application and environment
COPY --from=builder /app/web/.next/standalone ./
COPY --from=builder /app/web/.next/static ./.next/static
COPY --from=builder /app/web/public ./public
COPY --from=builder /app/web/.env ./.env

EXPOSE 3030
ENV PORT=3030

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME || exit 1

CMD ["node", "server.js"]
