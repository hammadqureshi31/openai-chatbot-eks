# Base image
FROM node:20-alpine AS base
WORKDIR /app
COPY package*.json ./

# Dependencies
FROM base AS dependencies
RUN npm ci

# Build
FROM dependencies AS build
COPY . .
RUN NEXT_PRIVATE_BUILD_WORKER=1 npm run build

# Prepare production dependencies
FROM dependencies AS production-dependencies
RUN npm prune --omit=dev

# Production
FROM node:20-alpine AS production
RUN apk upgrade --no-cache
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Copy production-only dependencies
COPY --from=production-dependencies --chown=node:node /app/node_modules ./node_modules

# Copy application
COPY --from=build --chown=node:node /app/.next ./.next
COPY --from=build --chown=node:node /app/public ./public
COPY --from=build --chown=node:node /app/package*.json ./
COPY --from=build --chown=node:node /app/next.config.js ./next.config.js
COPY --from=build --chown=node:node /app/next-i18next.config.js ./next-i18next.config.js

# Run as non-root user
USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/api/health || exit 1

CMD ["npm", "start"]
