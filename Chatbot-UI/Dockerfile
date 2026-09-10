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
RUN npm run build

# Production
FROM node:20-alpine AS production
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Copy necessary files from build stage
COPY --from=dependencies --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/.next ./.next
COPY --from=build --chown=node:node /app/public ./public
COPY --from=build --chown=node:node /app/package*.json ./
COPY --from=build --chown=node:node /app/next.config.js ./next.config.js
COPY --from=build --chown=node:node /app/next-i18next.config.js ./next-i18next.config.js

# Switch to the node user why? To run the application with a non-root user for security reasons.
USER node

# Expose the port the app will run on 
EXPOSE 3000

# Healthcheck to ensure the application is running
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/api/health || exit 1

# Start the application
CMD ["npm", "start"]