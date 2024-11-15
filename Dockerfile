# syntax = docker/dockerfile:1
FROM node:20.11.1-slim as deps

WORKDIR /app

# Install build essentials and git
RUN apt-get update -qq && \
    apt-get install -y build-essential pkg-config python-is-python3 git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure npm
RUN npm config set registry=https://registry.npmmirror.com/ && \
    npm config set fetch-retries=5 && \
    npm config set fetch-retry-maxtimeout=60000 && \
    npm config set timeout=60000

# Copy only necessary files
COPY package*.json ./
COPY apps/web/package*.json ./apps/web/

# Install dependencies
RUN cd apps/web && \
    echo "Installing web dependencies..." && \
    npm install --no-audit --no-fund --legacy-peer-deps

FROM node:20.11.1-slim as builder
WORKDIR /app

# Copy dependencies and source
COPY --from=deps /app/apps/web/node_modules ./apps/web/node_modules
COPY . .

# Build directly in web directory
WORKDIR /app/apps/web
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN echo "Building web application..." && \
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
