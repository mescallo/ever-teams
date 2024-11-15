# syntax = docker/dockerfile:1
FROM node:20.11.1-slim as deps

WORKDIR /app

# Install build essentials and git
RUN apt-get update -qq && \
    apt-get install -y build-essential pkg-config python-is-python3 git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Remove yarn and configure npm
RUN rm -rf /usr/local/lib/node_modules/yarn && \
    rm -rf /opt/yarn-* && \
    rm -rf ~/.yarn && \
    npm config set registry=https://registry.npmmirror.com/ && \
    npm config set fetch-retries=5 && \
    npm config set fetch-retry-maxtimeout=60000 && \
    npm config set timeout=60000

# Copy package files
COPY package*.json ./
COPY apps/web/package*.json ./apps/web/

# Install dependencies with retries
RUN npm cache clean --force && \
    echo "Installing dependencies..." && \
    for i in 1 2 3 4 5; do \
        echo "Attempt $i/5..." && \
        npm install --no-audit --no-fund --legacy-peer-deps || \
        (echo "Retry after $i..." && sleep 30 && continue) && break; \
    done && \
    cd apps/web && \
    for i in 1 2 3 4 5; do \
        echo "Installing web dependencies attempt $i/5..." && \
        npm install --no-audit --no-fund --legacy-peer-deps || \
        (echo "Retry after $i..." && sleep 30 && continue) && break; \
    done

# Update browserslist database
RUN npx update-browserslist-db@latest

FROM node:20.11.1-slim as builder
WORKDIR /app

# Copy node_modules and source
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Set environment variables
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV NX_SKIP_NX_CACHE=true
ENV NX_CACHE_PROJECT_GRAPH=false
ENV FORCE_COLOR=true

# Initialize NX and build
RUN echo "Initializing NX..." && \
    npx nx reset && \
    rm -rf .nx && \
    echo "Starting build process..." && \
    cd apps/web && \
    echo "Building web application..." && \
    npm run build

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
