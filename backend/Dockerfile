# Backend Dockerfile - Node.js/Express API
# Multi-stage build for optimization

# Stage 1: Base
FROM node:20-alpine AS base
WORKDIR /app

# Install dependencies only when needed
COPY package*.json ./
RUN npm install --only=production && npm cache clean --force

# Stage 2: Development
FROM node:20-alpine AS development
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev)
RUN npm install

# Copy source code
COPY . .

# Expose port
EXPOSE 5000

# Development command with hot reload
CMD ["npm", "run", "dev"]

# Stage 3: Production build
FROM node:20-alpine AS production
WORKDIR /app

# Copy production dependencies from base
COPY --from=base /app/node_modules ./node_modules

# Copy source code
COPY . .

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Change ownership
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:5000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Production command
CMD ["node", "server.js"]