# syntax = docker/dockerfile:1
# Ever Teams Platform - Versión 9
# Bypass NX completamente
FROM node:20.11.1-slim as deps

WORKDIR /app/web

# Install essential build tools
RUN apt-get update -qq && \
    apt-get install -y python3 make g++ git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Pre-configure npm
RUN npm config set registry https://registry.npmmirror.com && \
    npm install -g npm@latest

# Copy only web app files
COPY apps/web/package.json ./package.json

# Install Next.js and dependencies
RUN npm install --legacy-peer-deps --no-audit && \
    npm install next@13.4.19 react@latest react-dom@latest --legacy-peer-deps --no-audit && \
    npx browserslist@latest --update-db

# Create minimal next.config.js
RUN echo 'module.exports = {output: "standalone"}' > next.config.js

FROM node:20.11.1-slim as builder

WORKDIR /app/web

# Copy deps and source
COPY --from=deps /app/web/node_modules ./node_modules
COPY --from=deps /app/web/next.config.js ./next.config.js
COPY apps/web ./

# Set build environment
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_OPTIONS="--max_old_space_size=4096"

# Create pages directory if it doesn't exist
RUN mkdir -p pages

# Direct Next.js build without NX
RUN echo "Starting Next.js build..." && \
    ./node_modules/.bin/next build || \
    (echo "Build failed, retrying with clean cache..." && \
    rm -rf .next && \
    ./node_modules/.bin/next build)

FROM node:20.11.1-slim as runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Copy only the built application
COPY --from=builder /app/web/.next/standalone ./
COPY --from=builder /app/web/.next/static ./.next/static
COPY --from=builder /app/web/public ./public

EXPOSE 3030
ENV PORT=3030

CMD ["node", "server.js"]
