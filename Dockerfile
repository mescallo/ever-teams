# syntax = docker/dockerfile:1
# Ever Teams Platform - Versión 6
# Optimizada para evitar problemas con NX y browserslist
FROM node:20.11.1-slim as deps

WORKDIR /app

# Install build essentials
RUN apt-get update -qq && \
    apt-get install -y build-essential pkg-config python-is-python3 git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Remove yarn and prepare npm
RUN rm -rf /usr/local/lib/node_modules/yarn && \
    rm -rf /opt/yarn-* && \
    rm -rf ~/.yarn && \
    rm -rf ~/.npm && \
    npm cache clean --force

# Create and setup web directory
WORKDIR /app/apps/web

# Update browserslist database first
RUN npm install -g browserslist && \
    npx browserslist@latest --update-db

# Copy only web app files
COPY apps/web/package*.json ./

# Install only web dependencies
RUN echo "Installing web dependencies..." && \
    npm install --no-audit --no-fund --legacy-peer-deps && \
    npm install next@latest

# Set Next.js standalone mode
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_SHARP_PATH=/app/apps/web/node_modules/sharp

FROM node:20.11.1-slim as builder
WORKDIR /app/apps/web

# Copy dependencies and source for web only
COPY --from=deps /app/apps/web/node_modules ./node_modules
COPY apps/web/ ./

# Environment variables for build
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV NX_SKIP_NX_CACHE=true

# Direct Next.js build without NX
RUN echo "Building web application..." && \
    node_modules/.bin/next build

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

CMD ["node", "server.js"]
